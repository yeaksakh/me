import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hrm.dart';
import '../state/hrm_controller.dart';
import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';
import 'hrm_screen.dart';

/// The person's payslips, newest month first.
class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HrmController>().loadPayrolls();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hrm = context.watch<HrmController>();
    final symbol = context.watch<SessionController>().staff?.currencySymbol ?? r'$';
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final payrolls = hrm.payrolls;
    final latest = payrolls.isEmpty ? null : payrolls.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Payroll')),
      body: RefreshIndicator(
        onRefresh: () => context.read<HrmController>().loadPayrolls(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (latest != null) ...[
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Basic salary',
                      value: money(latest.basicSalary, symbol: symbol),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      icon: Icons.payments,
                      label: 'Latest net pay',
                      value: money(latest.netPay, symbol: symbol),
                      tone: colors.checked,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (hrm.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(hrm.error!, style: TextStyle(color: scheme.error)),
              ),
            if (payrolls.isEmpty)
              const SizedBox(
                height: 300,
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No payslips yet',
                  message: 'Your payslips show here once payroll has run.',
                ),
              ),
            for (final payroll in payrolls) ...[
              SectionCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PayslipScreen(payrollId: payroll.id),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            monthLabel(payroll.month),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            payroll.paidOn == null
                                ? 'Not paid yet'
                                : 'Paid ${shortDate(payroll.paidOn!)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      money(payroll.netPay, symbol: symbol),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: payroll.paidOn == null ? colors.lowStock : colors.checked,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right, color: scheme.outline),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// One payslip: the maths, the month's work, and whether it was paid.
class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key, required this.payrollId});

  final String payrollId;

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  Payslip? _slip;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final slip = await context.read<HrmController>().payslip(widget.payrollId);
    if (!mounted) return;
    setState(() {
      _slip = slip;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hrm = context.watch<HrmController>();
    final symbol = context.watch<SessionController>().staff?.currencySymbol ?? r'$';
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final slip = _slip;

    return Scaffold(
      appBar: AppBar(title: Text(slip?.monthLabel ?? 'Payslip')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : slip == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(hrm.error ?? 'This payslip could not be loaded.'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net pay',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          Text(
                            money(slip.netPay, symbol: symbol),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: colors.checked,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              StatusChip(
                                label: slip.isPaid
                                    ? 'Paid ${shortDate(slip.paidOn!)}'
                                    : 'Not paid yet',
                                color: slip.isPaid ? colors.checked : colors.lowStock,
                              ),
                              if (slip.paidBy.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'by ${slip.paidBy}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _Heading('Pay'),
                    SectionCard(
                      child: Column(
                        children: [
                          for (final line in slip.lines) ...[
                            _Line(
                              label: line.label,
                              detail: line.when,
                              amount: money(
                                line.isDeduction ? -line.amount : line.amount,
                                symbol: symbol,
                              ),
                              tone: line.isDeduction
                                  ? colors.outOfStock
                                  : line.kind == 'base'
                                      ? null
                                      : colors.checked,
                            ),
                            const Divider(height: 18),
                          ],
                          if (slip.lines.isEmpty) ...[
                            _Line(
                              label: 'Basic salary',
                              amount: money(slip.basicSalary, symbol: symbol),
                            ),
                            const Divider(height: 18),
                            _Line(
                              label: 'Earnings',
                              amount: money(slip.totalEarnings, symbol: symbol),
                              tone: colors.checked,
                            ),
                            const Divider(height: 18),
                            _Line(
                              label: 'Deductions',
                              amount: money(-slip.totalDeductions, symbol: symbol),
                              tone: colors.outOfStock,
                            ),
                            const Divider(height: 18),
                          ],
                          _Line(
                            label: 'Net pay',
                            amount: money(slip.netPay, symbol: symbol),
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _Heading('This month'),
                    SectionCard(
                      child: Column(
                        children: [
                          if (slip.shift.isNotEmpty)
                            _Line(label: 'Shift', amount: slip.shift),
                          if (slip.presentDays != null)
                            _Line(
                              label: 'Days present',
                              amount: _days(slip.presentDays!) +
                                  (slip.scheduledDays == null
                                      ? ''
                                      : ' of ${_days(slip.scheduledDays!)}'),
                            ),
                          if (slip.absentDays != null)
                            _Line(
                              label: 'Days absent',
                              detail: slip.absentDates.join(', '),
                              amount: _days(slip.absentDays!),
                              tone: (slip.absentDays ?? 0) > 0
                                  ? colors.outOfStock
                                  : null,
                            ),
                          if (slip.clockedHours != null)
                            _Line(
                              label: 'Hours clocked',
                              amount: '${slip.clockedHours!.toStringAsFixed(1)} h',
                            ),
                          if (slip.lateMinutes != null && slip.lateMinutes! > 0)
                            _Line(
                              label: 'Late',
                              amount: '${slip.lateMinutes!.round()} min',
                              tone: colors.lowStock,
                            ),
                          if (slip.paidLeaveDays != null && slip.paidLeaveDays! > 0)
                            _Line(
                              label: 'Paid leave',
                              amount: _days(slip.paidLeaveDays!),
                            ),
                          if (slip.unpaidLeaveDays != null && slip.unpaidLeaveDays! > 0)
                            _Line(
                              label: 'Unpaid leave',
                              amount: _days(slip.unpaidLeaveDays!),
                              tone: colors.outOfStock,
                            ),
                        ],
                      ),
                    ),
                    if (slip.leaves.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _Heading('Leave this month'),
                      for (final leave in slip.leaves)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SectionCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${leave.typeLabel} · '
                                    '${dateRange(leave.start, leave.end)}',
                                  ),
                                ),
                                Text(
                                  leave.daysLabel,
                                  style: TextStyle(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }

  static String _days(double value) =>
      value == value.truncateToDouble() ? '${value.toInt()}' : '$value';
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.amount,
    this.detail = '',
    this.tone,
    this.bold = false,
  });

  final String label;
  final String detail;
  final String amount;
  final Color? tone;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : 14,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}
