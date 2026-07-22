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
    final rows = await _supabase
        .from(AppConstants.tableNotifications)
        .select()
        .order('created_at', ascending: false);

    return rows.map(NotificationModel.fromJson).toList();
  }

  @override
  Future<NotificationItem> createNotification({
    required String title,
    required String body,
  }) async {
    final row = await _supabase
        .from(AppConstants.tableNotifications)
        .insert(NotificationModel.toInsertJson(title: title, body: body))
        .select()
        .single();
    return NotificationModel.fromJson(row);
  }
}
