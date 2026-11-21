// POST from pg_cron (push_internal.kick_dispatcher) → sends due notifications through APNs.
// Authenticated by the shared PUSH_DISPATCH_SECRET, not a user session.
// Deno's fetch negotiates HTTP/2 with APNs over ALPN, which APNs requires.
import { admin, handler, HttpError } from "../_shared/r2.ts";
import { ApnsTokenCache, apnsEnvironment, type ClaimedPush, importApnsKey, sameSecret } from "../_shared/apns.ts";
import { dispatch } from "../_shared/push-dispatch.ts";

const env = (name: string) => {
  const value = Deno.env.get(name);
  if (!value) throw new HttpError(500, `${name} is not set`);
  return value;
};

let auth: ApnsTokenCache | undefined;

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  if (!sameSecret(req.headers.get("x-push-secret") ?? "", env("PUSH_DISPATCH_SECRET"))) {
    throw new HttpError(401, "unauthorized");
  }
  const privateKey = env("APNS_PRIVATE_KEY");
  auth ??= new ApnsTokenCache(() => importApnsKey(privateKey), env("APNS_KEY_ID"), env("APNS_TEAM_ID"));
  const db = admin();

  return await dispatch({
    env: apnsEnvironment(Deno.env.get("APNS_ENV")),
    bundleId: env("APNS_BUNDLE_ID"),
    auth,
    fetch: (request) => fetch(request),
    deadline: Date.now() + 40_000,
    db: {
      async claim(batchSize, apnsEnv) {
        const { data, error } = await db.rpc("claim_push_notifications",
          { batch_size: batchSize, apns_environment: apnsEnv });
        if (error) throw new HttpError(500, error.message);
        return (data ?? []) as ClaimedPush[];
      },
      async finish(id, result) {
        const { error } = await db.from("notifications").update(result.delivered
          ? { status: "sent", sent_at: new Date().toISOString(), last_error: null }
          : { status: "failed", last_error: result.error })
          .eq("id", id);
        if (error) console.error("Couldn't record push result", error.message);
      },
      async removeTokens(tokens) {
        const { error } = await db.from("device_tokens").delete().in("token", tokens);
        if (error) console.error("Couldn't remove invalid device tokens", error.message);
      },
    },
  });
}));
