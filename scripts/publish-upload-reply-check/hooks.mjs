const stubs = {
  "r2.ts": `export class HttpError extends Error { constructor(s, m) { super(m); this.status = s; } }
    export const handler = (fn) => fn;
    export const caller = async () => ({ id: "aaaaaaaa-0000-0000-0000-000000000001" });
    export const admin = () => globalThis.fakeDb;
    export const privateVideoBucketUrl = () => "bucket";
    export const uploadKeys = () => ({ videoKey: "v", thumbKey: "t" });
    export const deleteKeys = async () => {};`,
  "sightengine.ts": `export const screenUpload = async () => "ok";`,
  "private-video.ts": `export const readPrivateVideo = async () => new Uint8Array();`,
  "video-rollout.ts": `export const videoUploadsEnabledFor = () => true;`,
};
export async function resolve(spec, ctx, next) {
  const name = spec.split("/").pop();
  if (spec.startsWith("../_shared/") && stubs[name]) return { url: "data:text/javascript," + encodeURIComponent(stubs[name]), shortCircuit: true };
  return next(spec, ctx);
}
