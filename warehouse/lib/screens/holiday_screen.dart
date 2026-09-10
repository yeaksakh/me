import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/hrm_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_card.dart';

/// The shop's holidays for a year, the next one first.
class HolidayScreen extends StatefulWidget {
  const HolidayScreen({super.key});

  @override
  State<HolidayScreen> createState() => _HolidayScreenState();
}

class _HolidayScreenState extends State<HolidayScreen> {
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    if (!mounted) return Future.value();
    return context.read<HrmController>().loadHolidays(year: _year);
  }

  @override
  Widget build(BuildContext context) {
    final hrm = context.watch<HrmController>();
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final holidays = hrm.holidays.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final upcoming = holidays.where((h) => !h.end.isBefore(today)).toList();
    final past = holidays.where((h) => h.end.isBefore(today)).toList().reversed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Holidays'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _year,
              items: [
                for (var y = now.year + 1; y >= now.year - 2; y--)
                  DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _year = value);
                _load();
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (hrm.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(hrm.error!, style: TextStyle(color: scheme.error)),
              ),
            if (holidays.isEmpty)
              const SizedBox(
                height: 300,
                child: EmptyState(
                  icon: Icons.beach_access,
                  title: 'No holidays',
                  message: 'None are set for this year on the website.',
                ),
              ),
            if (upcoming.isNotEmpty) ...[
              const _Heading('Coming up'),
              for (final holiday in upcoming) ...[
                SectionCard(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.pickedUp.withAlpha(28),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.beach_access, color: colors.pickedUp),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              holiday.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${dateRange(holiday.start, holiday.end)} · '
                              '${holiday.days} day${holiday.days == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (holiday.note.isNotEmpty)
                              Text(
                                holiday.note,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
            if (past.isNotEmpty) ...[
              const _Heading('Already passed'),
              for (final holiday in past) ...[
                SectionCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          holiday.name,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      Text(
                        dateRange(holiday.start, holiday.end),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
}
