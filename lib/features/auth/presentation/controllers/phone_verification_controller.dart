import 'dart:async';

import 'package:doon_walkers/features/auth/data/repositories/phone_verification_repository_impl.dart';
import 'package:doon_walkers/features/auth/domain/repositories/phone_verification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PhoneVerificationStep { enterPhone, enterOtp }

class PhoneVerificationState {
  const PhoneVerificationState({
    this.step = PhoneVerificationStep.enterPhone,
    this.phone = '',
    this.reqId = '',
  });

  final PhoneVerificationStep step;

  /// The number last sent an OTP (or prefilled from the user's existing
  /// `phone`, editable before the first send).
  final String phone;

  /// MSG91's identifier for the in-flight send — echoed back into
  /// retryOtp/verifyOtp. Empty until a code has actually been sent (the
  /// widget's "instant verify" path never sets this at all).
  final String reqId;

  PhoneVerificationState copyWith({
    PhoneVerificationStep? step,
    String? phone,
    String? reqId,
  }) {
    return PhoneVerificationState(
      step: step ?? this.step,
      phone: phone ?? this.phone,
      reqId: reqId ?? this.reqId,
    );
  }
}

/// Riverpod AsyncNotifier managing the phone verification flow — see
/// [PhoneVerificationRepository]'s doc for the widget-SDK-plus-one-
/// Edge-Function split this drives.
///
/// [state] is `AsyncValue<PhoneVerificationState>` rather than plain
/// `AsyncValue<void>` (unlike [AuthController]) because the UI needs
/// [PhoneVerificationState] to persist THROUGH a loading transition —
/// e.g. the OTP input must stay on screen with a spinner while
/// [verifyOtp] runs, not disappear because state momentarily has no
/// data. `copyWithPrevious` (same mechanism [isAdminProvider] relies on
/// for its own transient-error tolerance) is what keeps it visible.
final phoneVerificationControllerProvider =
    AsyncNotifierProvider<PhoneVerificationController, PhoneVerificationState>(
  PhoneVerificationController.new,
  name: 'phoneVerificationControllerProvider',
);

class PhoneVerificationController extends AsyncNotifier<PhoneVerificationState> {
  @override
  FutureOr<PhoneVerificationState> build() => const PhoneVerificationState();

  PhoneVerificationRepository get _repository => ref.read(phoneVerificationRepositoryProvider);

  /// Prefills the phone field before the first send — called once by the
  /// screen with the user's existing `public.users.phone`, if any.
  void prefillPhone(String phone) {
    final current = state.valueOrNull;
    if (current == null || current.phone.isNotEmpty) return;
    state = AsyncData(current.copyWith(phone: phone));
  }

  /// Requests a code for [phone]. Returns true if MSG91 verified the
  /// number instantly (no code needed) and [confirmVerification] already
  /// ran — the screen should treat that exactly like a completed
  /// [verifyOtp]. Returns false once the OTP step is showing.
  Future<bool> sendOtp(String phone) async {
    final base = state.valueOrNull ?? const PhoneVerificationState();
    state = const AsyncLoading<PhoneVerificationState>().copyWithPrevious(state);
    try {
      final result = await _repository.sendOtp(phone);
      switch (result) {
        case SendOtpInstantlyVerified(:final accessToken):
          await _repository.confirmVerification(accessToken);
          state = AsyncData(base.copyWith(phone: phone));
          return true;
        case SendOtpCodeSent(:final reqId):
          state = AsyncData(
            base.copyWith(step: PhoneVerificationStep.enterOtp, phone: phone, reqId: reqId),
          );
          return false;
      }
    } catch (e, st) {
      state = AsyncError<PhoneVerificationState>(e, st).copyWithPrevious(AsyncData(base));
      return false;
    }
  }

  Future<void> retryOtp() async {
    final base = state.valueOrNull ?? const PhoneVerificationState();
    if (base.reqId.isEmpty) return;
    state = const AsyncLoading<PhoneVerificationState>().copyWithPrevious(state);
    try {
      await _repository.retryOtp(base.reqId);
      state = AsyncData(base);
    } catch (e, st) {
      state = AsyncError<PhoneVerificationState>(e, st).copyWithPrevious(AsyncData(base));
    }
  }

  /// Verifies [otp] and, on success, confirms it server-side. Returns
  /// true once `public.users.phone_verified` has actually been set —
  /// the screen shows success and lets the router's redirect (see
  /// app_router.dart) take over from there.
  Future<bool> verifyOtp(String otp) async {
    final base = state.valueOrNull ?? const PhoneVerificationState();
    state = const AsyncLoading<PhoneVerificationState>().copyWithPrevious(state);
    try {
      final accessToken = await _repository.verifyOtp(reqId: base.reqId, otp: otp);
      await _repository.confirmVerification(accessToken);
      state = AsyncData(base);
      return true;
    } catch (e, st) {
      state = AsyncError<PhoneVerificationState>(e, st).copyWithPrevious(AsyncData(base));
      return false;
    }
  }

  /// Drops back to the phone-entry step without contacting MSG91 —
  /// "Change Number" on the OTP step uses this instead of re-running
  /// [sendOtp], which would fire an actual send request.
  void resetToPhoneStep() {
    final base = state.valueOrNull ?? const PhoneVerificationState();
    state = AsyncData(base.copyWith(step: PhoneVerificationStep.enterPhone, reqId: ''));
  }
}
