"use client";

interface ParamRow {
  label: string;
  fraction: number;
  value: string;
}

interface HandPanelProps {
  side: "left" | "right";
  detected: boolean;
  params: ParamRow[];
}

function PRow({ label, fraction, value }: ParamRow) {
  const pct = (Math.max(0, Math.min(1, fraction)) * 100).toFixed(1);
  return (
    <div className="prow">
      <div className="plabel">{label}</div>
      <div className="ptrack">
        <div className="pfill" style={{ width: `${pct}%` }} />
      </div>
      <div className="pval">{value}</div>
    </div>
  );
}

export default function HandPanel({ side, detected, params }: HandPanelProps) {
  const cls = side === "left" ? "lh" : "rh";
  const title = side === "left" ? "LEFT HAND" : "RIGHT HAND";

  return (
    <div className={`hpanel ${cls}`}>
      <div className="hpanel-title">
        <div className="htitle-dot" />
        {title}
      </div>
      {detected ? (
        params.map((p) => <PRow key={p.label} {...p} />)
      ) : (
        <div className="no-hand">no hand detected</div>
      )}
    </div>
  );
}
