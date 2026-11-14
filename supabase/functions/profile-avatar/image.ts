import { decode, encode } from "npm:jpeg-js@0.4.4";

export const MAX_BYTES = 384 * 1024;
export const MAX_SIDE = 512;

export function cleanAvatar(bytes: Uint8Array): Uint8Array<ArrayBuffer> {
  const image = decode(bytes, {
    useTArray: true,
    tolerantDecoding: false,
    maxResolutionInMP: 0.27,
    maxMemoryUsageInMB: 12,
  });
  if (image.width < 1 || image.width !== image.height || image.width > MAX_SIDE) {
    throw new Error("Photo must be square and at most 512 pixels across");
  }
  // Re-encode only the pixels, not metadata, comments or appended files.
  return Uint8Array.from(encode({ data: image.data, width: image.width, height: image.height }, 84).data);
}
