// Version 2, Phase Auth Upgrade — Section 4 (Phone/OTP Verification),
// rebuilt on MSG91's OTP Widget SDK.
//
// Replaces the old send-otp/verify-otp pair. The Flutter app now drives
// OTP send/resend/entry/expiry itself via the `sendotp_flutter_sdk`
// package talking directly to MSG91 (see
// lib/features/auth/data/repositories/phone_verification_repository_impl.dart)
// — this function's only job is the one step that MUST happen
// server-side: taking the access token the widget hands back after a
// successful verification and confirming with MSG91 that it's real,
// before trusting it enough to flip `phone_verified` on. Invoked
// directly by the Flutter app, same auth model as the functions it
// replaces — verify_jwt stays ON, caller resolved from their own JWT via
// userClient.auth.getUser(), never trusted from the request body.
//
// This is still the ONLY code path allowed to write
// `phone_verified`/`phone_verified_at` — the
// `on_user_update_check_phone_verified` DB trigger
// (phone_otp_verification_guards migration, untouched by this rework)
// rejects that write from anywhere else.
//
// MSG91 "Verify Access Token" contract:
//   POST https://control.msg91.com/api/v5/widget/verifyAccessToken
//   Body: {"authkey": "<MSG91_AUTH_KEY>", "access-token": "<token from the widget>"}
//   Response body: {"type": "success"|"error", "message": "..."}
//   On success, `message` is documented as carrying the verified mobile
//   number back.
//   ⚠️ CAVEAT — stronger than usual: docs.msg91.com/otp-widget/verify-
//   access-token renders client-side and could not be fetched directly
//   while writing this, and (unlike the raw /otp and /otp/verify
//   endpoints used by the old flow) I could not find an independent
//   third-party example confirming this exact URL/body shape — only
//   converging secondhand descriptions. MSG91's dashboard, under the
//   OTP Widget's own "Server-Side Integration" panel, shows YOUR
//   account's exact copy-pasteable snippet for this call (endpoint,
//   param names, and whether authkey goes in the body or a header) —
//   that snippet is the authoritative source and should be checked
//   against the request below before relying on this in production.
//
// Credentials: MSG91_AUTH_KEY is the same pre-existing Supabase secret
// the old flow used. No template id needed — the widget owns OTP
// generation now. SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY/
// SUPABASE_ANON_KEY are auto-injected by the platform.
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing authorization" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) {
    console.error("[verify-phone-token] failed to resolve caller from JWT:", userError);
    return jsonResponse({ error: "Not authenticated" }, 401);
  }

  let body: { accessToken?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid request body" }, 400);
  }

  const accessToken = (body.accessToken ?? "").trim();
  if (!accessToken) {
    return jsonResponse({ error: "Missing access token" }, 400);
  }

  const authKey = Deno.env.get("MSG91_AUTH_KEY");
  if (!authKey) {
    console.error("[verify-phone-token] MSG91_AUTH_KEY secret is not set");
    return jsonResponse({ error: "Server misconfigured" }, 500);
  }

  let msg91Response: Response;
  try {
    msg91Response = await fetch("https://control.msg91.com/api/v5/widget/verifyAccessToken", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ authkey: authKey, "access-token": accessToken }),
    });
  } catch (e) {
    console.error("[verify-phone-token] network error calling MSG91:", e);
    return jsonResponse({ error: "Could not verify your phone. Please try again." }, 502);
  }

  const responseText = await msg91Response.text();
  console.log(
    `[verify-phone-token] MSG91 response for user_id=${user.id}: status=${msg91Response.status} body=${responseText}`,
  );

  let responseJson: { type?: string; message?: string } = {};
  try {
    responseJson = JSON.parse(responseText);
  } catch {
    // Tolerate a non-JSON body — falls through to the rejection path.
  }

  if (responseJson.type !== "success") {
    console.log(`[verify-phone-token] MSG91 rejected the token for user_id=${user.id}: ${responseText}`);
    return jsonResponse(
      { error: "Could not verify your phone. Please request a new code and try again." },
      400,
    );
  }

  // `message` carries the verified mobile number on success — digits
  // only, in case MSG91 includes formatting characters.
  const verifiedPhone = (responseJson.message ?? "").replace(/[^0-9]/g, "");
  if (!verifiedPhone) {
    console.error(
      `[verify-phone-token] MSG91 reported success but no phone number in message for user_id=${user.id}: ${responseText}`,
    );
    return jsonResponse({ error: "Could not verify your phone. Please try again." }, 502);
  }

  const serviceClient = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { error: updateError } = await serviceClient
    .from("users")
    .update({
      phone: verifiedPhone,
      phone_verified: true,
      phone_verified_at: new Date().toISOString(),
    })
    .eq("id", user.id);

  if (updateError) {
    console.error("[verify-phone-token] failed to update public.users:", JSON.stringify(updateError));
    return jsonResponse({ error: "Verified, but saving failed. Please try again." }, 500);
  }

  console.log(`[verify-phone-token] user_id=${user.id} phone_verified=true`);
  return jsonResponse({ success: true }, 200);
});
