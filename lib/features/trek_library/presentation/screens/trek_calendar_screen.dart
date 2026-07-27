import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';

class TrekCalendarScreen extends ConsumerStatefulWidget {
  const TrekCalendarScreen({super.key});

  @override
  ConsumerState<TrekCalendarScreen> createState() => _TrekCalendarScreenState();
}

class _TrekCalendarScreenState extends ConsumerState<TrekCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  void _resetToToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = null;
    });
  }

  bool _isTrekOnDate(Trek trek, DateTime day) {
    final start = trek.trekDate;
    if (start == null) return false;

    final startDate = DateTime(start.year, start.month, start.day);
    final targetDate = DateTime(day.year, day.month, day.day);

    final duration = trek.durationDays ?? 1;
    final endDate = startDate.add(Duration(days: duration - 1));

    return !targetDate.isBefore(startDate) && !targetDate.isAfter(endDate);
  }

  bool _isTrekStartingOnDate(Trek trek, DateTime day) {
    final start = trek.trekDate;
    if (start == null) return false;
    return isSameDay(start, day);
  }

  Color _getDifficultyColor(TrekDifficulty difficulty, AppPalette palette) {
    switch (difficulty) {
      case TrekDifficulty.easy:
        return const Color(0xFF4CAF50); // Green
      case TrekDifficulty.moderate:
        return const Color(0xFFFFC107); // Amber
      case TrekDifficulty.hard:
      case TrekDifficulty.extreme:
        return palette.danger; // Red
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isAdmin = ref.watch(isAdminProvider);
    final treksProvider =
        isAdmin ? adminAllTreksProvider : publishedTreksProvider;
    final treksAsync = ref.watch(treksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trek Calendar'),
        actions: [
          TextButton.icon(
            onPressed: _resetToToday,
            icon: Icon(LucideIcons.calendarDays, size: 18),
            label: const Text('Today'),
          ),
        ],
      ),
      body: SafeArea(
        child: treksAsync.when(
          loading: () => const _CalendarSkeleton(),
          error:
              (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(AppIcons.error, size: 36, color: palette.danger),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Could not load trek calendar.',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Retry',
                        icon: AppIcons.refresh,
                        onPressed: () => ref.invalidate(treksProvider),
                      ),
                    ],
                  ),
                ),
              ),
          data: (allTreks) {
            final treksWithDates =
                allTreks.where((t) => t.trekDate != null).toList();

            // Month level check
            final monthTreks =
                treksWithDates.where((t) {
                  final start = t.trekDate!;
                  return start.year == _focusedDay.year &&
                      start.month == _focusedDay.month;
                }).toList();

            // Selected day matching treks
            final selectedDayTreks =
                _selectedDay != null
                    ? treksWithDates
                        .where((t) => _isTrekOnDate(t, _selectedDay!))
                        .toList()
                    : [];

            // Default upcoming list when no day selected
            final upcomingTreks =
                treksWithDates.where((t) => t.isUpcoming).toList()
                  ..sort((a, b) => a.trekDate!.compareTo(b.trekDate!));

            final displayedTreks =
                _selectedDay != null ? selectedDayTreks : upcomingTreks;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // TableCalendar Widget
                  Card(
                    elevation: 0,
                    color: palette.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      side: BorderSide(color: palette.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: TableCalendar<Trek>(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate:
                            (day) =>
                                _selectedDay != null &&
                                isSameDay(_selectedDay, day),
                        eventLoader: (day) {
                          return treksWithDates
                              .where((t) => _isTrekStartingOnDate(t, day))
                              .toList();
                        },
                        calendarFormat: CalendarFormat.month,
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: AppTextStyles.titleMedium.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          leftChevronIcon: Icon(
                            LucideIcons.chevronLeft,
                            color: palette.textPrimary,
                          ),
                          rightChevronIcon: Icon(
                            LucideIcons.chevronRight,
                            color: palette.textPrimary,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: palette.primary,
                              width: 2,
                            ),
                          ),
                          todayTextStyle: AppTextStyles.labelMedium.copyWith(
                            color: palette.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: palette.primary,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: AppTextStyles.labelMedium.copyWith(
                            color: palette.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          outsideDaysVisible: false,
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isEmpty) return const SizedBox.shrink();

                            final startingTreks =
                                treksWithDates
                                    .where(
                                      (t) => _isTrekStartingOnDate(t, date),
                                    )
                                    .toList();

                            if (startingTreks.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final visibleDots = startingTreks.take(3).toList();
                            final overflow = startingTreks.length - 3;

                            return Positioned(
                              bottom: 2,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final trek in visibleDots)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getDifficultyColor(
                                          trek.difficulty,
                                          palette,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (overflow > 0)
                                    Text(
                                      '+$overflow',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: palette.textSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          setState(() {
                            _focusedDay = focusedDay;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Header section for list below
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDay != null
                            ? 'Treks on ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}'
                            : 'Upcoming Treks',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_selectedDay != null)
                        TextButton(
                          onPressed: () => setState(() => _selectedDay = null),
                          child: const Text('Show All Upcoming'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Month level empty state indicator
                  if (monthTreks.isEmpty && _selectedDay == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Center(
                            child: Text(
                              'No scheduled treks in this month.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (displayedTreks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Center(
                            child: Text(
                              _selectedDay != null
                                  ? 'No treks scheduled for this date.'
                                  : 'No upcoming treks found.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedTreks.length,
                      separatorBuilder:
                          (context, index) =>
                              const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final trek = displayedTreks[index];
                        return _CalendarTrekCard(trek: trek);
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CalendarTrekCard extends ConsumerWidget {
  const _CalendarTrekCard({required this.trek});

  final Trek trek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final spotsLeftAsync = ref.watch(trekSpotsLeftProvider(trek.id));

    final dateStr =
        trek.trekDate != null
            ? '${trek.trekDate!.day}/${trek.trekDate!.month}/${trek.trekDate!.year}'
            : 'Unscheduled';

    final durationStr =
        trek.durationDays != null
            ? ' · ${trek.durationDays} day${trek.durationDays! > 1 ? 's' : ''}'
            : '';

    return AppCard(
      onTap: () => context.push('/trek-library/${trek.id}'),
      child: Row(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppRadius.card),
              ),
              color: palette.primarySubtle,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppRadius.card),
              ),
              child:
                  trek.coverImage != null && trek.coverImage!.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: trek.coverImage!,
                        fit: BoxFit.cover,
                        errorWidget:
                            (_, __, ___) => Icon(
                              LucideIcons.mountain,
                              color: palette.primary,
                              size: 32,
                            ),
                      )
                      : Icon(
                        LucideIcons.mountain,
                        color: palette.primary,
                        size: 32,
                      ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trek.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateStr$durationStr',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: palette.primarySubtle,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          trek.difficulty.label,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: palette.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      spotsLeftAsync.when(
                        data: (spots) {
                          final remaining = spots ?? 0;
                          final isWaitlist = remaining <= 0;
                          return Text(
                            isWaitlist
                                ? 'Waitlist Only'
                                : '$remaining spots left',
                            style: AppTextStyles.labelSmall.copyWith(
                              color:
                                  isWaitlist ? palette.danger : palette.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Icon(LucideIcons.chevronRight, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const SkeletonBox(height: 320, borderRadius: AppRadius.card),
            const SizedBox(height: AppSpacing.xl),
            for (var i = 0; i < 3; i++) ...[
              const SkeletonBox(height: 80, borderRadius: AppRadius.card),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
