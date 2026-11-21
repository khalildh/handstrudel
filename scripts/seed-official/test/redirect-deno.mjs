// Test-only: imported before each Edge Function in the local e2e stack (see stack.sh). Sends
// Cloudflare R2 and Sightengine requests to the mock server on the host. Plain JS so the
// web app's TypeScript build doesn't type-check Deno globals.
const base = `http://host.docker.internal:${Deno.env.get("MOCK_PORT") ?? "59490"}`;
const real = globalThis.fetch;
globalThis.fetch = (input, init) => {
  const request = input instanceof Request ? input : null;
  const url = new URL(request ? request.url : String(input));
  let target = null;
  if (url.hostname.endsWith(".r2.cloudflarestorage.com")) target = `${base}/r2/${url.hostname}${url.pathname}${url.search}`;
  if (url.hostname === "api.sightengine.com") target = `${base}/sightengine${url.pathname}`;
  if (!target) return real(input, init);
  return request ? real(new Request(target, request), init) : real(target, init);
};
