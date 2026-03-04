interface HandLandmark {
  x: number;
  y: number;
  z: number;
}

interface HandResult {
  multiHandLandmarks?: HandLandmark[][];
  multiHandedness?: Array<{ label: string; score: number }>;
}

interface HandsConfig {
  locateFile?: (file: string) => string;
}

interface HandsOptions {
  maxNumHands?: number;
  modelComplexity?: number;
  minDetectionConfidence?: number;
  minTrackingConfidence?: number;
}

declare class Hands {
  constructor(config: HandsConfig);
  setOptions(options: HandsOptions): void;
  onResults(callback: (results: HandResult) => void): void;
  send(input: { image: HTMLVideoElement }): Promise<void>;
}

interface CameraConfig {
  onFrame: () => Promise<void>;
  width?: number;
  height?: number;
}

declare class Camera {
  constructor(video: HTMLVideoElement, config: CameraConfig);
  start(): Promise<void>;
  stop(): void;
}
