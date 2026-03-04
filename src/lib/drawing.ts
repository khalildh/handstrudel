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

  ctx.shadowBlur = 8;
  ctx.shadowColor = color;
  ctx.strokeStyle = color + "55";
  ctx.lineWidth = 1.5;

  for (const [a, b] of HAND_CONNECTIONS) {
    ctx.beginPath();
    ctx.moveTo(x(a), y(a));
    ctx.lineTo(x(b), y(b));
    ctx.stroke();
  }

  ctx.shadowBlur = 10;
  for (let i = 0; i < lm.length; i++) {
    ctx.beginPath();
    ctx.arc(x(i), y(i), i === 0 ? 5 : i % 4 === 0 ? 3.5 : 2, 0, Math.PI * 2);
    ctx.fillStyle = i === 0 ? color : color + "aa";
    ctx.fill();
  }
  ctx.shadowBlur = 0;
}
