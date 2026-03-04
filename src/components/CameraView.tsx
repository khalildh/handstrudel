"use client";

import { RefObject } from "react";

interface CameraViewProps {
  videoRef: RefObject<HTMLVideoElement | null>;
  canvasRef: RefObject<HTMLCanvasElement | null>;
  children?: React.ReactNode;
}

export default function CameraView({
  videoRef,
  canvasRef,
  children,
}: CameraViewProps) {
  return (
    <div id="cam-area">
      <video id="video" ref={videoRef} playsInline muted />
      <canvas id="overlay" ref={canvasRef} />
      {children}
    </div>
  );
}
