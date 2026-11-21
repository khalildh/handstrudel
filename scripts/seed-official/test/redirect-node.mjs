// Test-only preload (`node --import`): sends Cloudflare R2 requests to the local mock server.
const port = process.env.MOCK_PORT || 59490;
const real = globalThis.fetch;
globalThis.fetch = (input, init) => {
  const url = new URL(typeof input === 'string' || input instanceof URL ? input : input.url);
  if (url.hostname.endsWith('.r2.cloudflarestorage.com')) {
    return real(`http://127.0.0.1:${port}/r2/${url.hostname}${url.pathname}${url.search}`, init);
  }
  return real(input, init);
};
