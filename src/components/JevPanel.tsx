"use client";

import { useState } from "react";
import { jevReady, type JevConfig } from "../lib/jev";
import type { JevStatus } from "../lib/jev-director";

interface JevPanelProps {
  config: JevConfig;
  status: JevStatus;
  onConfigChange: (cfg: JevConfig) => void;
  onApplyInstrument: (id: string) => void;
}

function pct(v: number): string {
  return `${Math.round(Math.max(0, Math.min(1, v)) * 100)}%`;
}

export default function JevPanel({
  config,
  status,
  onConfigChange,
  onApplyInstrument,
}: JevPanelProps) {
  const configured = config.proxyUrl.trim() !== "" || config.apiKey.trim() !== "";
  const [setupOpen, setSetupOpen] = useState(false);
  const [keyDraft, setKeyDraft] = useState(config.apiKey);
  const [proxyDraft, setProxyDraft] = useState(config.proxyUrl);

  const handleToggle = () => {
    const next = { ...config, enabled: !config.enabled };
    onConfigChange(next);
    if (next.enabled && !configured) setSetupOpen(true);
  };

  const handleSave = () => {
    onConfigChange({ ...config, apiKey: keyDraft.trim(), proxyUrl: proxyDraft.trim() });
    setSetupOpen(false);
  };

  const live = jevReady(config);
  const phaseClass =
    status.phase === "error" ? " jev-stat-error" : status.phase === "ok" ? " jev-stat-ok" : "";

  return (
    <div className="jev-panel">
      <div className="jev-header">
        <span className="jev-title">⚡ JEV</span>
        <button className="jev-setup-btn" onClick={() => setSetupOpen((v) => !v)}>
          {setupOpen ? "close" : "setup"}
        </button>
        <button
          className={`jev-btn${config.enabled ? " jev-btn-active" : ""}`}
          onClick={handleToggle}
        >
          {config.enabled ? "on" : "off"}
        </button>
      </div>

      {setupOpen && (
        <div className="jev-setup">
          <label className="jev-field">
            <span>proxy url</span>
            <input
              type="text"
              value={proxyDraft}
              placeholder="https://… (recommended)"
              onChange={(e) => setProxyDraft(e.target.value)}
            />
          </label>
          <label className="jev-field">
            <span>api key</span>
            <input
              type="password"
              value={keyDraft}
              placeholder="used only without a proxy"
              onChange={(e) => setKeyDraft(e.target.value)}
            />
          </label>
          <div className="jev-note">
            A key here is stored in this browser and sent straight from the page —
            fine for your own machine, not for a shared deployment. A proxy keeps it
            server-side.
          </div>
          <button className="jev-save-btn" onClick={handleSave}>
            save
          </button>
        </div>
      )}

      {config.enabled && !configured && (
        <div className="jev-stat jev-stat-error">needs a proxy url or api key</div>
      )}

      {live && (
        <>
          <div className={`jev-stat${phaseClass}`}>
            {status.phase === "asking" && "asking…"}
            {status.phase === "idle" && "waiting for first window"}
            {status.phase === "error" && `fallback — ${status.message}`}
            {status.phase === "ok" &&
              `${status.calls} call${status.calls === 1 ? "" : "s"} · ${status.latencyMs}ms`}
          </div>

          {status.patternChoice && (
            <div className="jev-row">
              <span className="jev-row-key">pattern</span>
              <span className="jev-row-val">{status.patternChoice}</span>
              <span className="jev-row-conf">{pct(status.patternConfidence)}</span>
            </div>
          )}

          {status.instrumentLabel && status.instrumentId && (
            <div className="jev-row">
              <span className="jev-row-key">sound</span>
              <span className="jev-row-val">{status.instrumentLabel}</span>
              <span className="jev-row-conf">{pct(status.instrumentConfidence)}</span>
              <button
                className="jev-apply-btn"
                onClick={() => onApplyInstrument(status.instrumentId as string)}
              >
                use
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
