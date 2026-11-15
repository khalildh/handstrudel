import { createServer } from "node:http";

const clip = {
  id: "31000000-0000-0000-0000-000000000001",
  user_id: "21000000-0000-0000-0000-000000000001",
  username: "keysfixture",
  display_name: "Local Loop Artist",
  caption: "Search fixture piano take",
  instrument: "Grand Piano",
  video_key: "fixture/clip.mp4",
  thumb_key: "fixture/thumb.jpg",
  like_count: 0,
  created_at: "2026-01-01T00:00:00Z",
};
const handleFilter = '(username.imatch."lo")';
const broaderFilter = '(caption.imatch."lo",instrument.imatch."lo",username.imatch."lo",display_name.imatch."lo")';
const searchesByKey = new Map();

const server = createServer((request, response) => {
  const url = new URL(request.url, "http://127.0.0.1");
  const key = request.headers.apikey;
  const send = (status, value) => response.writeHead(status, {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
  }).end(JSON.stringify(value));

  if (request.method !== "GET" || !/^search-fixture-[0-9a-f-]+$/i.test(key ?? "")) {
    return send(404, { message: "Not a search fixture request" });
  }
  if (url.pathname === "/__search_fixture") {
    return send(200, { fixture: "handstrudel-search", searches: searchesByKey.get(key) ?? [] });
  }
  if (url.pathname === "/rest/v1/weekly_challenges") return send(200, []);
  if (url.pathname !== "/rest/v1/feed_videos") return send(404, { message: "Not in the search fixture" });

  // The regular feed is empty; only the exact broad search can surface the clip.
  const filter = url.searchParams.get("or");
  if (filter === null) return send(200, []);
  const searches = searchesByKey.get(key) ?? [];
  searchesByKey.set(key, searches);
  if (filter === handleFilter) {
    searches.push("handle");
    return send(200, []);
  }
  if (filter === broaderFilter) {
    searches.push("broadened");
    return send(200, [clip]);
  }
  searches.push(`unexpected: ${filter}`);
  return send(400, { message: "Unexpected search filter" });
});

server.listen(Number(process.env.PORT ?? 54381), "127.0.0.1", () => {
  console.log(`Search fixture ready at http://127.0.0.1:${server.address().port}`);
});
