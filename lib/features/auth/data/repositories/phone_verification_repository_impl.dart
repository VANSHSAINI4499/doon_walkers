import 'dart:convert';

import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/auth/domain/repositories/phone_verification_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of
/// [PhoneVerificationRepository].
final phoneVerificationRepositoryProvider = Provider<PhoneVerificationRepository>(
  (ref) => PhoneVerificationRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'phoneVerificationRepositoryProvider',
);

/// Digits-only, with country code, no leading `+` — this is MSG91's own
/// documented requirement for `sendOTP`'s `identifier` field ("it must
/// contain the country code without +", per the SDK's doc comment on
/// `OTPWidget.sendOTP`). A bare 10-digit number is assumed Indian (this
/// app's only audience) and gets "91" prepended; anything else is just
/// stripped of non-digit characters (spaces, dashes, a leading +) and
/// passed through as-is.
String _normalizeIdentifier(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length == 10 ? '91$digits' : digits;
}

/// Wraps `sendotp_flutter_sdk`'s [OTPWidget] (initialized once in
/// main.dart) for send/retry/verify, and calls the verify-phone-token
/// Edge Function for the one step that must happen server-side. See
/// [PhoneVerificationRepository]'s doc for why those are split.
///
/// Every call logs its exact outbound identifier and the complete, raw,
/// unfiltered MSG91 response via [debugPrint] — deliberately verbose
/// (this is a very early, sparsely-documented SDK; see this file's
/// history) so a real device test makes the actual response shape
/// visible instead of guessed at.
class PhoneVerificationRepositoryImpl implements PhoneVerificationRepository {
  final SupabaseClient _supabase;

  const PhoneVerificationRepositoryImpl(this._supabase);

  @override
  Future<SendOtpResult> sendOtp(String phone) async {
    final identifier = _normalizeIdentifier(phone);
    debugPrint('[PhoneVerification] sendOtp: raw="$phone" identifier="$identifier"');

    final response = await OTPWidget.sendOTP({'identifier': identifier});
    debugPrint('[PhoneVerification] sendOtp response: ${jsonEncode(response)}');

    if (response == null || response['type'] != 'success') {
      throw Exception(_messageOf(response) ?? 'Could not send the verification code. Please try again.');
    }

    // MSG91's own example checks specifically for this key to detect an
    // "invisible"/instant verification (number already trusted, no code
    // sent at all) — see that response shape's doc in the widget's
    // pub.dev example.
    final instantToken = response['access-token'] as String?;
    if (instantToken != null && instantToken.isNotEmpty) {
      debugPrint('[PhoneVerification] sendOtp: instant verification (no SMS sent)');
      return SendOtpInstantlyVerified(instantToken);
    }

    final reqId = response['message'] as String?;
    if (reqId == null || reqId.isEmpty) {
      throw Exception('Could not send the verification code. Please try again.');
    }
    debugPrint('[PhoneVerification] sendOtp: code dispatch requested, reqId="$reqId"');
    return SendOtpCodeSent(reqId);
  }

  @override
  Future<void> retryOtp(String reqId) async {
    debugPrint('[PhoneVerification] retryOtp: reqId="$reqId"');
    final response = await OTPWidget.retryOTP({'reqId': reqId});
    debugPrint('[PhoneVerification] retryOtp response: ${jsonEncode(response)}');

    if (response == null || response['type'] != 'success') {
      throw Exception(_messageOf(response) ?? 'Could not resend the verification code. Please try again.');
    }
  }

  @override
  Future<String> verifyOtp({required String reqId, required String otp}) async {
    debugPrint('[PhoneVerification] verifyOtp: reqId="$reqId" otp="$otp"');
    final response = await OTPWidget.verifyOTP({'reqId': reqId, 'otp': otp});
    debugPrint('[PhoneVerification] verifyOtp response: ${jsonEncode(response)}');

    if (response == null || response['type'] != 'success') {
      throw Exception(_messageOf(response) ?? 'Incorrect or expired code. Please try again.');
    }

    // Which key actually carries the token here isn't confirmed against
    // a live MSG91 account — see PhoneVerificationRepository's doc.
    // Checking `access-token` first (same key the instant-verify path
    // uses) with a fallback to `message` (the old raw-API convention)
    // covers both plausible shapes; if MSG91 uses neither, this throws
    // with the raw response already printed above by debugPrint.
    final accessToken = response['access-token'] as String? ?? response['message'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Verification succeeded but no access token was returned. Please try again.');
    }
    return accessToken;
  }

  @override
  Future<void> confirmVerification(String accessToken) async {
    debugPrint('[PhoneVerification] confirmVerification: accessToken="$accessToken"');
    try {
      final response =
          await _supabase.functions.invoke('verify-phone-token', body: {'accessToken': accessToken});
      debugPrint('[PhoneVerification] confirmVerification response: status=${response.status} data=${response.data}');
    } on FunctionException catch (e) {
      debugPrint('[PhoneVerification] confirmVerification FAILED: status=${e.status} details=${e.details}');
      throw Exception(_functionErrorMessage(e) ?? 'Could not verify your phone. Please try again.');
    }
  }

  String? _messageOf(Map<String, dynamic>? response) {
    final message = response?['message'];
    return message is String && message.isNotEmpty ? message : null;
  }

  /// verify-phone-token returns `{"error": "..."}` as JSON on failure —
  /// [FunctionException.details] is already the decoded body when the
  /// response was `application/json`, so no manual json.decode needed.
  String? _functionErrorMessage(FunctionException e) {
    final details = e.details;
    return details is Map ? details['error'] as String? : null;
  }
}
