"use client";

import Link from "next/link";
import { WatchIcon } from "../app/watch/watch-design";
import { PARAM_DEFS, HYDRA_PARAM_DEFS, INSTRUMENTS, DEFAULT_INSTRUMENT } from "../lib/music";
import {
  MappingConfig,
  DEFAULT_MAPPING,
  DEFAULT_HYDRA_MAPPING,
  DEFAULT_ADVANCED_MAPPING,
  DEFAULT_ADVANCED_HYDRA_MAPPING,
  AXIS_DEFS,
} from "../lib/hand-mapping";
import { useState, useRef } from "react";

interface MappingPreset {
  config: MappingConfig;
  hydraConfig: MappingConfig;
  advanced: boolean;
  instrument?: string;
}

interface StartOverlayProps {
  onStart: (config: MappingConfig, hydraConfig: MappingConfig, advanced: boolean, instrument: string) => void;
  starting: boolean;
  status: string;
  error: string;
}

function GestureArtwork() {
  return (
    <figure className="studio-art" aria-hidden="true">
      <svg className="studio-orbit" viewBox="0 0 380 240" fill="none">
        <path d="M54 120h272M190 15v210" stroke="#b5c4ff" strokeDasharray="3 7" opacity=".45" />
        {Array.from({ length: 9 }, (_, i) => (
          <ellipse key={i} cx="190" cy="120" rx={65 + i * 7} ry={35 + i * 3}
            transform={`rotate(${-49 + i * 12} 190 120)`}
            stroke={i < 3 ? "#e5f298" : "#b5c4ff"} opacity={.84 - i * .06} />
        ))}
        <circle cx="127" cy="102" r="24" fill="#e5f298" fillOpacity=".13" stroke="#e5f298" strokeOpacity=".45" />
        <circle cx="127" cy="102" r="5" fill="#e5f298" />
        <circle cx="255" cy="141" r="20" fill="#e8ecff" fillOpacity=".12" stroke="#e8ecff" strokeOpacity=".5" />
        <circle cx="255" cy="141" r="4" fill="#e8ecff" />
      </svg>
      <figcaption><span>FIG. 01</span><span>GESTURE / SIGNAL</span></figcaption>
    </figure>
  );
}

export default function StartOverlay({ onStart, starting, status, error }: StartOverlayProps) {
  const [advanced, setAdvanced] = useState(false);
  const [config, setConfig] = useState<MappingConfig>({
    left:  { ...DEFAULT_MAPPING.left },
    right: { ...DEFAULT_MAPPING.right },
  });
  const [hydraConfig, setHydraConfig] = useState<MappingConfig>({
    left:  { ...DEFAULT_HYDRA_MAPPING.left },
    right: { ...DEFAULT_HYDRA_MAPPING.right },
  });
  const [instrument, setInstrument] = useState<string>(DEFAULT_INSTRUMENT);

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

  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleExport = () => {
    const preset: MappingPreset = { config, hydraConfig, advanced, instrument };
    const blob = new Blob([JSON.stringify(preset, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "handstrudel-preset.json";
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleImport = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const preset = JSON.parse(reader.result as string) as MappingPreset;
        if (preset.config?.left && preset.config?.right) {
          setConfig(preset.config);
        }
        if (preset.hydraConfig?.left && preset.hydraConfig?.right) {
          setHydraConfig(preset.hydraConfig);
        }
        if (typeof preset.advanced === "boolean") {
          setAdvanced(preset.advanced);
        }
        if (typeof preset.instrument === "string") {
          setInstrument(preset.instrument);
        }
      } catch {
        console.warn("Invalid preset file");
      }
    };
    reader.readAsText(file);
    e.target.value = ""; // allow re-importing same file
  };

  const axes = advanced ? AXIS_DEFS : AXIS_DEFS.filter((a) => a.basic);

  return (
    <main id="start" aria-labelledby="studio-title">
      <div className="studio-intro">
        <div className="studio-intro-copy">
          <p className="studio-eyebrow"><span /> THE BROWSER INSTRUMENT</p>
          <h1 id="studio-title">Make music<br /><em>in the air.</em></h1>
          <p className="studio-lede">Turn your webcam into an instrument. Move your hands to shape a live pattern and hear it change as you play.</p>
          <Link className="studio-watch-link" href="/watch" prefetch={false}>
            <WatchIcon name="play" /> Watch performances <WatchIcon name="next" />
          </Link>
        </div>
        <GestureArtwork />
      </div>

      <div className="studio-setup">
        <div className="studio-setup-heading">
          <p className="studio-index">01 / SETUP</p>
          <h2>Start a session</h2>
          <p>Pick a sound, allow camera access, and hold your hands in view.</p>
        </div>
        <label className="instrument-row">
          <span className="instrument-label">Instrument</span>
          <select className="config-select instrument-select" value={instrument}
            onChange={(e) => setInstrument(e.target.value)}>
            {INSTRUMENTS.map((inst) => (
              <option key={inst.id} value={inst.id}>{inst.label}</option>
            ))}
          </select>
        </label>

        <button id="start-btn" disabled={starting} onClick={() => onStart(config, hydraConfig, advanced, instrument)}>
          <WatchIcon name="play" /> {starting ? status : "Start camera"} <WatchIcon name="next" />
        </button>
        <p className="studio-camera-note" aria-live="polite">
          {starting ? "Your session is opening..." : "Camera stays off until you start. No account needed."}
        </p>
        {error && <p className="studio-error" role="alert">{error}</p>}

        <details className="studio-mappings">
          <summary>Customize gesture mapping <WatchIcon name="chevron" /></summary>
          <div className="studio-mapping-options">
            <p>Choose what each movement changes in the sound and visuals.</p>
            <button className="advanced-toggle" aria-pressed={advanced} onClick={toggleAdvanced}>Advanced</button>
          </div>
          <div className={`config-grid ${advanced ? "config-grid-advanced" : ""}`}>
            {(["left", "right"] as const).map((hand) => (
              <div key={hand} className={`config-col config-${hand}`}>
                <h3 className={`config-title ${hand === "left" ? "gl" : "gr"}`}>{hand} hand</h3>
                {axes.map((axis) => (
                  <div key={axis.key} className="config-row">
                    <span className="config-icon">{axis.label}</span>
                    <select className="config-select"
                      aria-label={`${hand} hand ${axis.label} sound`}
                      value={config[hand][axis.key] ?? "none"}
                      onChange={(e) => update(hand, axis.key, e.target.value)}>
                      <option value="none">No sound</option>
                      {PARAM_DEFS.map((d) => <option key={d.id} value={d.id}>{d.label}</option>)}
                      <option value="save">Save snippet</option>
                      <option value="instrument">Change instrument</option>
                    </select>
                    <select className="config-select config-select-hydra"
                      aria-label={`${hand} hand ${axis.label} visual`}
                      value={hydraConfig[hand][axis.key] ?? "none"}
                      onChange={(e) => updateHydra(hand, axis.key, e.target.value)}>
                      <option value="none">No visual</option>
                      {HYDRA_PARAM_DEFS.map((d) => <option key={d.id} value={d.id}>{d.label}</option>)}
                    </select>
                  </div>
                ))}
              </div>
            ))}
          </div>
          <div className="preset-actions">
            <button className="preset-btn" onClick={handleExport}>Export preset</button>
            <button className="preset-btn" onClick={() => fileInputRef.current?.click()}>Import preset</button>
            <input ref={fileInputRef} type="file" accept=".json" hidden onChange={handleImport} />
          </div>
        </details>
      </div>
    </main>
  );
}
