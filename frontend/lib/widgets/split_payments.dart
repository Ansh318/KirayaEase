// schedule_rent_split_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class SplitPayment {
  DateTime date;
  int amount; // in rupees
  SplitPayment({required this.date, required this.amount});
}

typedef ConfirmSplits = void Function(List<SplitPayment> splits);

Future<void> showScheduleRentSplitSheet({
  required BuildContext context,
  required int monthlyRent, // e.g., 12500 for ₹12,500
  List<SplitPayment>? initialSplits,
  required ConfirmSplits onConfirm,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ScheduleRentSplitSheet(
      monthlyRent: monthlyRent,
      initial: initialSplits,
      onConfirm: onConfirm,
    ),
  );
}

class _ScheduleRentSplitSheet extends StatefulWidget {
  final int monthlyRent;
  final List<SplitPayment>? initial;
  final ConfirmSplits onConfirm;

  const _ScheduleRentSplitSheet({
    required this.monthlyRent,
    required this.onConfirm,
    this.initial,
  });

  @override
  State<_ScheduleRentSplitSheet> createState() =>
      _ScheduleRentSplitSheetState();
}

class _ScheduleRentSplitSheetState extends State<_ScheduleRentSplitSheet> {
  final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _dateFmtDayMon = DateFormat('MMM d'); // “Oct 1”
  final List<_SplitRow> _rows = [];

  @override
  void initState() {
    super.initState();
    if (widget.initial?.isNotEmpty == true) {
      for (final s in widget.initial!) {
        _rows.add(_SplitRow(date: s.date, amount: s.amount));
      }
    } else {
      // sensible defaults: split in 2 (60/40)
      final now = DateTime.now();
      final first = DateTime(now.year, now.month, 1);
      final mid = DateTime(now.year, now.month, 17);
      _rows.addAll([
        _SplitRow(date: first, amount: (widget.monthlyRent * 0.6).round()),
        _SplitRow(
            date: mid,
            amount: widget.monthlyRent - (widget.monthlyRent * 0.6).round()),
      ]);
    }
  }

  int get total {
    return _rows.fold<int>(
      0,
      (sum, r) {
        final raw = r.controller.text.replaceAll(',', '');
        final amt = int.tryParse(raw) ?? 0;
        return sum + amt;
      },
    );
  }

  bool get isValidTotal => total == widget.monthlyRent;

  void _addRow() {
    if (_rows.length >= 6) return;
    final remaining = widget.monthlyRent - total;
    final date = DateTime(DateTime.now().year, DateTime.now().month, 1)
        .add(Duration(days: 16 * _rows.length));
    final amt = remaining > 0 ? remaining : 0;
    setState(() => _rows.add(_SplitRow(date: date, amount: amt)));
  }

  void _removeRow(int i) => setState(() => _rows.removeAt(i));

  Future<void> _pickDate(int i) async {
    final row = _rows[i];
    final picked = await showDatePicker(
      context: context,
      initialDate: row.date,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1),
      helpText: 'Choose split date',
    );
    if (picked != null) setState(() => row.date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, viewInsets),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Schedule Rent Payment',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Split rows
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _SplitRowWidget(
                    labelDate: _dateFmtDayMon.format(_rows[i].date),
                    controller: _rows[i].controller,
                    onTapDate: () => _pickDate(i),
                    onChanged: (_) => setState(() {}),
                    onRemove: _rows.length > 1 ? () => _removeRow(i) : null,
                  ),
                ),

                const SizedBox(height: 12),

                // Add split
                TextButton.icon(
                  onPressed: _rows.length >= 6 ? null : _addRow,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add another split'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black87,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),

                const SizedBox(height: 6),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Total ${_currency.format(total)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isValidTotal ? Colors.black : Colors.red[700],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Confirm
                SizedBox(
                  width: double.infinity,
                  child: _MintButton(
                    enabled: isValidTotal && total > 0,
                    onPressed: () {
                      final splits = _rows.map((r) {
                        final amt = int.tryParse(
                              r.controller.text.replaceAll(',', ''),
                            ) ??
                            0;
                        return SplitPayment(date: r.date, amount: amt);
                      }).toList();
                      widget.onConfirm(splits);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- UI bits ----------

class _SplitRow {
  DateTime date;
  final TextEditingController controller;
  _SplitRow({required this.date, required int amount})
      : controller = TextEditingController(
            text: NumberFormat.decimalPattern('en_IN').format(amount));
}

class _SplitRowWidget extends StatelessWidget {
  final String labelDate;
  final TextEditingController controller;
  final VoidCallback onTapDate;
  final ValueChanged<String> onChanged;
  final VoidCallback? onRemove;

  const _SplitRowWidget({
    super.key,
    required this.labelDate,
    required this.controller,
    required this.onTapDate,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    InputBorder _fieldBorder() => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE7E7E7)),
        );

    return Row(
      children: [
        // Date chip
        Expanded(
          child: InkWell(
            onTap: onTapDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE7E7E7)),
                color: Colors.white,
              ),
              child: Text(labelDate,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Amount field
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _IndianGroupingInputFormatter(),
            ],
            decoration: InputDecoration(
              prefixText: '₹ ',
              hintText: '0',
              border: _fieldBorder(),
              enabledBorder: _fieldBorder(),
              focusedBorder: _fieldBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: onChanged,
          ),
        ),

        // Remove
        if (onRemove != null) ...[
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onRemove,
          ),
        ],
      ],
    );
  }
}

// Mint rounded button matching your style
class _MintButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  final Widget child;

  const _MintButton({
    required this.enabled,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.5,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFFCFF6EE), // soft mint
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: child,
      ),
    );
  }
}

// Indian numbering grouping (e.g., 12,500; 1,00,000)
class _IndianGroupingInputFormatter extends TextInputFormatter {
  final _fmt = NumberFormat.decimalPattern('en_IN');
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final num = int.parse(digits);
    final formatted = _fmt.format(num);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
