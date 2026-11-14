import { decode, encode } from "npm:jpeg-js@0.4.4";
import { cleanAvatar } from "./image.ts";

function fixture(width: number, height: number) {
  return Uint8Array.from(encode({
    width, height, data: new Uint8Array(width * height * 4).fill(200),
    comments: ["private metadata"],
  }, 80).data);
}

Deno.test("avatar re-encodes only the selected pixels", () => {
  const jpeg = fixture(64, 64);
  const input = new Uint8Array(jpeg.length + 4);
  input.set(jpeg);
  input.set([12, 34, 56, 78], jpeg.length);
  const result = cleanAvatar(input);
  const decoded = decode(result, { useTArray: true });
  if (decoded.width !== 64 || decoded.height !== 64 || decoded.comments?.length) throw new Error("Invalid re-encode");
  if (result.at(-2) !== 255 || result.at(-1) !== 217) throw new Error("Trailing data retained");
});

Deno.test("avatar rejects non-JPEG, rectangular and oversized images", () => {
  for (const bytes of [new Uint8Array([0, 1, 2]), fixture(32, 64), fixture(513, 513)]) {
    let rejected = false;
    try { cleanAvatar(bytes); } catch { rejected = true; }
    if (!rejected) throw new Error("Invalid image accepted");
  }
});
