#!/usr/bin/env node
// Growth-funnel conversion from the opt-in daily counters in public.app_usage_daily.
//
//   SUPABASE_SERVICE_ROLE_KEY=… [SUPABASE_URL=…] node scripts/funnel-report.mjs \
//     [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--json]
//
// Defaults to the last 14 UTC days including today. Counts are summed daily totals from opted-in
// installs, not per-person cohorts: "conversion" is the ratio of totals between steps in the range,
// so a step can exceed 100% (one share opened by several people, say).
import { daysAgo, isoDay, parseArgs, serviceClient, table, today } from "./lib/supabase-service.mjs";

export const FUNNELS = [
  { name: "Activation", steps: ["active_day", "first_note", "recording_started", "recording_saved", "first_post_published"] },
  { name: "Store", steps: ["store_viewed", "purchase_started", "purchase_completed"], byDetail: true },
  { name: "Locked sounds", steps: ["play_this_sound_tapped", "locked_sound_tapped", "locked_sound_unlocked"] },
  { name: "Invites", steps: ["invite_link_shared", "invite_code_redeemed", "invited_first_post"] },
  { name: "Challenges & replies", steps: ["challenge_link_shared", "challenge_link_opened", "reply_started", "reply_posted"] },
  { name: "Daily sound", steps: ["daily_sound_opened", "daily_take_posted", "streak_extended"] },
  { name: "Sound pages", steps: ["sound_page_opened", "play_this_sound_tapped"] },
];

const pct = (n, d) => (d > 0 ? `${((100 * n) / d).toFixed(1)}%` : "—");

/** Pure: totals per event (and per event+detail) → funnel step rows. */
export function buildReport(rows) {
  const totals = new Map();
  const details = new Map();
  for (const { event, detail, events } of rows) {
    totals.set(event, (totals.get(event) ?? 0) + Number(events));
    if (detail) {
      const key = `${event}:${detail}`;
      details.set(key, (details.get(key) ?? 0) + Number(events));
    }
  }
  const funnels = FUNNELS.map(({ name, steps, byDetail }) => {
    const counts = steps.map((s) => totals.get(s) ?? 0);
    return {
      name,
      steps: steps.map((step, i) => ({
        step,
        count: counts[i],
        fromPrevious: i === 0 ? "" : pct(counts[i], counts[i - 1]),
        fromFirst: i === 0 ? "" : pct(counts[i], counts[0]),
      })),
      products: byDetail
        ? ["pro", "plus_monthly", "plus_yearly"].map((product) => {
          const started = details.get(`purchase_started:${product}`) ?? 0;
          const completed = details.get(`purchase_completed:${product}`) ?? 0;
          return { product, started, completed, completion: pct(completed, started) };
        })
        : undefined,
    };
  });
  const notifications = [...details.entries()]
    .filter(([key]) => key.startsWith("notification_opened:"))
    .map(([key, opened]) => ({ type: key.split(":")[1], opened }))
    .sort((a, b) => b.opened - a.opened);
  return { funnels, notifications, totals: Object.fromEntries(totals) };
}

async function main() {
  const args = parseArgs(process.argv.slice(2), { flags: ["json"], options: ["from", "to"] });
  const from = isoDay(args.from, daysAgo(13));
  const to = isoDay(args.to, today());
  const { url, selectAll } = serviceClient();
  const rows = await selectAll("app_usage_daily", `select=day,event,detail,events&day=gte.${from}&day=lte.${to}`);
  const report = buildReport(rows);

  if (args.json) {
    console.log(JSON.stringify({ from, to, ...report }, null, 2));
    return;
  }
  console.log(`Funnel report ${from} … ${to} (UTC) from ${new URL(url).host}: ${rows.length} daily rows`);
  console.log("Totals are opt-in daily counts, not cohorts; a step can exceed 100%.\n");
  for (const funnel of report.funnels) {
    console.log(`## ${funnel.name}`);
    console.log(table(funnel.steps, ["step", "count", "fromPrevious", "fromFirst"]));
    if (funnel.products) {
      console.log("\nBy product");
      console.log(table(funnel.products, ["product", "started", "completed", "completion"]));
    }
    console.log("");
  }
  console.log("## Notifications opened");
  console.log(report.notifications.length ? table(report.notifications, ["type", "opened"]) : "(none)");
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}
