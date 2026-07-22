// Phase 8 — push delivery. Originally broadcast-only; Version 2, Phase
// M2 fix added targeted (single-recipient) delivery on top — see the
// target_user_id handling below and 0021_notifications_targeting.sql.
//
// Invoked by a Supabase Database Webhook on INSERT into public.notifications
// (see the webhook config drafted alongside this file — NOT YET CREATED,
// that step needs a human click-through in the Dashboard; there's no MCP/CLI
// primitive for it). The webhook payload shape is Supabase's standard
// `{ type, table, schema, record, old_record }`.
//
// Auth model: this function keeps JWT verification ON (the default). The
// Database Webhook must be configured to send `Authorization: Bearer
// <service_role_key>` — set that up via the Dashboard's own webhook editor,
// which lets you attach the key without it ever passing through chat or a
// file. Never disable verify_jwt here: this function reads title/body
// straight from the request body and blasts them to every registered
// device (or, now, a specific one), so an unauthenticated version of this
// endpoint would be an open mass-push spam vector.
//
// Credentials: the Firebase service account is read from the
// FIREBASE_SERVICE_ACCOUNT secret (Deno.env.get) — never hardcoded.
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are auto-injected into every
// Edge Function by the platform; no need to set those ourselves. The
// service-role client is required here specifically to read device_tokens,
// which has no SELECT policy for any client role by design (see the
// device_tokens migration) — only this server-side, service-role path can
// ever read raw tokens.
//
// DEPLOYMENT NOTE: this file was updated for target_user_id filtering as
// part of the Phase M2 fix, but has NOT been redeployed — the deployed
// version (as of this change) is still the Phase 8 broadcast-only
// original. Redeploying is a deliberate follow-up step via Claude Code's
// Supabase MCP connection, not done automatically by this change. Until
// that redeploy happens, EVERY notification — targeted or not — still
// broadcasts to all device_tokens, because the currently-live function
// doesn't know about target_user_id at all.
import { createClient } from "npm:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

interface NotificationRecord {
  id: string;
  title: string;
  body: string;
  // Version 2, Phase M2 fix. Absent/null = broadcast to everyone
  // (original Phase 8 behavior, unchanged). Set = deliver only to
  // this user's device tokens — see 0021_notifications_targeting.sql.
  target_user_id?: string | null;
}

interface WebhookPayload {
  type?: string;
  table?: string;
  record?: NotificationRecord;
}

Deno.serve(async (req: Request) => {
  console.log("[send-push-notification] invoked");

  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch (e) {
    console.error("[send-push-notification] request body was not valid JSON:", e);
    return new Response("invalid JSON body", { status: 400 });
  }
  console.log("[send-push-notification] payload:", JSON.stringify(payload));

  const notification = payload.record;
  if (!notification?.title || !notification?.body) {
    console.error("[send-push-notification] payload.record missing title/body — aborting");
    return new Response("missing notification title/body", { status: 400 });
  }
  const targetUserId = notification.target_user_id ?? null;
  console.log(
    `[send-push-notification] notification id=${notification.id} title="${notification.title}" ` +
      `mode=${targetUserId ? `targeted(user_id=${targetUserId})` : "broadcast"}`,
  );

  const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!serviceAccountRaw) {
    console.error("[send-push-notification] FIREBASE_SERVICE_ACCOUNT secret is not set");
    return new Response("server misconfigured", { status: 500 });
  }
  const serviceAccount = JSON.parse(serviceAccountRaw);
  console.log(`[send-push-notification] loaded service account for project_id=${serviceAccount.project_id}`);

  const auth = new GoogleAuth({
    credentials: serviceAccount,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const authClient = await auth.getClient();
  const { token: accessToken } = await authClient.getAccessToken();
  if (!accessToken) {
    console.error("[send-push-notification] failed to obtain FCM OAuth2 access token");
    return new Response("failed to authenticate with FCM", { status: 500 });
  }
  console.log("[send-push-notification] obtained FCM OAuth2 access token");

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Targeted: only this user's tokens. Broadcast (targetUserId null):
  // every token, same as the original Phase 8 behavior — unchanged.
  let deviceTokensQuery = supabase.from("device_tokens").select("id, fcm_token");
  if (targetUserId) {
    deviceTokensQuery = deviceTokensQuery.eq("user_id", targetUserId);
  }
  const { data: deviceTokens, error: fetchError } = await deviceTokensQuery;

  if (fetchError) {
    console.error("[send-push-notification] failed to read device_tokens:", JSON.stringify(fetchError));
    return new Response("failed to read device tokens", { status: 500 });
  }

  console.log(
    `[send-push-notification] found ${deviceTokens?.length ?? 0} device token(s) ` +
      `in device_tokens${targetUserId ? ` for user_id=${targetUserId}` : ""}`,
  );
  if (!deviceTokens || deviceTokens.length === 0) {
    console.log("No device tokens found");
    return new Response(
      JSON.stringify({ sent: 0, failed: 0, pruned: 0, totalTokens: 0 }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  let sent = 0;
  let failed = 0;
  const staleIds: string[] = [];

  for (const row of deviceTokens) {
    console.log(`[send-push-notification] sending to device_tokens.id=${row.id}...`);
    let res: Response;
    try {
      res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: row.fcm_token,
              notification: {
                title: notification.title,
                body: notification.body,
              },
            },
          }),
        },
      );
    } catch (e) {
      failed++;
      console.error(`[send-push-notification] network error calling FCM for id=${row.id}:`, e);
      continue;
    }

    const responseBody = await res.text();
    console.log(
      `[send-push-notification] FCM response for id=${row.id}: status=${res.status} body=${responseBody}`,
    );

    if (res.ok) {
      sent++;
      continue;
    }

    failed++;
    console.error(
      `[send-push-notification] FCM send FAILED for device_tokens.id=${row.id}: ` +
        `http_status=${res.status} full_response_body=${responseBody}`,
    );

    const errorBody = JSON.parse(responseBody || "{}");
    const status = errorBody?.error?.status;

    // UNREGISTERED / INVALID_ARGUMENT are permanent (uninstalled app, token
    // rotated without us hearing about it, malformed token) — prune rather
    // than let this table accumulate dead rows and retry them forever.
    if (status === "UNREGISTERED" || status === "INVALID_ARGUMENT") {
      console.log(`[send-push-notification] marking id=${row.id} for pruning (status=${status})`);
      staleIds.push(row.id);
    }
  }

  if (staleIds.length > 0) {
    const { error: deleteError } = await supabase
      .from("device_tokens")
      .delete()
      .in("id", staleIds);
    if (deleteError) {
      console.error("[send-push-notification] failed to prune stale device_tokens:", JSON.stringify(deleteError));
    } else {
      console.log(`[send-push-notification] pruned ${staleIds.length} stale token(s)`);
    }
  }

  console.log(
    `[send-push-notification] done: sent=${sent} failed=${failed} pruned=${staleIds.length} totalTokens=${deviceTokens.length}`,
  );

  return new Response(
    JSON.stringify({
      sent,
      failed,
      pruned: staleIds.length,
      totalTokens: deviceTokens.length,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
