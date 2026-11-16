import { presignPut, privateVideoBucketUrl, uploadKeys } from "./r2.ts";

Deno.test("private video upload signs the no-overwrite precondition", async () => {
  const settings = {
    R2_ACCOUNT_ID: "test-account",
    R2_BUCKET: "legacy-bucket",
    R2_VIDEO_STAGING_BUCKET: "private-bucket",
    R2_VIDEO_STAGING_ACCESS_KEY_ID: "test-key",
    R2_VIDEO_STAGING_SECRET_ACCESS_KEY: "test-secret",
  };
  const old = Object.keys(settings).map((name) => [name, Deno.env.get(name)] as const);
  try {
    for (const [key, value] of Object.entries(settings)) Deno.env.set(key, value);
    const { videoKey } = uploadKeys("user", "post");
    const signed = new URL(await presignPut(videoKey, "video/mp4", 1234, privateVideoBucketUrl()));
    if (signed.pathname !== "/private-bucket/videos/user/screened/post.mp4") throw new Error("Wrong upload key");
    const headers = signed.searchParams.get("X-Amz-SignedHeaders")?.split(";");
    for (const header of ["content-type", "content-length", "if-none-match"]) {
      if (!headers?.includes(header)) throw new Error(`Missing signed header: ${header}`);
    }
  } finally {
    for (const [name, value] of old) {
      if (value === undefined) Deno.env.delete(name);
      else Deno.env.set(name, value);
    }
  }
});
