import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hrm.dart';
import '../state/hrm_controller.dart';
import '../utils/formatters.dart';

/// Asks for leave: the kind, the days, and why. Lands as `pending` for a
/// manager to approve.
class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  LeaveType? _type;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  bool _halfDay = false;
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _start = _end = DateTime(today.year, today.month, today.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HrmController>().loadLeaveTypes();
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  int get _days => _halfDay ? 0 : _end.difference(_start).inDays + 1;

  Future<void> _pick({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked.isBefore(_start) ? _start : picked;
      }
    });
  }

  Future<void> _submit() async {
    final hrm = context.read<HrmController>();
    final type = _type;
    if (type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose the kind of leave.')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final done = await hrm.requestLeave(
      type: type,
      start: _start,
      end: _halfDay ? _start : _end,
      reason: _reason.text,
      halfDay: _halfDay,
    );
    if (!mounted) return;
    if (!done) {
      final message = hrm.error;
      if (message != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        hrm.clearError();
      }
      return;
    }
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Leave requested — waiting for approval.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final hrm = context.watch<HrmController>();
    final scheme = Theme.of(context).colorScheme;
    final types = hrm.leaveTypes;

    return Scaffold(
      appBar: AppBar(title: const Text('Request leave')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          DropdownButtonFormField<LeaveType>(
            initialValue: _type,
            isExpanded: true,
            items: [
              for (final type in types)
                DropdownMenuItem(
                  value: type,
                  child: Text(type.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _type = value),
            decoration: InputDecoration(
              labelText: 'Kind of leave',
              prefixIcon: const Icon(Icons.category_outlined),
              helperText: types.isEmpty && hrm.error == null
                  ? 'Loading the kinds of leave…'
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'From',
                  date: _start,
                  onTap: () => _pick(start: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'To',
                  date: _halfDay ? _start : _end,
                  onTap: _halfDay ? null : () => _pick(start: false),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Half day'),
            value: _halfDay,
            onChanged: (value) => setState(() => _halfDay = value),
          ),
          Text(
            _halfDay ? 'Half a day' : '$_days day${_days == 1 ? '' : 's'}',
            style: TextStyle(fontWeight: FontWeight.w600, color: scheme.primary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reason,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Reason',
              alignLabelWithHint: true,
            ),
          ),
          if (hrm.error != null) ...[
            const SizedBox(height: 10),
            Text(hrm.error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: hrm.busy ? null : _submit,
            icon: const Icon(Icons.send),
            label: const Text('Send request'),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.date, this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today, size: 18),
            enabled: onTap != null,
          ),
          child: Text(longDate(date)),
        ),
      );
}
