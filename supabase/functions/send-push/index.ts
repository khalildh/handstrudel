// POST from pg_cron (push_internal.kick_dispatcher) → sends due notifications through APNs.
// Authenticated by the shared PUSH_DISPATCH_SECRET, not a user session.
// Deno's fetch negotiates HTTP/2 with APNs over ALPN, which APNs requires.
import { admin, handler, HttpError } from "../_shared/r2.ts";
import {
  ApnsTokenCache, apnsEnvironment, apnsRequest, type ClaimedPush, deliveryOutcome, importApnsKey, pushMessage,
  sameSecret,
} from "../_shared/apns.ts";

const env = (name: string) => {
  const value = Deno.env.get(name);
  if (!value) throw new HttpError(500, `${name} is not set`);
  return value;
};

let tokens: ApnsTokenCache | undefined;

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const expected = env("PUSH_DISPATCH_SECRET");
  if (!sameSecret(req.headers.get("x-push-secret") ?? "", expected)) throw new HttpError(401, "unauthorized");

  const apnsEnv = apnsEnvironment(Deno.env.get("APNS_ENV"));
  const bundleId = env("APNS_BUNDLE_ID");
  const privateKey = env("APNS_PRIVATE_KEY");
  tokens ??= new ApnsTokenCache(() => importApnsKey(privateKey), env("APNS_KEY_ID"), env("APNS_TEAM_ID"));
  const db = admin();

  const deadline = Date.now() + 40_000;
  const totals = { sent: 0, failed: 0, removedTokens: 0 };
  while (Date.now() < deadline) {
    const { data, error } = await db.rpc("claim_push_notifications", { batch_size: 100, apns_environment: apnsEnv });
    if (error) throw new HttpError(500, error.message);
    const batch = (data ?? []) as ClaimedPush[];
    if (!batch.length) break;

    const deadTokens = new Set<string>();
    for (let i = 0; i < batch.length; i += 10) {
      await Promise.all(batch.slice(i, i + 10).map(async (notification) => {
        let delivered = false;
        let lastError = "no devices";
        let message;
        try {
          message = pushMessage(notification);
        } catch (e) {
          lastError = e instanceof Error ? e.message : String(e);
        }
        for (const device of message ? notification.tokens : []) {
          const result = await send(apnsEnv, device, bundleId, message!);
          if (result.outcome === "sent") delivered = true;
          else if (result.outcome === "remove-token") deadTokens.add(device);
          else lastError = result.detail;
        }
        const { error: updateError } = await db.from("notifications").update(delivered
          ? { status: "sent", sent_at: new Date().toISOString(), last_error: null }
          : { status: "failed", last_error: lastError.slice(0, 200) })
          .eq("id", notification.id);
        if (updateError) console.error("Couldn't record push result", updateError.message);
        if (delivered) totals.sent++;
        else totals.failed++;
      }));
    }
    if (deadTokens.size) {
      const { error: deleteError } = await db.from("device_tokens").delete().in("token", [...deadTokens]);
      if (deleteError) console.error("Couldn't remove invalid device tokens", deleteError.message);
      else totals.removedTokens += deadTokens.size;
    }
    if (batch.length < 100) break;
  }
  return totals;
}));

async function send(apnsEnv: "sandbox" | "production", device: string, bundleId: string,
                    message: ReturnType<typeof pushMessage>) {
  for (let attempt = 0; attempt < 2; attempt++) {
    let response: Response;
    try {
      response = await fetch(apnsRequest(apnsEnv, device, bundleId, await tokens!.get(), message));
    } catch (e) {
      return { outcome: "failed" as const, detail: e instanceof Error ? e.message : String(e) };
    }
    const reason = response.status === 200
      ? undefined
      : ((await response.json().catch(() => ({}))) as { reason?: string }).reason;
    if (response.status === 200) await response.body?.cancel();
    const outcome = deliveryOutcome(response.status, reason);
    if (outcome === "refresh-auth" && attempt === 0) {
      tokens!.invalidate();
      continue;
    }
    return { outcome, detail: `APNs ${response.status} ${reason ?? ""}`.trim() };
  }
  return { outcome: "failed" as const, detail: "APNs auth rejected" };
}
