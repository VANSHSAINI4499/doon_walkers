import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/notifications/data/models/notification_model.dart';
import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';
import 'package:doon_walkers/features/notifications/domain/repositories/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'notificationRepositoryProvider',
);

class NotificationRepositoryImpl implements NotificationRepository {
  final SupabaseClient _supabase;

  const NotificationRepositoryImpl(this._supabase);

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
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

  @override
  Future<Set<String>> fetchReadNotificationIds() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return const {};

    final response = await _supabase.rpc('get_my_read_notification_ids')
        as List<dynamic>;

    return response
        .map((e) => (e as Map<String, dynamic>)['notification_id'] as String)
        .toSet();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.rpc(
      'mark_notification_read',
      params: {'p_notification_id': notificationId},
    );
  }

  @override
  Future<int> markAllAsRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    final response = await _supabase.rpc('mark_all_notifications_read');
    return (response as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> getUnreadCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    final response = await _supabase.rpc('get_unread_notification_count');
    return (response as num?)?.toInt() ?? 0;
  }
}
