import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/notifications/data/models/notification_model.dart';
import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';
import 'package:doon_walkers/features/notifications/domain/repositories/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [NotificationRepository].
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'notificationRepositoryProvider',
);

/// Supabase implementation of [NotificationRepository].
class NotificationRepositoryImpl implements NotificationRepository {
  final SupabaseClient _supabase;

  const NotificationRepositoryImpl(this._supabase);

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    // Explicit filter *as well as* RLS — the policy is the real
    // boundary, but being explicit keeps this correct if an admin
    // (who has no special SELECT bypass on this table — see
    // 0021_notifications_targeting.sql, deliberately no is_admin() OR
    // clause) opens their own notification list. A guest never reaches
    // this call at all (the /notifications route redirect-guards
    // them), but the null-safe fallback (broadcasts only) keeps this
    // defensively correct even so.
    final userId = _supabase.auth.currentUser?.id;
    final query = _supabase.from(AppConstants.tableNotifications).select();
    final filtered = userId == null
        ? query.isFilter('target_user_id', null)
        : query.or('target_user_id.is.null,target_user_id.eq.$userId');

    final rows = await filtered.order('created_at', ascending: false);
    return rows.map(NotificationModel.fromJson).toList();
  }

  @override
  Future<NotificationItem> createNotification({
    required String title,
    required String body,
    String? targetUserId,
  }) async {
    final row = await _supabase
        .from(AppConstants.tableNotifications)
        .insert(NotificationModel.toInsertJson(
          title: title,
          body: body,
          targetUserId: targetUserId,
        ))
        .select()
        .single();
    return NotificationModel.fromJson(row);
  }
}
