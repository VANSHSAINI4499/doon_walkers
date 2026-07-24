/// Outcome of [PhoneVerificationRepository.sendOtp].
sealed class SendOtpResult {
  const SendOtpResult();
}

/// MSG91 sent a code — [reqId] must be echoed back into [PhoneVerificationRepository.verifyOtp]/[PhoneVerificationRepository.retryOtp].
class SendOtpCodeSent extends SendOtpResult {
  const SendOtpCodeSent(this.reqId);
  final String reqId;
}

/// MSG91's widget recognized this number as already trusted ("invisible"
/// verification) and skipped asking for a code entirely — [accessToken]
/// is ready to hand straight to [PhoneVerificationRepository.confirmVerification].
class SendOtpInstantlyVerified extends SendOtpResult {
  const SendOtpInstantlyVerified(this.accessToken);
  final String accessToken;
}

/// Abstract interface for phone/OTP verification (Version 2, Phase Auth
/// Upgrade), built on MSG91's OTP Widget SDK (`sendotp_flutter_sdk`)
/// rather than a direct MSG91 API proxy. The widget itself handles OTP
/// generation, resend cooldown, and expiry — this repository's Dart side
/// just drives its send/retry/verify calls and, on success, hands the
/// resulting access token to [confirmVerification], which is the only
/// step that talks to Supabase (see supabase/functions/verify-phone-token).
/// That split matters: `public.users.phone_verified` can ONLY ever be
/// set by that Edge Function (enforced by the
/// `on_user_update_check_phone_verified` DB trigger) — nothing in this
/// class writes to `public.users` directly, no matter what MSG91 tells
/// the device.
abstract class PhoneVerificationRepository {
  /// Requests a new OTP for [phone] (digits only, with country code —
  /// e.g. `919876543210`).
  Future<SendOtpResult> sendOtp(String phone);

  /// Resends the OTP for the send identified by [reqId] — MSG91 owns
  /// whatever resend cooldown/limit applies; a rejection surfaces as a
  /// thrown [Exception] with MSG91's own message.
  Future<void> retryOtp(String reqId);

  /// Verifies [otp] against the send identified by [reqId]. Returns the
  /// access token MSG91 hands back on success — this repository does
  /// NOT trust it on its own; callers must still pass it to
  /// [confirmVerification] for server-side verification before treating
  /// the phone as verified anywhere in the app.
  Future<String> verifyOtp({required String reqId, required String otp});

  /// Sends [accessToken] to the verify-phone-token Edge Function, which
  /// re-checks it with MSG91 server-side and, only then, sets
  /// `phone`/`phone_verified`/`phone_verified_at` on the caller's own
  /// `public.users` row. [currentUserProvider]'s live stream picks up
  /// the change — no separate refresh needed here.
  Future<void> confirmVerification(String accessToken);
}
