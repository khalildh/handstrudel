export const HAND_CONNECTIONS: [number, number][] = [
  [0, 1], [1, 2], [2, 3], [3, 4],
  [0, 5], [5, 6], [6, 7], [7, 8],
  [0, 9], [9, 10], [10, 11], [11, 12],
  [0, 13], [13, 14], [14, 15], [15, 16],
  [0, 17], [17, 18], [18, 19], [19, 20],
  [5, 9], [9, 13], [13, 17],
];

export function drawHand(
  ctx: CanvasRenderingContext2D,
  lm: { x: number; y: number }[],
  color: string,
  W: number,
  H: number,
): void {
  const x = (i: number) => (1 - lm[i].x) * W;
  const y = (i: number) => lm[i].y * H;

  ctx.strokeStyle = color + "55";
  ctx.lineWidth = 1.5;

  // Draw all connections as a single path (avoids per-segment beginPath/stroke overhead)
  ctx.beginPath();
  for (const [a, b] of HAND_CONNECTIONS) {
    ctx.moveTo(x(a), y(a));
    ctx.lineTo(x(b), y(b));
  }
  ctx.stroke();

  // Batch landmark dots — single fill call per color
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(x(0), y(0), 5, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = color + "aa";
  ctx.beginPath();
  for (let i = 1; i < lm.length; i++) {
    const r = i % 4 === 0 ? 3.5 : 2;
    ctx.moveTo(x(i) + r, y(i));
    ctx.arc(x(i), y(i), r, 0, Math.PI * 2);
  }
  ctx.fill();
}
