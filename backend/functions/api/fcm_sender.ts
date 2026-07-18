// FCM HTTP v1 sender (docs/features/push-notifications.md). Mints a short-lived
// Google OAuth access token from the Firebase service account (RS256 JWT →
// token endpoint), caches it, and posts messages to
// https://fcm.googleapis.com/v1/projects/{project}/messages:send.
//
// `fetch` and `now` are injectable so the token-minting and message-building
// logic is unit-testable without real credentials or network.
import { importPKCS8, SignJWT } from "npm:jose@5";

export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri: string;
}

export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface PushResult {
  ok: boolean;
  /** True when FCM reports the token is no longer valid (UNREGISTERED /
   * invalid-argument on the token) — the caller should clear it. */
  unregistered?: boolean;
  error?: string;
}

export interface PushSender {
  send(token: string, message: PushMessage): Promise<PushResult>;
}

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

/** Parse the service-account JSON from a secret string; throws on malformed. */
export function parseServiceAccount(raw: string): ServiceAccount {
  const sa = JSON.parse(raw) as Partial<ServiceAccount>;
  if (!sa.project_id || !sa.client_email || !sa.private_key || !sa.token_uri) {
    throw new Error("FCM service account missing project_id/client_email/private_key/token_uri");
  }
  return sa as ServiceAccount;
}

export class FcmSender implements PushSender {
  private token: { value: string; expiresAt: number } | null = null;

  constructor(
    private readonly sa: ServiceAccount,
    private readonly deps: {
      fetch?: typeof fetch;
      now?: () => number;
    } = {},
  ) {}

  private get fetchFn() {
    return this.deps.fetch ?? fetch;
  }
  private get now() {
    return this.deps.now ?? (() => Date.now());
  }

  /** Mint (or reuse) a Google OAuth access token for the FCM scope. */
  async accessToken(): Promise<string> {
    const nowMs = this.now();
    if (this.token && this.token.expiresAt - 60_000 > nowMs) return this.token.value;

    const key = await importPKCS8(this.sa.private_key, "RS256");
    const assertion = await new SignJWT({ scope: FCM_SCOPE })
      .setProtectedHeader({ alg: "RS256" })
      .setIssuer(this.sa.client_email)
      .setSubject(this.sa.client_email)
      .setAudience(this.sa.token_uri)
      .setIssuedAt(Math.floor(nowMs / 1000))
      .setExpirationTime("1h")
      .sign(key);

    const res = await this.fetchFn(this.sa.token_uri, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    });
    if (!res.ok) throw new Error(`OAuth token exchange failed: ${res.status} ${await res.text()}`);
    const json = await res.json() as { access_token: string; expires_in: number };
    this.token = { value: json.access_token, expiresAt: nowMs + json.expires_in * 1000 };
    return json.access_token;
  }

  async send(token: string, message: PushMessage): Promise<PushResult> {
    let accessToken: string;
    try {
      accessToken = await this.accessToken();
    } catch (err) {
      return { ok: false, error: `auth: ${err instanceof Error ? err.message : String(err)}` };
    }

    const url = `https://fcm.googleapis.com/v1/projects/${this.sa.project_id}/messages:send`;
    const payload = {
      message: {
        token,
        notification: { title: message.title, body: message.body },
        ...(message.data ? { data: message.data } : {}),
      },
    };
    const res = await this.fetchFn(url, {
      method: "POST",
      headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (res.ok) return { ok: true };

    const errText = await res.text();
    // 404 UNREGISTERED or 400 with an invalid-token argument → the token is dead.
    const unregistered = res.status === 404 ||
      (res.status === 400 && /registration-token|invalid.*token|UNREGISTERED/i.test(errText));
    return { ok: false, unregistered, error: `${res.status} ${errText}` };
  }
}
