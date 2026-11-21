#!/usr/bin/env node
// Admin tool for remote config and the instrument catalog (docs/remote-updates.md). Node 20+, no dependencies.
//
//   SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY=... node scripts/remote-config.mjs <command>
//
//   list                                       All config rows (including disabled ones and notes)
//   set <key> <json-value> [--platform ios|android|web|all] [--min 1.0.3] [--max 1.0.4]
//       [--rollout 0-100] [--priority N] [--note text]   Add a row (checked against shared/remote-config/keys.json)
//   enable <id> | disable <id> | delete <id>   Change one row
//   rollout <id> <0-100>                       Change one row's percentage
//   preview --version 1.0.3 [--platform ios] [--install <id>]   What an install resolves to
//   instruments                                List the instrument catalog
//   publish-instrument <file.json> [--platform ...] [--min 1.0.3] [--order N]   Add or replace a file
//   unpublish-instrument <id>                  Hide a file (keeps the row)
//
// Writes need the service-role key. A non-local SUPABASE_URL also needs --prod.
// --dry-run prints the request instead of sending a write.
import { readdirSync, readFileSync } from "node:fs";

const fromRoot = (path) => new URL(`../${path}`, import.meta.url);
const keys = JSON.parse(readFileSync(fromRoot("shared/remote-config/keys.json"), "utf8")).keys;
const VERSION = /^[0-9]{1,6}(\.[0-9]{1,6}){0,2}$/;
const INSTRUMENT_ID = /^[a-z0-9][a-z0-9._-]{0,79}$/;
const SUPPORTED_INSTRUMENT_FORMAT = 1;
const PLATFORMS = ["all", "ios", "android", "web"];

function fail(message) {
  console.error(`error: ${message}`);
  process.exit(1);
}

function parseArgs(argv) {
  const positional = [];
  const flags = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) { positional.push(arg); continue; }
    const name = arg.slice(2);
    if (["prod", "dry-run"].includes(name)) { flags[name] = true; continue; }
    if (i + 1 >= argv.length) fail(`--${name} needs a value`);
    flags[name] = argv[++i];
  }
  return { positional, flags };
}

const { positional, flags } = parseArgs(process.argv.slice(2));
const [command, ...args] = positional;
const baseURL = (process.env.SUPABASE_URL ?? "http://127.0.0.1:54321").replace(/\/$/, "");
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const isLocal = /^https?:\/\/(127\.0\.0\.1|localhost|\[::1\])(:\d+)?$/.test(baseURL);

async function request(method, path, body, { write = false, upsert = false } = {}) {
  if (!serviceKey) fail("set SUPABASE_SERVICE_ROLE_KEY");
  if (write && !isLocal && !flags.prod) fail(`${baseURL} isn't local; pass --prod to write to it`);
  if (write && flags["dry-run"]) {
    console.log(`[dry run] ${method} ${path}\n${JSON.stringify(body, null, 2)}`);
    return [];
  }
  const response = await fetch(`${baseURL}/rest/v1/${path}`, {
    method,
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
      Prefer: upsert ? "return=representation,resolution=merge-duplicates" : "return=representation",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  if (!response.ok) fail(`${response.status} ${text}`);
  return text ? JSON.parse(text) : [];
}

function checkVersion(value, flag) {
  if (value !== undefined && !VERSION.test(value)) fail(`--${flag} must look like 1.0.3`);
  return value ?? null;
}

function checkPlatform(value) {
  const platform = value ?? "all";
  if (!PLATFORMS.includes(platform)) fail(`--platform must be one of ${PLATFORMS.join(", ")}`);
  return platform;
}

// Same type rules the apps use (shared/remote-config/fixtures/resolve.json).
function checkValue(key, value) {
  const def = keys[key];
  if (!def) fail(`unknown key ${key}; apps ignore it. Known keys: ${Object.keys(keys).join(", ")}`);
  const ok = {
    bool: () => typeof value === "boolean",
    number: () => typeof value === "number" && Number.isFinite(value),
    string: () => typeof value === "string",
    version: () => typeof value === "string" && VERSION.test(value),
    string_array: () => Array.isArray(value) && value.every((item) => typeof item === "string"),
  }[def.type];
  if (!ok?.()) fail(`${key} needs a ${def.type} (JSON), got ${JSON.stringify(value)}`);
  if (def.type === "number" && (value < def.min || value > def.max)) {
    console.warn(`warning: apps clamp ${key} to ${def.min}–${def.max}`);
  }
  if (key === "update.app_store_url" && !value.startsWith("https://apps.apple.com/")) {
    fail("update.app_store_url must start with https://apps.apple.com/");
  }
  if (key === "update.minimum_version") {
    console.warn("warning: every older version will be blocked. Make sure this version is live in the App Store everywhere.");
  }
}

function printRows(rows) {
  if (!rows.length) return;
  console.table(rows.map((row) => ({
    id: row.id, key: row.key, value: JSON.stringify(row.value), platform: row.platform,
    min: row.min_app_version ?? "", max: row.max_app_version ?? "", rollout: row.rollout_percent,
    priority: row.priority, enabled: row.enabled, note: row.note ?? "",
  })));
}

function rowID(value) {
  if (!/^\d+$/.test(value ?? "")) fail("pass a row id from `list`");
  return value;
}

switch (command) {
  case "list":
    printRows(await request("GET", "app_config?select=*&order=key,priority.desc,id.desc"));
    break;

  case "set": {
    const [key, raw] = args;
    if (!key || raw === undefined) fail("usage: set <key> <json-value>");
    let value;
    try { value = JSON.parse(raw); } catch { fail(`value must be JSON (strings need quotes: '"text"'), got ${raw}`); }
    checkValue(key, value);
    const rollout = Number(flags.rollout ?? 100);
    if (!Number.isInteger(rollout) || rollout < 0 || rollout > 100) fail("--rollout must be 0–100");
    const row = {
      key, value, platform: checkPlatform(flags.platform),
      min_app_version: checkVersion(flags.min, "min"), max_app_version: checkVersion(flags.max, "max"),
      rollout_percent: rollout, priority: Number(flags.priority ?? 0), note: flags.note ?? null,
    };
    printRows(await request("POST", "app_config", row, { write: true }));
    break;
  }

  case "enable":
  case "disable":
    printRows(await request("PATCH", `app_config?id=eq.${rowID(args[0])}`, { enabled: command === "enable" }, { write: true }));
    break;

  case "rollout": {
    const percent = Number(args[1]);
    if (!Number.isInteger(percent) || percent < 0 || percent > 100) fail("usage: rollout <id> <0-100>");
    printRows(await request("PATCH", `app_config?id=eq.${rowID(args[0])}`, { rollout_percent: percent }, { write: true }));
    break;
  }

  case "delete":
    printRows(await request("DELETE", `app_config?id=eq.${rowID(args[0])}`, undefined, { write: true }));
    break;

  case "preview": {
    const version = checkVersion(flags.version, "version");
    if (!version) fail("usage: preview --version 1.0.3 [--platform ios] [--install <id>]");
    const platform = flags.platform ?? "ios";
    if (flags.install) {
      const resolved = await request("POST", "rpc/app_config_resolve",
        { p_platform: platform, p_app_version: version, p_install_id: flags.install });
      console.log(JSON.stringify(resolved, null, 2));
    } else {
      const rows = await request("POST", "rpc/app_config_for", { p_platform: platform, p_app_version: version });
      console.table(rows.map((row) => ({ ...row, value: JSON.stringify(row.value) })));
    }
    break;
  }

  case "instruments":
    console.table((await request("GET",
      "instrument_catalog?select=id,format_version,platform,min_app_version,published,sort_order,updated_at&order=sort_order,id")));
    break;

  case "publish-instrument": {
    const [path] = args;
    if (!path) fail("usage: publish-instrument <file.json>");
    const bytes = readFileSync(path);
    if (bytes.length > 16 * 1024) fail("instrument files are limited to 16 KB");
    let body;
    try { body = JSON.parse(bytes.toString("utf8")); } catch { fail("not JSON"); }
    if (body?.format !== "handstrudel.instrument") fail('format must be "handstrudel.instrument"');
    if (!Number.isInteger(body.format_version) || body.format_version < 1) fail("format_version must be a positive integer");
    if (body.format_version > SUPPORTED_INSTRUMENT_FORMAT) {
      console.warn(`warning: format ${body.format_version} is newer than ${SUPPORTED_INSTRUMENT_FORMAT}; only apps that read it will show this file`);
    }
    if (!INSTRUMENT_ID.test(body.id ?? "")) fail("id must match ^[a-z0-9][a-z0-9._-]{0,79}$");
    if (body.id.startsWith("builtin.")) fail("the builtin. prefix is reserved for bundled instruments");
    const bundled = readdirSync(fromRoot("shared/instruments/library")).filter((file) => file.endsWith(".json"))
      .map((file) => JSON.parse(readFileSync(fromRoot(`shared/instruments/library/${file}`), "utf8")).id);
    if (bundled.includes(body.id)) fail(`${body.id} is bundled in the app; bundled files win, so pick another id`);
    if (typeof body.name !== "string" || !body.name.trim()) fail("name is required");
    const row = {
      id: body.id, format_version: body.format_version, body, platform: checkPlatform(flags.platform),
      min_app_version: checkVersion(flags.min, "min"), published: true, sort_order: Number(flags.order ?? 0),
    };
    const saved = await request("POST", "instrument_catalog?on_conflict=id", row, { write: true, upsert: true });
    console.log(`published ${body.id}${saved.length ? "" : " (dry run)"}; apps validate it with InstrumentSpec.load before showing it`);
    break;
  }

  case "unpublish-instrument": {
    const [id] = args;
    if (!INSTRUMENT_ID.test(id ?? "")) fail("usage: unpublish-instrument <id>");
    await request("PATCH", `instrument_catalog?id=eq.${encodeURIComponent(id)}`, { published: false }, { write: true });
    console.log(`unpublished ${id}`);
    break;
  }

  default:
    console.log(readFileSync(new URL(import.meta.url), "utf8").split("\n").filter((line) => line.startsWith("//")).map((line) => line.slice(3)).join("\n"));
    process.exit(command ? 1 : 0);
}
