export type AspectRatio = "16:9" | "9:16" | "1:1";

const ASPECT_SIZES: Record<AspectRatio, { w: number; h: number }> = {
  "16:9": { w: 1280, h: 720 },
  "9:16": { w: 720, h: 1280 },
  "1:1": { w: 720, h: 720 },
};

export interface RecorderOptions {
  /** The webcam video element */
  video: HTMLVideoElement;
  /** The hand-skeleton overlay canvas */
  overlay: HTMLCanvasElement;
  /** Audio stream from the recording destination node */
  audioStream: MediaStream;
  /** Aspect ratio preset */
  aspect: AspectRatio;
}

export interface Recorder {
  start: () => void;
  stop: () => Promise<Blob>;
  readonly recording: boolean;
}

/**
 * Creates a video recorder that composites the camera feed + hand overlay
 * onto an off-screen canvas, captures audio from the provided stream,
 * and records everything via MediaRecorder.
 */
export function createRecorder(opts: RecorderOptions): Recorder {
  const { video, overlay, audioStream, aspect } = opts;
  const { w, h } = ASPECT_SIZES[aspect];

  const comp = document.createElement("canvas");
  comp.width = w;
  comp.height = h;
  const ctx = comp.getContext("2d")!;

  let mediaRecorder: MediaRecorder | null = null;
  let chunks: Blob[] = [];
  let animFrame = 0;
  let isRecording = false;

  function drawFrame() {
    if (!isRecording) return;

    const vw = video.videoWidth || 640;
    const vh = video.videoHeight || 480;

    // Center-crop video to target aspect ratio
    const targetRatio = w / h;
    const videoRatio = vw / vh;

    let sx = 0, sy = 0, sw = vw, sh = vh;
    if (videoRatio > targetRatio) {
      sw = vh * targetRatio;
      sx = (vw - sw) / 2;
    } else {
      sh = vw / targetRatio;
      sy = (vh - sh) / 2;
    }

    // Draw mirrored video (matches CSS scaleX(-1))
    ctx.save();
    ctx.translate(w, 0);
    ctx.scale(-1, 1);
    ctx.drawImage(video, sx, sy, sw, sh, 0, 0, w, h);
    ctx.restore();

    // Dim to match the 35% opacity look
    ctx.fillStyle = "rgba(0, 0, 0, 0.65)";
    ctx.fillRect(0, 0, w, h);

    // Draw hand overlay (scaled to fit)
    const ow = overlay.width || w;
    const oh = overlay.height || h;
    const overlayRatio = ow / oh;

    let ox = 0, oy = 0, odw = w, odh = h;
    if (overlayRatio > targetRatio) {
      odh = w / overlayRatio;
      oy = (h - odh) / 2;
    } else {
      odw = h * overlayRatio;
      ox = (w - odw) / 2;
    }
    ctx.drawImage(overlay, ox, oy, odw, odh);

    // Watermark
    ctx.font = `bold ${Math.round(w * 0.018)}px "JetBrains Mono", monospace`;
    ctx.fillStyle = "rgba(224, 224, 255, 0.3)";
    ctx.textAlign = "left";
    ctx.textBaseline = "bottom";
    ctx.fillText("HANDSTRUDEL", w * 0.03, h * 0.97);

    animFrame = requestAnimationFrame(drawFrame);
  }

  const recorder: Recorder = {
    get recording() {
      return isRecording;
    },

    start() {
      chunks = [];
      isRecording = true;

      const canvasStream = comp.captureStream(30);
      const combined = new MediaStream([
        ...canvasStream.getVideoTracks(),
        ...audioStream.getAudioTracks(),
      ]);

      // Try VP9+opus, fall back to VP8+opus, then default
      let mimeType = "video/webm;codecs=vp9,opus";
      if (!MediaRecorder.isTypeSupported(mimeType)) {
        mimeType = "video/webm;codecs=vp8,opus";
      }
      if (!MediaRecorder.isTypeSupported(mimeType)) {
        mimeType = "video/webm";
      }

      mediaRecorder = new MediaRecorder(combined, {
        mimeType,
        videoBitsPerSecond: 4_000_000,
      });

      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunks.push(e.data);
      };

      mediaRecorder.start(100);
      drawFrame();
    },

    stop() {
      return new Promise<Blob>((resolve) => {
        if (!mediaRecorder || mediaRecorder.state === "inactive") {
          isRecording = false;
          cancelAnimationFrame(animFrame);
          resolve(new Blob(chunks, { type: "video/webm" }));
          return;
        }

        mediaRecorder.onstop = () => {
          isRecording = false;
          cancelAnimationFrame(animFrame);
          resolve(new Blob(chunks, { type: "video/webm" }));
        };

        mediaRecorder.stop();
      });
    },
  };

  return recorder;
}

/** Download a blob as a file */
export function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
