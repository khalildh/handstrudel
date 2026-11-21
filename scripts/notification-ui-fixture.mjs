import { createServer } from "node:http";
import { readFileSync } from "node:fs";

const viewer = "20000000-0000-0000-0000-000000000001";
const creator = "20000000-0000-0000-0000-000000000002";
const video = "30000000-0000-0000-0000-000000000001";
const root = "40000000-0000-0000-0000-000000000001";
const reply = "40000000-0000-0000-0000-000000000002";
const now = new Date().toISOString();
const demoLikes = 42;
const clipBytes = process.env.FIXTURE_CLIP ? readFileSync(process.env.FIXTURE_CLIP) : null;
const thumbnailBytes = process.env.FIXTURE_THUMBNAIL ? readFileSync(process.env.FIXTURE_THUMBNAIL) : null;
const canControlMedia = process.env.FIXTURE_CONTROL_MEDIA === "1";
const singleClip = process.env.FIXTURE_SINGLE_CLIP === "1";
const mediaDelay = Math.max(0, Number(process.env.FIXTURE_MEDIA_DELAY_MS) || 0);
const engagementDelay = Math.max(0, Number(process.env.FIXTURE_ENGAGEMENT_DELAY_MS) || 0);
const mediaRequests = [];
const thumbnailRequests = [];
const countViews = process.env.FIXTURE_VIEW_COUNTS === "1";
const showEngagement = process.env.FIXTURE_ENGAGEMENT === "1";
const showReposts = process.env.FIXTURE_REPOSTS === "1";
// Sound pages: the first two clips share one sound (the second is a take on the first).
const soundPages = process.env.FIXTURE_SOUND_PAGES === "1";
let shareCount = 4;
const counted = new Set();
let mediaAvailable = !canControlMedia;
const demoThumb = "thumbs/76c9a372-7439-48dc-94ec-75a06cb6f1d7/385e21ab-7160-4378-b897-c602de952140.jpg";
const post = {
  id: video, user_id: creator, username: "loopmaker", caption: "Evening loop", comments_enabled: true,
  video_key: "test/clip.mp4", thumb_key: demoThumb, like_count: demoLikes, created_at: now,
  instrument: "Grand Piano", duration_s: process.env.FIXTURE_NO_DURATION === "1" ? undefined : clipBytes ? 4 : undefined,
  backing_enabled: process.env.FIXTURE_PLAY_ALONG === "1",
  view_count: countViews ? 7 : undefined,
  sound_setup: {
    version: 1, instrument: "grand_piano", waveform: "sine", key: "D", scale: "Minor", progression: "free",
    mode: "soundfont", bpm: 96, useSoundFont: true, autoStrum: false, padVolume: 0.3, gridOctave: 3, gridRange: 2,
  },
};
const secondPost = {
  ...post, id: "30000000-0000-0000-0000-000000000002", username: "secondartist",
  user_id: "20000000-0000-0000-0000-000000000003", caption: "Second performance", like_count: 0,
  video_key: "test/next-clip.mp4",
  source_video_id: process.env.FIXTURE_REMIXES === "1" ? video : undefined,
  source_username: process.env.FIXTURE_REMIXES === "1" ? post.username : undefined,
};
const sequencePosts = process.env.FIXTURE_SEQUENCE_CLIPS === "1" ? [3, 4].map((index) => ({
  ...post,
  id: `30000000-0000-0000-0000-00000000000${index}`,
  user_id: `20000000-0000-0000-0000-00000000000${index + 1}`,
  username: `artist${index}`,
  caption: index === 3 ? "Third performance" : "Fourth performance, with a longer caption that wraps over several lines.",
  like_count: 0,
  video_key: `test/sequence-${index}.mp4`,
})) : [];
const initial = {
  id: root, video_id: video, user_id: viewer, username: "viewer", parent_id: null,
  body: "Which octave?", created_at: now, reply_count: 1,
};
const answer = {
  id: reply, video_id: video, user_id: creator, username: "loopmaker", parent_id: root,
  body: "Try the lower octave", created_at: now, reply_count: 0,
};
let readAt = null;
let videoLikeReadAt = null;
let displayName = "Studio Viewer";
let following = false;
const draftPosting = process.env.FIXTURE_DRAFT_POSTING === "1";
const draftUploadID = "30000000-0000-0000-0000-000000000099";
let draftUploadStatus = "reserved";
let avatarKey = process.env.FIXTURE_AVATAR === "1" ? demoThumb : null;
const liked = new Set();
const saved = new Set();
const reposted = new Set();
const engagement = (id) => ({
  saves: 5 + saved.size, shares: shareCount, remixes: 3,
  ...(showReposts ? { reposts: 2 + Number(reposted.has(id)), reposted_by_me: reposted.has(id) } : {}),
});
const withLikes = (comment) => ({ ...comment, like_count: liked.has(comment.id) ? 1 : 0, liked_by_me: liked.has(comment.id) });

createServer((request, response) => {
  const url = new URL(request.url, "http://localhost");
  const send = (value) => {
    if (request.method === "HEAD") {
      const count = value.length;
      return response.writeHead(200, { "Content-Range": count ? `0-${count - 1}/${count}` : "*/0" }).end();
    }
    response.writeHead(200, { "Content-Type": "application/json" }).end(JSON.stringify(value));
  };
  const route = url.pathname.replace(/^\/cold-[^/]+(?=\/(?:test|thumbs)\/)/, "");
  switch (route) {
    case "/__fixture/media-requests":
      return send(mediaRequests);
    case "/__fixture/thumbnail-requests":
      return send(thumbnailRequests);
    case "/__fixture/draft-upload-result": {
      if (!draftPosting || request.method !== "POST" || draftUploadStatus !== "checking") return response.writeHead(409).end();
      const result = url.searchParams.get("status");
      if (result !== "published" && result !== "held") return response.writeHead(400).end();
      draftUploadStatus = result;
      return response.writeHead(204).end();
    }
    case "/functions/v1/sign-upload":
      if (!draftPosting || request.method !== "POST") return response.writeHead(404).end();
      request.resume();
      draftUploadStatus = "reserved";
      return send({
        id: draftUploadID,
        videoUploadUrl: `http://${request.headers.host}/__fixture/draft-video`,
        thumbUploadUrl: `http://${request.headers.host}/__fixture/draft-thumb`,
      });
    case "/__fixture/draft-video":
    case "/__fixture/draft-thumb":
      if (!draftPosting || request.method !== "PUT") return response.writeHead(404).end();
      request.on("end", () => response.writeHead(204).end());
      request.resume();
      return;
    case "/functions/v1/publish-upload": {
      if (!draftPosting || request.method !== "POST") return response.writeHead(404).end();
      let body = "";
      request.on("data", (chunk) => { body += chunk; });
      request.on("end", () => {
        const { action, id } = JSON.parse(body);
        if (id.toLowerCase() !== draftUploadID) return response.writeHead(404).end();
        if (action === "submit" && draftUploadStatus === "reserved") draftUploadStatus = "checking";
        send({ status: draftUploadStatus });
      });
      return;
    }
    case "/__fixture/feed-media":
      if (!canControlMedia || request.method !== "POST") return response.writeHead(404).end();
      mediaAvailable = url.searchParams.get("available") === "1";
      return response.writeHead(204).end();
    case `/${demoThumb}`:
      thumbnailRequests.push(url.pathname);
      if (!thumbnailBytes) return response.writeHead(404).end();
      response.writeHead(200, { "Content-Type": "image/jpeg", "Content-Length": thumbnailBytes.length });
      return response.end(request.method === "HEAD" ? undefined : thumbnailBytes);
    case "/test/clip.mp4":
    case "/test/next-clip.mp4":
    case "/test/sequence-3.mp4":
    case "/test/sequence-4.mp4": {
      if (!clipBytes || !mediaAvailable) return response.writeHead(404).end();
      mediaRequests.push(url.pathname);
      const range = /^bytes=(\d+)-(\d*)$/.exec(request.headers.range ?? "");
      const start = range ? Number(range[1]) : 0;
      const end = range?.[2] ? Math.min(Number(range[2]), clipBytes.length - 1) : clipBytes.length - 1;
      if (start > end) return response.writeHead(416, { "Content-Range": `bytes */${clipBytes.length}` }).end();
      const headers = { "Content-Type": "video/mp4", "Accept-Ranges": "bytes", "Content-Length": end - start + 1 };
      if (range) headers["Content-Range"] = `bytes ${start}-${end}/${clipBytes.length}`;
      const deliver = () => {
        if (response.destroyed) return;
        response.writeHead(range ? 206 : 200, headers);
        response.end(request.method === "HEAD" ? undefined : clipBytes.subarray(start, end + 1));
      };
      if (mediaDelay) return void setTimeout(deliver, mediaDelay);
      return deliver();
    }
    case "/auth/v1/otp": return send({});
    case "/auth/v1/verify": return send({
      access_token: "fixture-token", token_type: "bearer", expires_in: 3600,
      expires_at: Math.floor(Date.now() / 1000) + 3600, refresh_token: "fixture-refresh",
      user: { id: viewer, aud: "authenticated", app_metadata: {}, user_metadata: {}, created_at: now, updated_at: now },
    });
    case "/rest/v1/profiles": {
      if (request.method === "PATCH") {
        let body = "";
        request.on("data", (chunk) => { body += chunk; });
        request.on("end", () => {
          displayName = JSON.parse(body).display_name;
          response.writeHead(204).end();
        });
        return;
      }
      return send({ id: viewer, username: "viewer", display_name: displayName, avatar_key: avatarKey, accepted_terms_at: now });
    }
    case "/functions/v1/profile-avatar":
      if (request.method === "DELETE") {
        avatarKey = null;
        return send({ avatarKey });
      }
      if (request.method === "POST" && request.headers["content-type"] === "image/jpeg") {
        avatarKey = demoThumb;
        return send({ avatarKey });
      }
      return response.writeHead(415).end();
    case "/rest/v1/videos":
      return send(process.env.FIXTURE_ACCOUNT_CLIPS === "1"
        ? [post, secondPost].map((clip) => ({ ...clip, user_id: viewer, username: "viewer" }))
        : []);
    case "/rest/v1/rpc/video_engagement":
      return showEngagement ? send([engagement(video)]) : response.writeHead(404).end();
    case "/rest/v1/rpc/video_engagement_v2":
    case "/rest/v1/rpc/set_video_repost": {
      if (!showEngagement && !showReposts) {
        return response.writeHead(404, { "Content-Type": "application/json" })
          .end(JSON.stringify({ code: "PGRST202", message: "Missing repost function" }));
      }
      let body = "";
      request.on("data", (chunk) => { body += chunk; });
      request.on("end", () => {
        const { target_video: id, repost } = JSON.parse(body);
        const key = id.toLowerCase();
        if (repost === true) reposted.add(key);
        if (repost === false) reposted.delete(key);
        if (engagementDelay) setTimeout(() => send([engagement(key)]), engagementDelay);
        else send([engagement(key)]);
      });
      return;
    }
    case "/rest/v1/rpc/sound_summary":
    case "/rest/v1/rpc/sound_take_counts": {
      if (!soundPages) return response.writeHead(404, { "Content-Type": "application/json" })
        .end(JSON.stringify({ code: "PGRST202", message: "Missing sound function" }));
      let body = "";
      request.on("data", (chunk) => { body += chunk; });
      request.on("end", () => {
        const { target_video, target_videos } = JSON.parse(body);
        const takes = [post.id, secondPost.id];
        if (route.endsWith("sound_summary")) {
          return send(takes.includes(target_video.toLowerCase())
            ? [{ sound_id: post.id, take_count: takes.length, original_video_id: post.id }] : []);
        }
        send(target_videos.map((id) => id.toLowerCase()).filter((id) => takes.includes(id))
          .map((video_id) => ({ video_id, sound_id: post.id, take_count: takes.length })));
      });
      return;
    }
    case "/rest/v1/sound_takes": {
      if (!soundPages) return send([]);
      const top = (url.searchParams.get("order") ?? "").startsWith("like_count");
      const takes = [post, secondPost].map((item) => ({ ...item, sound_id: post.id, is_original: item.id === post.id }));
      return send(top ? takes : takes.reverse());
    }
    case "/rest/v1/rpc/record_video_share":
      if (!showEngagement) return response.writeHead(404).end();
      shareCount += 1;
      return response.writeHead(204).end();
    case "/rest/v1/rpc/record_video_view": {
      if (!countViews || request.method !== "POST") return response.writeHead(404).end();
      let body = "";
      request.on("data", (chunk) => { body += chunk; });
      request.on("end", () => {
        const { target_video, watch_receipt } = JSON.parse(body);
        const clip = [post, secondPost, ...sequencePosts].find((item) => item.id === target_video.toLowerCase());
        if (!clip) return send(null);
        const receipt = `${clip.id}/${watch_receipt}`;
        if (!counted.has(receipt)) {
          counted.add(receipt);
          clip.view_count += 1;
        }
        send(clip.view_count);
      });
      return;
    }
    case "/rest/v1/rpc/set_video_bookmark": {
      let body = "";
      request.on("data", (chunk) => { body += chunk; });
      request.on("end", () => {
        const { target_video: id, save } = JSON.parse(body);
        if (save) saved.add(id.toLowerCase());
        else saved.delete(id.toLowerCase());
        response.writeHead(204).end();
      });
      return;
    }
    case "/rest/v1/video_bookmarks": return send([...saved].map((video_id) => ({ video_id })));
    case "/rest/v1/saved_videos": return send([post, secondPost].filter(({ id }) => saved.has(id)).map((item) => ({ ...item, saved_at: now })));
    case "/rest/v1/video_audio_downloads": return send(process.env.FIXTURE_AUDIO_DOWNLOAD === "1" ? [{ video_id: video }] : []);
    case "/rest/v1/my_reposted_videos":
      return send([post, secondPost].filter(({ id }) => reposted.has(id)).map((item) => ({ ...item, activity_at: now })));
    case "/rest/v1/following_activity_videos":
      if (showReposts) return send([{
        ...post, activity_at: now, reposted_by: secondPost.username, reposted_by_id: secondPost.user_id,
      }]);
      return response.writeHead(404, { "Content-Type": "application/json" })
        .end(JSON.stringify({ code: "PGRST205", message: "Missing following activity view in this fixture." }));
    case "/rest/v1/following_videos":
      if (process.env.FIXTURE_MISSING_FOLLOWING_VIEW === "1") {
        return response.writeHead(404, { "Content-Type": "application/json" })
          .end(JSON.stringify({ code: "PGRST205", message: "Missing joined view in this fixture." }));
      }
      return send(following ? [post] : []);
    case "/rest/v1/follows": {
      if (request.method === "POST" || request.method === "DELETE") {
        following = request.method === "POST";
        return response.writeHead(following ? 201 : 204).end();
      }
      const follower = url.searchParams.get("follower_id")?.slice(3).toLowerCase();
      const followee = url.searchParams.get("followee_id")?.slice(3).toLowerCase();
      return send(following && (!follower || follower === viewer) && (!followee || followee === creator)
        ? [{ follower_id: viewer, followee_id: creator }] : []);
    }
    case "/rest/v1/feed_videos": {
      const id = url.searchParams.get("id")?.slice(3).toLowerCase();
      const handle = url.searchParams.get("username")?.slice(3);
      const author = url.searchParams.get("user_id")?.slice(3).toLowerCase();
      const source = url.searchParams.get("source_video_id")?.slice(3).toLowerCase();
      return send((singleClip ? [post] : [post, secondPost, ...sequencePosts]).filter((item) => (!id || item.id === id) && (!handle || item.username === handle)
        && (!author || item.user_id === author) && (!source || item.source_video_id === source)));
    }
    case "/rest/v1/public_creators": {
      const handle = url.searchParams.get("username")?.slice(3);
      const id = url.searchParams.get("id")?.slice(3).toLowerCase();
      const profiles = [
        { id: creator, username: "loopmaker", display_name: "Loop Maker", likes_received: demoLikes, views_received: 1234 },
        { id: viewer, username: "viewer", display_name: displayName, likes_received: 0, views_received: 0 },
      ];
      return send(profiles.filter((item) => (!handle || item.username === handle) && (!id || item.id === id)));
    }
    case "/rest/v1/activity_inbox": return send([{
      id: "50000000-0000-0000-0000-000000000001", video_id: video, comment_id: reply,
      kind: "reply", username: "loopmaker", body: answer.body, created_at: now, read_at: readAt,
    }]);
    case "/rest/v1/activity_inbox_v2": return send([{
      id: "50000000-0000-0000-0000-000000000002", video_id: video, comment_id: null,
      kind: "video_like", username: "loopmaker", body: post.caption, created_at: now, read_at: videoLikeReadAt, like_count: 3,
    }, {
      id: "50000000-0000-0000-0000-000000000001", video_id: video, comment_id: reply,
      kind: "reply", username: "loopmaker", body: answer.body, created_at: now, read_at: readAt,
    }]);
    case "/rest/v1/rpc/mark_creator_activity_read": readAt = now; return send(null);
    case "/rest/v1/rpc/mark_like_activity_read": videoLikeReadAt = now; return send(null);
    case "/rest/v1/comment_likes": {
      if (request.method === "POST") {
        let body = "";
        request.on("data", (chunk) => { body += chunk; });
        request.on("end", () => {
          liked.add(JSON.parse(body).comment_id.toLowerCase());
          response.writeHead(201).end();
        });
        return;
      }
      if (request.method === "DELETE") {
        liked.delete(url.searchParams.get("comment_id")?.slice(3).toLowerCase());
        return response.writeHead(204).end();
      }
      return send([]);
    }
    case "/rest/v1/video_comments": {
      const id = url.searchParams.get("id");
      // The normal thread loads only the root. The exact reply comes from the targeted request.
      if (id) return send(id.endsWith(reply) ? [withLikes(answer)] : id.endsWith(root) ? [withLikes(initial)] : []);
      return send(url.searchParams.get("parent_id") === "is.null" ? [withLikes(initial)] : []);
    }
    default: return send([]);
  }
}).listen(Number(process.env.PORT ?? 54328), "127.0.0.1");
