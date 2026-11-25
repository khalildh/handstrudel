// APNs token-based (.p8) auth and notification payloads. No npm imports, so the
// tests also run under Node's test runner.

export type ApnsEnvironment = "sandbox" | "production";

export function apnsEnvironment(value: string | undefined): ApnsEnvironment {
  if (value === "sandbox" || value === "production") return value;
  throw new Error("APNS_ENV must be sandbox or production");
}

export const apnsHost = (env: ApnsEnvironment) =>
  env === "production" ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";

const encoder = new TextEncoder();

export function base64url(bytes: Uint8Array | string): string {
  const data = typeof bytes === "string" ? encoder.encode(bytes) : bytes;
  let binary = "";
  for (const byte of data) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** Imports the contents of an AuthKey_XXXX.p8 file. Accepts `\n` escapes from secret stores. */
export function importApnsKey(pem: string): Promise<CryptoKey> {
  const body = pem.replace(/\\n/g, "\n")
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  if (!body) throw new Error("APNS_PRIVATE_KEY is empty");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}

/** ES256 provider token. WebCrypto already returns the raw r||s signature JWS expects. */
export async function apnsJwt(key: CryptoKey, keyId: string, teamId: string, issuedAt: number): Promise<string> {
  const input = `${base64url(JSON.stringify({ alg: "ES256", kid: keyId }))}.${
    base64url(JSON.stringify({ iss: teamId, iat: issuedAt }))}`;
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, encoder.encode(input));
  return `${input}.${base64url(new Uint8Array(signature))}`;
}

/** Reuses one token for 50 minutes; APNs rejects tokens older than an hour or refreshed too often. */
export class ApnsTokenCache {
  private token?: { value: string; issuedAt: number };
  private key: () => Promise<CryptoKey>;
  private keyId: string;
  private teamId: string;
  private now: () => number;

  constructor(key: () => Promise<CryptoKey>, keyId: string, teamId: string,
              now: () => number = () => Math.floor(Date.now() / 1000)) {
    this.key = key;
    this.keyId = keyId;
    this.teamId = teamId;
    this.now = now;
  }

  async get(): Promise<string> {
    const now = this.now();
    if (this.token && now - this.token.issuedAt < 50 * 60) return this.token.value;
    this.token = { value: await apnsJwt(await this.key(), this.keyId, this.teamId, now), issuedAt: now };
    return this.token.value;
  }

  invalidate() {
    this.token = undefined;
  }
}

/** One row from `claim_push_notifications`. */
export type ClaimedPush = {
  id: string;
  kind: "remix" | "take_reply" | "like" | "comment" | "following_post" | "challenge";
  actor_username: string | null;
  actor_count: number | null;
  video_id: string | null;
  comment_body: string | null;
  video_caption: string | null;
  challenge_title: string | null;
  tokens: string[];
};

export type PushMessage = {
  payload: { aps: Record<string, unknown>; link?: string; kind: string };
  collapseId?: string;
};

export function clip(text: string | null | undefined, limit: number): string {
  const characters = Array.from((text ?? "").replace(/\s+/g, " ").trim());
  return characters.length <= limit ? characters.join("") : `${characters.slice(0, limit - 1).join("")}…`;
}

export function likeText(username: string, count: number): string {
  const others = Math.max(0, count - 1);
  if (others === 0) return `@${username} liked your post.`;
  return `@${username} and ${others} ${others === 1 ? "other" : "others"} liked your post.`;
}

/** Alert text and the in-app link (existing handstrudel:// routes) for one notification. */
export function pushMessage(n: ClaimedPush): PushMessage {
  const who = `@${n.actor_username ?? "someone"}`;
  const watch = n.video_id ? `handstrudel://watch/${n.video_id}` : undefined;
  let title = "HandStrudel";
  let body: string;
  let link = watch;
  let collapseId: string | undefined;
  switch (n.kind) {
    case "remix":
      title = "New play-along";
      body = `${who} played along with your post.`;
      break;
    case "take_reply":
      title = "New take";
      body = `${who} replied to your post with a take.`;
      break;
    case "like":
      body = likeText(n.actor_username ?? "someone", n.actor_count ?? 1);
      // A later batch for the same post replaces the earlier banner.
      collapseId = n.video_id ? `like-${n.video_id}` : undefined;
      break;
    case "comment": {
      const comment = clip(n.comment_body, 120);
      body = comment ? `${who} commented: ${comment}` : `${who} commented on your post.`;
      link = n.video_id ? `handstrudel://comments/${n.video_id}` : undefined;
      break;
    }
    case "following_post": {
      const caption = clip(n.video_caption, 100);
      body = caption ? `${who} posted: ${caption}` : `${who} posted a new performance.`;
      break;
    }
    case "challenge":
      title = "New weekly challenge";
      body = `${clip(n.challenge_title, 60) || "This week's challenge"} is live. Play along now.`;
      break;
    default:
      throw new Error(`Unknown notification kind: ${(n as { kind: string }).kind}`);
  }
  return {
    payload: {
      aps: { alert: { title, body }, sound: "default", "thread-id": n.kind },
      ...(link ? { link } : {}),
      kind: n.kind,
    },
    collapseId,
  };
}

export type DeliveryOutcome = "sent" | "remove-token" | "refresh-auth" | "failed";

/** What to do with an APNs response. 410, and a bad token for this environment, mean the token is dead. */
export function deliveryOutcome(status: number, reason: string | undefined): DeliveryOutcome {
  if (status === 200) return "sent";
  if (status === 410) return "remove-token";
  if (status === 400 && (reason === "BadDeviceToken" || reason === "DeviceTokenNotForTopic")) return "remove-token";
  if (status === 403 && (reason === "ExpiredProviderToken" || reason === "InvalidProviderToken")) return "refresh-auth";
  return "failed";
}

export function apnsRequest(env: ApnsEnvironment, token: string, bundleId: string, jwt: string,
                            message: PushMessage): Request {
  const headers: Record<string, string> = {
    authorization: `bearer ${jwt}`,
    "apns-topic": bundleId,
    "apns-push-type": "alert",
    "apns-priority": "10",
    // Give up after a day; stale social pushes aren't useful.
    "apns-expiration": String(Math.floor(Date.now() / 1000) + 24 * 60 * 60),
    "content-type": "application/json",
  };
  if (message.collapseId) headers["apns-collapse-id"] = message.collapseId;
  return new Request(`${apnsHost(env)}/3/device/${token}`, {
    method: "POST", headers, body: JSON.stringify(message.payload),
  });
}

/** Constant-time comparison for the dispatcher's shared secret. */
export function sameSecret(given: string, expected: string): boolean {
  const a = encoder.encode(given);
  const b = encoder.encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return diff === 0 && b.length > 0;
}
