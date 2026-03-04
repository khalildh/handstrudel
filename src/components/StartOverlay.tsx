"use client";

import { PARAM_DEFS } from "../lib/music";
import { MappingConfig, DEFAULT_MAPPING } from "../lib/hand-mapping";
import { useState } from "react";

interface StartOverlayProps {
  onStart: (config: MappingConfig) => void;
  fading?: boolean;
}

const AXIS_ICONS = { y: "\u2195", x: "\u2194", spread: "\u270B" } as const;
const AXIS_KEYS = ["y", "x", "spread"] as const;

export default function StartOverlay({ onStart, fading }: StartOverlayProps) {
  const [config, setConfig] = useState<MappingConfig>({
    left:  { ...DEFAULT_MAPPING.left },
    right: { ...DEFAULT_MAPPING.right },
  });

  const update = (hand: "left" | "right", axis: string, value: string) => {
    setConfig((prev) => ({
      ...prev,
      [hand]: { ...prev[hand], [axis]: value },
    }));
  };

  return (
    <div id="start" style={fading ? { opacity: 0 } : undefined}>
      <h1>HANDSTRUDEL</h1>

      <div className="config-grid">
        {(["left", "right"] as const).map((hand) => (
          <div key={hand} className={`config-col config-${hand}`}>
            <div className={`config-title ${hand === "left" ? "gl" : "gr"}`}>
              {hand === "left" ? "LEFT HAND" : "RIGHT HAND"}
            </div>
            {AXIS_KEYS.map((axis) => (
              <div key={axis} className="config-row">
                <span className="config-icon">{AXIS_ICONS[axis]}</span>
                <select
                  className={`config-select config-select-${hand}`}
                  value={config[hand][axis]}
                  onChange={(e) => update(hand, axis, e.target.value)}
                >
                  {PARAM_DEFS.map((d) => (
                    <option key={d.id} value={d.id}>
                      {d.label}
                    </option>
                  ))}
                </select>
              </div>
            ))}
          </div>
        ))}
      </div>

      <button id="start-btn" onClick={() => onStart(config)}>
        ▶ START
      </button>
      <div className="hint">
        allow camera when prompted
        <br />
        hands generate &amp; re-evaluate real Strudel code
      </div>
    </div>
  );
}
