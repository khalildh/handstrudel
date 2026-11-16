import { privateVideoR2 } from "./r2.ts";

export async function readPrivateVideo(bucket: string, key: string, length: number, type: string) {
  const res = await privateVideoR2().fetch(`${bucket}/${key}`, { signal: AbortSignal.timeout(15_000) });
  if (!res.ok || Number(res.headers.get("Content-Length")) !== length || res.headers.get("Content-Type") !== type ||
      res.headers.has("Content-Encoding")) {
    await res.body?.cancel();
    throw new Error("Missing or invalid private upload");
  }
  const bytes = await res.arrayBuffer();
  const prefix = new Uint8Array(bytes, 0, Math.min(8, bytes.byteLength));
  const valid = type === "image/jpeg"
    ? prefix[0] === 0xff && prefix[1] === 0xd8 && prefix[2] === 0xff
    : prefix[4] === 0x66 && prefix[5] === 0x74 && prefix[6] === 0x79 && prefix[7] === 0x70;
  if (bytes.byteLength !== length || !valid) throw new Error("Invalid private media");
  return bytes;
}
