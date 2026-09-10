import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/hrm.dart';
import '../services/camera.dart';
import '../services/location.dart';
import '../state/hrm_controller.dart';
import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/section_card.dart';
import 'attendance_screen.dart';
import 'holiday_screen.dart';
import 'leave_approvals_screen.dart';
import 'leave_screen.dart';
import 'payroll_screen.dart';

/// The HR tab: the clock, then the same doors YeaksaMax opens -- attendance,
/// leave, holidays, leave approvals for a manager, and pay.
class HrmScreen extends StatefulWidget {
  const HrmScreen({super.key});

  @override
  State<HrmScreen> createState() => _HrmScreenState();
}

class _HrmScreenState extends State<HrmScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HrmController>().loadShift();
    });
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<SessionController>().staff;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HRM',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            if (staff != null)
              Text(
                staff.name,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<HrmController>().loadShift(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const ClockCard(),
            const SizedBox(height: 20),
            _Door(
              icon: Icons.calendar_today,
              title: 'Attendance',
              subtitle: 'Your clock-ins and hours',
              onTap: () => _open(const AttendanceScreen()),
            ),
            _Door(
              icon: Icons.event_busy,
              title: 'Leave',
              subtitle: 'Your requests, and ask for leave',
              onTap: () => _open(const LeaveScreen()),
            ),
            _Door(
              icon: Icons.beach_access,
              title: 'Holidays',
              subtitle: "The shop's days off this year",
              onTap: () => _open(const HolidayScreen()),
            ),
            if (staff?.isAdmin ?? false)
              _Door(
                icon: Icons.group,
                title: 'Leave approvals',
                subtitle: 'Approve or reject staff requests',
                onTap: () => _open(const LeaveApprovalsScreen()),
              ),
            _Door(
              icon: Icons.payments_outlined,
              title: 'Payroll',
              subtitle: 'Your payslips',
              onTap: () => _open(const PayrollScreen()),
            ),
          ],
        ),
      ),
    );
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

/// The big card: whether a shift is open, since when, and the one button.
class ClockCard extends StatelessWidget {
  const ClockCard({super.key});

  Future<void> _punch(BuildContext context) async {
    final hrm = context.read<HrmController>();
    final clockedIn = hrm.isClockedIn;
    final choice = await showDialog<_PunchChoice>(
      context: context,
      builder: (_) => _PunchDialog(clockingIn: !clockedIn),
    );
    if (choice == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    // The fix is asked for AFTER the person confirms, and never waited on for
    // long: the punch goes through with or without it.
    final position = await LocationService.current();
    final action = await hrm.clock(
      note: choice.note,
      position: position,
      photoPath: choice.photoPath,
    );
    if (action == null) {
      final message = hrm.error;
      if (message != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        hrm.clearError();
      }
      return;
    }
    HapticFeedback.mediumImpact();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(action == 'in'
            ? 'Clocked in at ${clockTime(DateTime.now())}.'
            : 'Clocked out at ${clockTime(DateTime.now())}.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final hrm = context.watch<HrmController>();
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final shift = hrm.openShift;
    final clockedIn = hrm.isClockedIn;
    final accent = clockedIn ? colors.prepared : colors.ordered;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  clockedIn ? Icons.hourglass_bottom : Icons.login,
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !hrm.shiftLoaded
                          ? 'Checking…'
                          : clockedIn
                              ? 'Clocked in'
                              : 'Not clocked in',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shift == null
                          ? (hrm.shiftLoaded
                              ? 'Tap the button when you start.'
                              : ' ')
                          : 'Since ${dateTime(shift.clockIn)} · '
                              '${hoursMinutes(shift.worked)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hrm.error != null && !hrm.shiftLoaded) ...[
            const SizedBox(height: 12),
            Text(hrm.error!, style: TextStyle(color: scheme.error, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: hrm.busy || !hrm.shiftLoaded ? null : () => _punch(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(60),
            ),
            icon: Icon(clockedIn ? Icons.logout : Icons.login),
            label: Text(
              clockedIn ? 'Clock out' : 'Clock in',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PunchChoice {
  const _PunchChoice({this.note, this.photoPath});

  final String? note;
  final String? photoPath;
}

/// Confirms the punch, with an optional note and selfie -- what the website's
/// check-in asks for.
class _PunchDialog extends StatefulWidget {
  const _PunchDialog({required this.clockingIn});

  final bool clockingIn;

  @override
  State<_PunchDialog> createState() => _PunchDialogState();
}

class _PunchDialogState extends State<_PunchDialog> {
  final _note = TextEditingController();
  String? _photoPath;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final verb = widget.clockingIn ? 'Clock in' : 'Clock out';
    return AlertDialog(
      title: Text(verb),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.clockingIn
                ? 'Start your shift now?'
                : 'End your shift now?',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.sticky_note_2_outlined),
            ),
          ),
          const SizedBox(height: 10),
          if (_photoPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_photoPath!),
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(height: 0),
              ),
            ),
          TextButton.icon(
            onPressed: () async {
              final path = await Camera.takePhoto();
              if (path != null && mounted) setState(() => _photoPath = path);
            },
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_photoPath == null ? 'Add a photo' : 'Retake photo'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _PunchChoice(note: _note.text, photoPath: _photoPath),
          ),
          child: Text(verb),
        ),
      ],
    );
  }
}

class _Door extends StatelessWidget {
  const _Door({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(24),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: scheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

/// A coloured status word, for leave and pay.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(28),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
}

Color leaveColor(BuildContext context, LeaveStatus status) {
  final colors = context.appColors;
  return switch (status) {
    LeaveStatus.approved => colors.inStock,
    LeaveStatus.pending => colors.lowStock,
    LeaveStatus.rejected || LeaveStatus.cancelled => colors.outOfStock,
  };
}
