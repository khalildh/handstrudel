// The send-push loop, with the database and network injected so it can be tested
// against a mocked APNs.
import {
  type ApnsEnvironment, type ApnsTokenCache, apnsRequest, type ClaimedPush, deliveryOutcome, type PushMessage,
  pushMessage,
} from "./apns.ts";

export type DispatchDb = {
  /** `claim_push_notifications`: marks due rows as sending and returns them. */
  claim(batchSize: number, env: ApnsEnvironment): Promise<ClaimedPush[]>;
  finish(id: string, result: { delivered: true } | { delivered: false; error: string }): Promise<void>;
  removeTokens(tokens: string[]): Promise<void>;
};

export type DispatchOptions = {
  db: DispatchDb;
  env: ApnsEnvironment;
  bundleId: string;
  auth: ApnsTokenCache;
  fetch: (request: Request) => Promise<Response>;
  /** Stop claiming new batches after this time (ms since epoch). */
  deadline: number;
  batchSize?: number;
};

export type DispatchTotals = { sent: number; failed: number; removedTokens: number };

export async function dispatch(options: DispatchOptions): Promise<DispatchTotals> {
  const { db, env, bundleId, auth, deadline } = options;
  const batchSize = options.batchSize ?? 100;
  const totals = { sent: 0, failed: 0, removedTokens: 0 };
  while (Date.now() < deadline) {
    const batch = await db.claim(batchSize, env);
    if (!batch.length) break;

    const deadTokens = new Set<string>();
    for (let i = 0; i < batch.length; i += 10) {
      await Promise.all(batch.slice(i, i + 10).map(async (notification) => {
        let delivered = false;
        let lastError = "no devices";
        let message: PushMessage | undefined;
        try {
          message = pushMessage(notification);
        } catch (e) {
          lastError = e instanceof Error ? e.message : String(e);
        }
        for (const device of message ? notification.tokens : []) {
          const result = await send(options, device, message!);
          if (result.outcome === "sent") delivered = true;
          else if (result.outcome === "remove-token") deadTokens.add(device);
          else lastError = result.detail;
        }
        await db.finish(notification.id, delivered ? { delivered } : { delivered, error: lastError.slice(0, 200) });
        if (delivered) totals.sent++;
        else totals.failed++;
      }));
    }
    if (deadTokens.size) {
      await db.removeTokens([...deadTokens]);
      totals.removedTokens += deadTokens.size;
    }
    if (batch.length < batchSize) break;
  }
  return totals;

  async function send(o: DispatchOptions, device: string, message: PushMessage) {
    for (let attempt = 0; attempt < 2; attempt++) {
      let response: Response;
      try {
        response = await o.fetch(apnsRequest(env, device, bundleId, await auth.get(), message));
      } catch (e) {
        return { outcome: "failed" as const, detail: e instanceof Error ? e.message : String(e) };
      }
      const reason = response.status === 200
        ? undefined
        : ((await response.json().catch(() => ({}))) as { reason?: string }).reason;
      if (response.status === 200) await response.body?.cancel();
      const outcome = deliveryOutcome(response.status, reason);
      if (outcome === "refresh-auth" && attempt === 0) {
        auth.invalidate();
        continue;
      }
      return { outcome, detail: `APNs ${response.status} ${reason ?? ""}`.trim() };
    }
    return { outcome: "failed" as const, detail: "APNs auth rejected" };
  }
}
