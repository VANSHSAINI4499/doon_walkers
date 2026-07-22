import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/comments/data/models/comment_model.dart';
import 'package:doon_walkers/features/comments/domain/entities/comment.dart';
import 'package:doon_walkers/features/comments/domain/repositories/comment_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [CommentRepository].
final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => CommentRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'commentRepositoryProvider',
);

/// Custom SQLSTATE the `check_comment_blocklist` trigger
/// (0012_comments_moderation.sql) raises with explicitly — see
/// [CommentBlocklistException]'s doc for why this is matched on rather
/// than the bare-RAISE default `P0001`.
const _blocklistViolation = 'DWB01';

/// Supabase implementation of [CommentRepository].
class CommentRepositoryImpl implements CommentRepository {
  final SupabaseClient _supabase;

  const CommentRepositoryImpl(this._supabase);

  String get _currentUserId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw Exception('You need to be signed in to do that.');
    }
    return id;
  }

  @override
  Future<List<Comment>> fetchCommentsForTrek(String trekId) async {
    final rows = await _supabase
        .from(AppConstants.tableComments)
        .select()
        .eq('trek_id', trekId)
        .order('created_at', ascending: false);

    return rows.map(CommentModel.fromJson).toList();
  }

  @override
  Future<List<Comment>> fetchHiddenComments() async {
    final rows = await _supabase
        .from(AppConstants.tableComments)
        .select('*, treks(title)')
        .eq('is_visible', false)
        .order('created_at', ascending: false);

    return rows.map(CommentModel.fromJson).toList();
  }

  @override
  Future<List<String>> fetchBlocklistTerms() async {
    final rows = await _supabase.from(AppConstants.tableCommentBlocklist).select('term');
    return rows.map((row) => row['term'] as String).toList();
  }

  @override
  Future<Comment> createComment({
    required String trekId,
    required String commentText,
  }) async {
    try {
      final row = await _supabase
          .from(AppConstants.tableComments)
          .insert(CommentModel.toInsertJson(
            trekId: trekId,
            userId: _currentUserId,
            commentText: commentText,
          ))
          .select()
          .single();
      return CommentModel.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == _blocklistViolation) {
        throw const CommentBlocklistException();
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteComment(String id) async {
    await _supabase.from(AppConstants.tableComments).delete().eq('id', id);
  }

  @override
  Future<void> setVisibility(String id, bool isVisible) async {
    await _supabase
        .from(AppConstants.tableComments)
        .update({'is_visible': isVisible}).eq('id', id);
  }
}
