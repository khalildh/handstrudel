// Test-only: imported before each Edge Function in the local e2e stack (see e2e.sh). Sends
// Cloudflare R2 and Sightengine requests to the mock server on the host.
const base = `http://host.docker.internal:${Deno.env.get("MOCK_PORT") ?? "59490"}`;
const real = globalThis.fetch;
globalThis.fetch = ((input: Request | URL | string, init?: RequestInit) => {
  const request = input instanceof Request ? input : null;
  const url = new URL(request ? request.url : String(input));
  let target: string | null = null;
  if (url.hostname.endsWith(".r2.cloudflarestorage.com")) target = `${base}/r2/${url.hostname}${url.pathname}${url.search}`;
  if (url.hostname === "api.sightengine.com") target = `${base}/sightengine${url.pathname}`;
  if (!target) return real(input, init);
  return request ? real(new Request(target, request), init) : real(target, init);
}) as typeof fetch;
