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
const canControlMedia = process.env.FIXTURE_CONTROL_MEDIA === "1";
let mediaAvailable = !canControlMedia;
const demoThumb = "thumbs/76c9a372-7439-48dc-94ec-75a06cb6f1d7/385e21ab-7160-4378-b897-c602de952140.jpg";
const post = {
  id: video, user_id: creator, username: "loopmaker", caption: "Evening loop", comments_enabled: true,
  video_key: "test/clip.mp4", thumb_key: demoThumb, like_count: demoLikes, created_at: now,
  instrument: "Grand Piano", duration_s: clipBytes ? 4 : undefined,
  backing_enabled: process.env.FIXTURE_PLAY_ALONG === "1",
  sound_setup: {
    version: 1, instrument: "grand_piano", waveform: "sine", key: "D", scale: "Minor", progression: "free",
    mode: "soundfont", bpm: 96, useSoundFont: true, autoStrum: false, padVolume: 0.3, gridOctave: 3, gridRange: 2,
  },
};
const secondPost = {
  ...post, id: "30000000-0000-0000-0000-000000000002", username: "secondartist",
  user_id: "20000000-0000-0000-0000-000000000003", caption: "Second performance", like_count: 0,
  video_key: "test/next-clip.mp4",
};
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
let avatarKey = process.env.FIXTURE_AVATAR === "1" ? demoThumb : null;
const liked = new Set();
const saved = new Set();
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
  switch (url.pathname) {
    case "/__fixture/feed-media":
      if (!canControlMedia || request.method !== "POST") return response.writeHead(404).end();
      mediaAvailable = url.searchParams.get("available") === "1";
      return response.writeHead(204).end();
    case "/test/clip.mp4":
    case "/test/next-clip.mp4": {
      if (!clipBytes || !mediaAvailable) return response.writeHead(404).end();
      const range = /^bytes=(\d+)-(\d*)$/.exec(request.headers.range ?? "");
      const start = range ? Number(range[1]) : 0;
      const end = range?.[2] ? Math.min(Number(range[2]), clipBytes.length - 1) : clipBytes.length - 1;
      if (start > end) return response.writeHead(416, { "Content-Range": `bytes */${clipBytes.length}` }).end();
      const headers = { "Content-Type": "video/mp4", "Accept-Ranges": "bytes", "Content-Length": end - start + 1 };
      if (range) headers["Content-Range"] = `bytes ${start}-${end}/${clipBytes.length}`;
      response.writeHead(range ? 206 : 200, headers);
      return response.end(request.method === "HEAD" ? undefined : clipBytes.subarray(start, end + 1));
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
    case "/rest/v1/videos": return send([]);
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
      return send([post, secondPost].filter((item) => (!id || item.id === id) && (!handle || item.username === handle)
        && (!author || item.user_id === author)));
    }
    case "/rest/v1/public_creators": {
      const handle = url.searchParams.get("username")?.slice(3);
      const id = url.searchParams.get("id")?.slice(3).toLowerCase();
      const profiles = [
        { id: creator, username: "loopmaker", display_name: "Loop Maker", likes_received: demoLikes },
        { id: viewer, username: "viewer", display_name: displayName, likes_received: 0 },
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
