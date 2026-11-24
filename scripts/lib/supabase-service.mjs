// Shared helpers for the service-role report scripts. Node 20+, no dependencies.
//
// SUPABASE_URL                 default http://127.0.0.1:54321 (local stack)
// SUPABASE_SERVICE_ROLE_KEY    required; never printed
//
// The key reads tables that no app role can read, so keep it in your shell environment only.

export function serviceClient() {
  const url = (process.env.SUPABASE_URL || "http://127.0.0.1:54321").replace(/\/$/, "");
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!key) {
    console.error("Set SUPABASE_SERVICE_ROLE_KEY (and SUPABASE_URL for a non-local project).");
    process.exit(2);
  }
  const headers = { apikey: key, Authorization: `Bearer ${key}` };

  /** GET /rest/v1/<table>?<query>, following pages of `pageSize` rows. */
  async function selectAll(table, query, pageSize = 1000) {
    const rows = [];
    for (let from = 0; ; from += pageSize) {
      const res = await fetch(`${url}/rest/v1/${table}?${query}`, {
        headers: { ...headers, "Range-Unit": "items", Range: `${from}-${from + pageSize - 1}` },
      });
      if (!res.ok) throw new Error(`${table}: HTTP ${res.status} ${await res.text()}`);
      const page = await res.json();
      rows.push(...page);
      if (page.length < pageSize) return rows;
    }
  }

  return { url, selectAll };
}

/** Parses `--name value` and `--flag` arguments. */
export function parseArgs(argv, { flags = [], options = [] }) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const name = argv[i].replace(/^--/, "");
    if (flags.includes(name)) out[name] = true;
    else if (options.includes(name) && i + 1 < argv.length) out[name] = argv[++i];
    else {
      console.error(`Unknown argument: ${argv[i]}`);
      process.exit(2);
    }
  }
  return out;
}

export function isoDay(value, fallback) {
  const day = value ?? fallback;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) {
    console.error(`Expected a YYYY-MM-DD date, got ${day}`);
    process.exit(2);
  }
  return day;
}

export const daysAgo = (n) => new Date(Date.now() - n * 86_400_000).toISOString().slice(0, 10);
export const today = () => new Date().toISOString().slice(0, 10);

export function table(rows, columns) {
  const widths = columns.map((c) => Math.max(c.length, ...rows.map((r) => String(r[c] ?? "").length)));
  const line = (cells) => cells.map((cell, i) => {
    const text = String(cell ?? "");
    return typeof cell === "number" || /^[\d.%—-]+$/.test(text) ? text.padStart(widths[i]) : text.padEnd(widths[i]);
  }).join("  ");
  return [line(columns), line(widths.map((w) => "-".repeat(w))), ...rows.map((r) => line(columns.map((c) => r[c])))].join("\n");
}
