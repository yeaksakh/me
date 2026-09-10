import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hrm.dart';
import '../state/hrm_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';

enum _Range { today, week, month }

/// Every shift in a window: when it began, when it ended, how long it ran.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  _Range _range = _Range.month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  ({DateTime from, DateTime to}) get _window {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_range) {
      _Range.today => (from: today, to: today),
      _Range.week => (
          from: today.subtract(Duration(days: today.weekday - 1)),
          to: today
        ),
      _Range.month => (from: DateTime(now.year, now.month, 1), to: today),
    };
  }

  Future<void> _load() {
    if (!mounted) return Future.value();
    final window = _window;
    return context
        .read<HrmController>()
        .loadHistory(from: window.from, to: window.to);
  }

  @override
  Widget build(BuildContext context) {
    final hrm = context.watch<HrmController>();
    final entries = hrm.history;
    final scheme = Theme.of(context).colorScheme;
    final worked = entries.fold(Duration.zero, (sum, e) => sum + e.worked);
    final days = entries
        .map((e) => DateTime(e.clockIn.year, e.clockIn.month, e.clockIn.day))
        .toSet()
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final range in _Range.values)
                  ChoiceChip(
                    label: Text(switch (range) {
                      _Range.today => 'Today',
                      _Range.week => 'This week',
                      _Range.month => 'This month',
                    }),
                    selected: _range == range,
                    onSelected: (_) {
                      setState(() => _range = range);
                      _load();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.event_available,
                    label: 'Days worked',
                    value: '$days',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.timer_outlined,
                    label: 'Hours',
                    value: hoursMinutes(worked),
                    tone: context.appColors.checked,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hrm.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(hrm.error!, style: TextStyle(color: scheme.error)),
              ),
            if (entries.isEmpty)
              const SizedBox(
                height: 260,
                child: EmptyState(
                  icon: Icons.history_toggle_off,
                  title: 'No shifts here',
                  message: 'Clock in from the HRM tab and it will show here.',
                ),
              ),
            for (final entry in entries) ...[
              _ShiftCard(entry: entry),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.entry});

  final AttendanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  longDate(entry.clockIn),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                entry.isOpen ? 'Open' : hoursMinutes(entry.worked),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: entry.isOpen ? colors.prepared : colors.checked,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Punch(
                  label: 'In',
                  time: entry.clockIn,
                  note: entry.note,
                  photoUrl: entry.inPhotoUrl,
                  color: colors.ordered,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Punch(
                  label: 'Out',
                  time: entry.clockOut,
                  note: entry.outNote,
                  photoUrl: entry.outPhotoUrl,
                  color: colors.pickedUp,
                ),
              ),
            ],
          ),
          if (entry.inLatitude != null) ...[
            const SizedBox(height: 8),
            Text(
              'Position recorded',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _Punch extends StatelessWidget {
  const _Punch({
    required this.label,
    required this.time,
    required this.color,
    this.note,
    this.photoUrl,
  });

  final String label;
  final DateTime? time;
  final String? note;
  final String? photoUrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photoUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              photoUrl!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(width: 0),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                time == null ? '—' : clockTime(time!),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (note != null)
                Text(
                  note!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
