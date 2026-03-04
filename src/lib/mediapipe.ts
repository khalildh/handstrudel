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
        handsRef.current[side] = {
          x: lm[0].x,
          y: lm[0].y,
          spread: Math.min(1, sp * 2.8),
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
