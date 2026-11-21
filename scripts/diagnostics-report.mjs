#!/usr/bin/env node
// Crash and hang summary from public.app_diagnostics (MetricKit reports from opted-in installs).
//
//   SUPABASE_SERVICE_ROLE_KEY=… [SUPABASE_URL=…] node scripts/diagnostics-report.mjs \
//     [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--version 1.0.2] [--kind crash|hang|…] [--top 10]
//     [--dsym path/to/HandStrudel.app.dSYM]... [--json]
//
// Prints counts by version/build/kind and the top signatures. A signature is the kind, the
// exception/signal (or hang), and the first app frames of the crashing thread. With --dsym (macOS,
// repeatable: one per archived build, from Xcode Organizer or the .xcarchive), frames from a
// matching binary UUID are symbolicated with `atos`; others show binary + offset.
import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { daysAgo, isoDay, parseArgs, serviceClient, table, today } from "./lib/supabase-service.mjs";

const APP_BINARY = "HandStrudel";
const FRAMES_IN_SIGNATURE = 3;

/** The crashing (attributed) thread's frames, top of stack first. */
export function attributedFrames(payload) {
  const stacks = payload?.callStackTree?.callStacks ?? [];
  const stack = stacks.find((s) => s.threadAttributed) ?? stacks[0];
  const frames = [];
  // MetricKit nests callers as subFrames under the frame they called.
  let frame = stack?.callStackRootFrames?.[0];
  while (frame && frames.length < 256) {
    frames.push(frame);
    frame = frame.subFrames?.[0];
  }
  return frames;
}

export function reason(row) {
  const meta = row.payload?.diagnosticMetaData ?? {};
  switch (row.kind) {
    case "crash": {
      const parts = [];
      if (meta.exceptionType != null) parts.push(`exc ${meta.exceptionType}`);
      if (meta.signal != null) parts.push(`sig ${meta.signal}`);
      if (meta.terminationReason) parts.push(String(meta.terminationReason).slice(0, 60));
      return parts.join(" / ") || "crash";
    }
    case "hang": return "hang";
    default: return row.kind;
  }
}

const frameKey = (f) => `${f.binaryName ?? "?"}+${f.offsetIntoBinaryTextSegment ?? "?"}`;

export function signature(row, symbolicate = frameKey) {
  const frames = attributedFrames(row.payload);
  const app = frames.filter((f) => f.binaryName === APP_BINARY);
  const chosen = (app.length ? app : frames).slice(0, FRAMES_IN_SIGNATURE);
  return `${row.kind} | ${reason(row)} | ${chosen.map(symbolicate).join(" ← ") || "(no stack)"}`;
}

/** Pure: rows → { byVersion, signatures }. */
export function summarize(rows, { top = 10, symbolicate } = {}) {
  const byVersion = new Map();
  const signatures = new Map();
  for (const row of rows) {
    const vk = `${row.app_version} (${row.build})|${row.kind}`;
    byVersion.set(vk, (byVersion.get(vk) ?? 0) + 1);
    const sig = signature(row, symbolicate);
    const entry = signatures.get(sig) ?? { signature: sig, count: 0, versions: new Set(), devices: new Set(), truncated: 0, last: "" };
    entry.count += 1;
    entry.versions.add(`${row.app_version} (${row.build})`);
    entry.devices.add(row.device_model);
    if (row.truncated) entry.truncated += 1;
    if (row.received_at > entry.last) entry.last = row.received_at;
    signatures.set(sig, entry);
  }
  return {
    byVersion: [...byVersion.entries()]
      .map(([key, count]) => {
        const [version, kind] = key.split("|");
        return { version, kind, count };
      })
      .sort((a, b) => b.version.localeCompare(a.version, undefined, { numeric: true }) || b.count - a.count),
    signatures: [...signatures.values()]
      .sort((a, b) => b.count - a.count)
      .slice(0, top)
      .map((s) => ({ ...s, versions: [...s.versions].join(", "), devices: [...s.devices].join(", "), last: s.last.slice(0, 16) })),
  };
}

// ---- symbolication (macOS: dwarfdump + atos) --------------------------------------------------

function dwarfFiles(path) {
  if (!existsSync(path)) throw new Error(`No such dSYM: ${path}`);
  const dir = join(path, "Contents/Resources/DWARF");
  if (existsSync(dir)) return readdirSync(dir).map((f) => join(dir, f));
  return statSync(path).isFile() ? [path] : [];
}

/** Maps binary UUID → DWARF file for every --dsym given. */
function loadDsyms(paths) {
  const byUUID = new Map();
  for (const path of paths) {
    for (const file of dwarfFiles(path)) {
      const out = execFileSync("dwarfdump", ["--uuid", file], { encoding: "utf8" });
      for (const [, uuid, arch] of out.matchAll(/UUID: ([0-9A-F-]+) \((\w+)\)/gi)) {
        byUUID.set(uuid.toUpperCase(), { file, arch });
      }
    }
  }
  return byUUID;
}

/** Symbolicates every frame of every row in one atos call per binary/load address. */
function buildSymbolicator(rows, dsyms) {
  const names = new Map();
  if (dsyms.size === 0) return frameKey;
  const groups = new Map();
  for (const row of rows) {
    for (const f of attributedFrames(row.payload)) {
      const dsym = dsyms.get(String(f.binaryUUID ?? "").toUpperCase());
      if (!dsym || f.address == null || f.offsetIntoBinaryTextSegment == null) continue;
      const load = BigInt(f.address) - BigInt(f.offsetIntoBinaryTextSegment);
      const key = `${dsym.file}|${dsym.arch}|${load}`;
      const group = groups.get(key) ?? { dsym, load, addresses: new Set() };
      group.addresses.add(BigInt(f.address));
      groups.set(key, group);
    }
  }
  for (const { dsym, load, addresses } of groups.values()) {
    const list = [...addresses];
    try {
      const out = execFileSync("atos", ["-arch", dsym.arch, "-o", dsym.file, "-l", `0x${load.toString(16)}`,
        ...list.map((a) => `0x${a.toString(16)}`)], { encoding: "utf8" }).trim().split("\n");
      list.forEach((address, i) => names.set(`${dsym.file}|${address}`, out[i]));
    } catch (error) {
      console.error(`atos failed for ${dsym.file}: ${error.message}`);
    }
  }
  return (f) => {
    const dsym = dsyms.get(String(f.binaryUUID ?? "").toUpperCase());
    const name = dsym && f.address != null ? names.get(`${dsym.file}|${BigInt(f.address)}`) : undefined;
    // atos echoes the bare address when it has no symbol for it.
    return name && !/^0x[0-9a-f]+$/i.test(name) ? name.replace(/ \(in [^)]+\)/, "") : frameKey(f);
  };
}

async function main() {
  const argv = process.argv.slice(2);
  const dsymPaths = [];
  for (let i = argv.length - 2; i >= 0; i--) {
    if (argv[i] === "--dsym") dsymPaths.unshift(...argv.splice(i, 2).slice(1));
  }
  const args = parseArgs(argv, { flags: ["json"], options: ["from", "to", "version", "kind", "top"] });
  const from = isoDay(args.from, daysAgo(29));
  const to = isoDay(args.to, today());
  const filters = [`received_at=gte.${from}T00:00:00Z`, `received_at=lt.${to}T23:59:59.999Z`];
  if (args.version) filters.push(`app_version=eq.${encodeURIComponent(args.version)}`);
  if (args.kind) filters.push(`kind=eq.${encodeURIComponent(args.kind)}`);

  const { url, selectAll } = serviceClient();
  const rows = await selectAll("app_diagnostics",
    `select=id,received_at,kind,app_version,build,os_version,device_model,summary,truncated,payload&${filters.join("&")}&order=received_at.desc`);
  const symbolicate = buildSymbolicator(rows, loadDsyms(dsymPaths));
  const report = summarize(rows, { top: Number(args.top ?? 10), symbolicate });

  if (args.json) {
    console.log(JSON.stringify({ from, to, total: rows.length, ...report }, null, 2));
    return;
  }
  console.log(`Diagnostics ${from} … ${to} (UTC) from ${new URL(url).host}: ${rows.length} reports` +
    (dsymPaths.length ? `, symbolicated with ${dsymPaths.length} dSYM(s)` : ", unsymbolicated (pass --dsym)"));
  console.log("\n## By version");
  console.log(report.byVersion.length ? table(report.byVersion, ["version", "kind", "count"]) : "(none)");
  console.log(`\n## Top ${report.signatures.length} signatures`);
  report.signatures.forEach((s, i) => {
    console.log(`\n${i + 1}. ×${s.count}  ${s.signature}`);
    console.log(`   versions: ${s.versions} · devices: ${s.devices} · last: ${s.last}` +
      (s.truncated ? ` · ${s.truncated} truncated` : ""));
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}
