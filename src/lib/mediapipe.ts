import { HandsState } from "./hand-mapping";
import { drawHand } from "./drawing";

function loadScript(src: string): Promise<void> {
  return new Promise((resolve, reject) => {
    if (document.querySelector(`script[src="${src}"]`)) {
      resolve();
      return;
    }
    const script = document.createElement("script");
    script.src = src;
    script.crossOrigin = "anonymous";
    script.onload = () => resolve();
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

function computeAdvancedAxes(lm: HandLandmark[]) {
  const dist = (a: HandLandmark, b: HandLandmark) =>
    Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);

  // Individual finger curls: dist(tip, mcp), scaled and clamped (1 = extended)
  const thumbCurl  = Math.min(1, dist(lm[4],  lm[2])  * 4);
  const indexCurl  = Math.min(1, dist(lm[8],  lm[5])  * 4);
  const middleCurl = Math.min(1, dist(lm[12], lm[9])  * 4);
  const ringCurl   = Math.min(1, dist(lm[16], lm[13]) * 4);
  const pinkyCurl  = Math.min(1, dist(lm[20], lm[17]) * 4);

  // Pinch: 1 = pinching (thumb tip close to index tip)
  const pinch = Math.max(0, Math.min(1, 1 - dist(lm[4], lm[8]) * 5));

  // Fist: average of 5 inverted finger curls (1 = closed)
  const fist = 1 - (thumbCurl + indexCurl + middleCurl + ringCurl + pinkyCurl) / 5;

  // Rotation: atan2 from wrist to middle_mcp, normalized 0–1
  const dx = lm[9].x - lm[0].x;
  const dy = lm[9].y - lm[0].y;
  const rotation = (Math.atan2(dy, dx) / Math.PI + 1) / 2;

  return { pinch, fist, rotation, thumbCurl, indexCurl, middleCurl, ringCurl, pinkyCurl };
}

export async function initializeMediaPipe(
  videoEl: HTMLVideoElement,
  canvasEl: HTMLCanvasElement,
  handsRef: React.MutableRefObject<HandsState>,
  onParams: () => void,
): Promise<void> {
  await loadScript(
    "https://cdn.jsdelivr.net/npm/@mediapipe/hands/hands.js",
  );
  await loadScript(
    "https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js",
  );

  const hands = new Hands({
    locateFile: (f: string) =>
      `https://cdn.jsdelivr.net/npm/@mediapipe/hands/${f}`,
  });

  hands.setOptions({
    maxNumHands: 2,
    modelComplexity: 1,
    minDetectionConfidence: 0.65,
    minTrackingConfidence: 0.5,
  });

  hands.onResults((res: HandResult) => {
    const drawCtx = canvasEl.getContext("2d")!;
    const W = videoEl.videoWidth || 640;
    const H = videoEl.videoHeight || 480;
    canvasEl.width = W;
    canvasEl.height = H;
    drawCtx.clearRect(0, 0, W, H);

    handsRef.current = { left: null, right: null };

    if (res.multiHandLandmarks) {
      for (let i = 0; i < res.multiHandLandmarks.length; i++) {
        const lm = res.multiHandLandmarks[i];
        const side =
          res.multiHandedness![i].label === "Left" ? "right" : "left";
        const sp = Math.hypot(
          lm[4].x - lm[20].x,
          lm[4].y - lm[20].y,
        );
        const advanced = computeAdvancedAxes(lm);
        handsRef.current[side] = {
          x: lm[0].x,
          y: lm[0].y,
          spread: Math.min(1, sp * 2.8),
          ...advanced,
          lm,
        };
        drawHand(
          drawCtx,
          lm,
          side === "left" ? "#00ff9d" : "#ff2d6b",
          W,
          H,
        );
      }
    }

    onParams();
  });

  const camera = new Camera(videoEl, {
    onFrame: async () => {
      await hands.send({ image: videoEl });
    },
    width: 640,
    height: 480,
  });

  await camera.start();
}
