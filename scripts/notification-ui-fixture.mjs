import { createServer } from "node:http";

const viewer = "20000000-0000-0000-0000-000000000001";
const creator = "20000000-0000-0000-0000-000000000002";
const video = "30000000-0000-0000-0000-000000000001";
const root = "40000000-0000-0000-0000-000000000001";
const reply = "40000000-0000-0000-0000-000000000002";
const now = new Date().toISOString();
const post = {
  id: video, user_id: creator, username: "loopmaker", caption: "Evening loop", comments_enabled: true,
  video_key: "test/clip.mp4", thumb_key: "test/thumb.jpg", like_count: 0, created_at: now,
};
const secondPost = {
  ...post, id: "30000000-0000-0000-0000-000000000002", username: "secondartist",
  user_id: "20000000-0000-0000-0000-000000000003", caption: "Second performance",
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
const liked = new Set();
const withLikes = (comment) => ({ ...comment, like_count: liked.has(comment.id) ? 1 : 0, liked_by_me: liked.has(comment.id) });

createServer((request, response) => {
  const url = new URL(request.url, "http://localhost");
  const send = (value) => response.writeHead(200, { "Content-Type": "application/json" }).end(JSON.stringify(value));
  switch (url.pathname) {
    case "/auth/v1/otp": return send({});
    case "/auth/v1/verify": return send({
      access_token: "fixture-token", token_type: "bearer", expires_in: 3600,
      expires_at: Math.floor(Date.now() / 1000) + 3600, refresh_token: "fixture-refresh",
      user: { id: viewer, aud: "authenticated", app_metadata: {}, user_metadata: {}, created_at: now, updated_at: now },
    });
    case "/rest/v1/profiles": return send({ id: viewer, username: "viewer", accepted_terms_at: now });
    case "/rest/v1/feed_videos": {
      const id = url.searchParams.get("id")?.slice(3).toLowerCase();
      const handle = url.searchParams.get("username")?.slice(3);
      return send([post, secondPost].filter((item) => (!id || item.id === id) && (!handle || item.username === handle)));
    }
    case "/rest/v1/public_creators": {
      const handle = url.searchParams.get("username")?.slice(3);
      return send([{ id: creator, username: "loopmaker", display_name: "Loop Maker" }].filter((item) => !handle || item.username === handle));
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
