"use client";

import { PARAM_DEFS, HYDRA_PARAM_DEFS } from "../lib/music";
import {
  MappingConfig,
  DEFAULT_MAPPING,
  DEFAULT_HYDRA_MAPPING,
  DEFAULT_ADVANCED_MAPPING,
  DEFAULT_ADVANCED_HYDRA_MAPPING,
  AXIS_DEFS,
} from "../lib/hand-mapping";
import { useState } from "react";

interface StartOverlayProps {
  onStart: (config: MappingConfig, hydraConfig: MappingConfig, advanced: boolean) => void;
  fading?: boolean;
}

export default function StartOverlay({ onStart, fading }: StartOverlayProps) {
  const [advanced, setAdvanced] = useState(false);
  const [config, setConfig] = useState<MappingConfig>({
    left:  { ...DEFAULT_MAPPING.left },
    right: { ...DEFAULT_MAPPING.right },
  });
  const [hydraConfig, setHydraConfig] = useState<MappingConfig>({
    left:  { ...DEFAULT_HYDRA_MAPPING.left },
    right: { ...DEFAULT_HYDRA_MAPPING.right },
  });

  const toggleAdvanced = () => {
    setAdvanced((prev) => {
      const next = !prev;
      if (next) {
        setConfig((c) => ({
          left:  { ...DEFAULT_ADVANCED_MAPPING.left,  ...c.left },
          right: { ...DEFAULT_ADVANCED_MAPPING.right, ...c.right },
        }));
        setHydraConfig((c) => ({
          left:  { ...DEFAULT_ADVANCED_HYDRA_MAPPING.left,  ...c.left },
          right: { ...DEFAULT_ADVANCED_HYDRA_MAPPING.right, ...c.right },
        }));
      } else {
        setConfig((c) => ({
          left:  { y: c.left.y,  x: c.left.x,  spread: c.left.spread },
          right: { y: c.right.y, x: c.right.x, spread: c.right.spread },
        }));
        setHydraConfig((c) => ({
          left:  { y: c.left.y,  x: c.left.x,  spread: c.left.spread },
          right: { y: c.right.y, x: c.right.x, spread: c.right.spread },
        }));
      }
      return next;
    });
  };

  const update = (hand: "left" | "right", axis: string, value: string) => {
    setConfig((prev) => ({
      ...prev,
      [hand]: { ...prev[hand], [axis]: value },
    }));
  };

  const updateHydra = (hand: "left" | "right", axis: string, value: string) => {
    setHydraConfig((prev) => ({
      ...prev,
      [hand]: { ...prev[hand], [axis]: value },
    }));
  };

  const axes = advanced ? AXIS_DEFS : AXIS_DEFS.filter((a) => a.basic);

  return (
    <div id="start" style={fading ? { opacity: 0 } : undefined}>
      <h1>HANDSTRUDEL</h1>

      <button
        className="advanced-toggle"
        onClick={toggleAdvanced}
      >
        {advanced ? "ADVANCED" : "SIMPLE"}
      </button>

      <div className={`config-grid ${advanced ? "config-grid-advanced" : ""}`}>
        {(["left", "right"] as const).map((hand) => (
          <div
            key={hand}
            className={`config-col ${advanced ? "config-col-advanced" : ""} config-${hand}`}
          >
            <div className={`config-title ${hand === "left" ? "gl" : "gr"}`}>
              {hand === "left" ? "LEFT HAND" : "RIGHT HAND"}
            </div>
            {axes.map((axis) => (
              <div key={axis.key} className={`config-row ${advanced ? "config-row-compact" : ""}`}>
                <span className="config-icon">{axis.icon}</span>
                <select
                  className={`config-select config-select-${hand}`}
                  value={config[hand][axis.key] ?? "none"}
                  onChange={(e) => update(hand, axis.key, e.target.value)}
                >
                  <option value="none">—</option>
                  {PARAM_DEFS.map((d) => (
                    <option key={d.id} value={d.id}>
                      {d.label}
                    </option>
                  ))}
                  <option value="save">💾 save</option>
                </select>
                <select
                  className={`config-select config-select-hydra`}
                  value={hydraConfig[hand][axis.key] ?? "none"}
                  onChange={(e) => updateHydra(hand, axis.key, e.target.value)}
                >
                  <option value="none">—</option>
                  {HYDRA_PARAM_DEFS.map((d) => (
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

      <button id="start-btn" onClick={() => onStart(config, hydraConfig, advanced)}>
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
