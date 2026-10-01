import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/auth_store.dart';
import '../../stora_login/stora_login.dart';
import '../stores/utang_store.dart';
import '../theme/home_colors.dart';

class UtangLedgerScreen extends StatefulWidget {
  const UtangLedgerScreen({super.key});

  @override
  State<UtangLedgerScreen> createState() => _UtangLedgerScreenState();
}

class _UtangLedgerScreenState extends State<UtangLedgerScreen> {
  String _selectedFilter = 'Active'; // 'Active', 'Overdue', 'Due Soon', 'Paid', 'All'
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isOpeningDialog = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UtangRecord> _filterRecords(List<UtangRecord> all) {
    var filtered = all;

    if (_selectedFilter == 'Active') {
      filtered = filtered.where((r) => !r.isFullyPaid).toList();
    } else if (_selectedFilter == 'Overdue') {
      filtered = filtered.where((r) => r.isOverdue).toList();
    } else if (_selectedFilter == 'Due Soon') {
      filtered = filtered.where((r) => r.isDueSoon || r.isDueToday).toList();
    } else if (_selectedFilter == 'Paid') {
      filtered = filtered.where((r) => r.isFullyPaid).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((r) {
        return r.customerName.toLowerCase().contains(q) ||
            r.customerPhone.toLowerCase().contains(q) ||
            r.notes.toLowerCase().contains(q);
      }).toList();
    }

    return filtered;
  }

  Widget _buildPresetPenaltyChip(String label, double amount, TextEditingController ctrl, StateSetter setDialogState) {
    final currentVal = double.tryParse(ctrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final isSelected = currentVal == amount && ctrl.text.trim().isNotEmpty;
    return InkWell(
      onTap: () {
        setDialogState(() {
          ctrl.text = amount.toStringAsFixed(0);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber.withValues(alpha: 0.25) : HomeColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.amber : HomeColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.amber : HomeColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyChip({
    required String label,
    required String value,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    final isSelected = selectedValue == value;
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.amber.withValues(alpha: 0.22) : HomeColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.amber : HomeColors.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: isSelected ? Colors.amber : HomeColors.textSecondary,
                  fontSize: 10.0,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showNewUtangDialog() async {
    if (_isOpeningDialog) return;
    _isOpeningDialog = true;

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final penaltyCtrl = TextEditingController();
    String selectedFrequency = 'none'; // 'none', 'daily', 'weekly', 'monthly'
    int selectedGraceDays = 0;
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 7));
    bool isSubmitting = false;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => PopScope(
            canPop: !isSubmitting,
            child: AlertDialog(
          backgroundColor: HomeColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: HomeColors.cardBorder),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'New Utang Entry',
                style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: HomeColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Customer Name *',
                    labelStyle: TextStyle(color: HomeColors.textSecondary),
                    filled: true,
                    fillColor: HomeColors.cardElevated,
                    prefixIcon: Icon(Icons.person_rounded, color: HomeColors.textSecondary, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: HomeColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Mobile Number (Optional)',
                    labelStyle: TextStyle(color: HomeColors.textSecondary),
                    filled: true,
                    fillColor: HomeColors.cardElevated,
                    prefixIcon: Icon(Icons.phone_rounded, color: HomeColors.textSecondary, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: HomeColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Total Amount (₱) *',
                    labelStyle: TextStyle(color: HomeColors.textSecondary),
                    filled: true,
                    fillColor: HomeColors.cardElevated,
                    prefixIcon: const Icon(Icons.payments_rounded, color: Colors.amber, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Payment Due Date', style: TextStyle(color: HomeColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final earliest = selectedDueDate.isBefore(DateTime(now.year - 1, now.month, now.day))
                        ? selectedDueDate.subtract(const Duration(days: 30))
                        : DateTime(now.year - 1, now.month, now.day);
                    final latest = selectedDueDate.isAfter(DateTime(now.year + 2, now.month, now.day))
                        ? selectedDueDate.add(const Duration(days: 365))
                        : DateTime(now.year + 2, now.month, now.day);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDueDate,
                      firstDate: earliest,
                      lastDate: latest,
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDueDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: HomeColors.cardElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HomeColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('MMM dd, yyyy (EEEE)').format(selectedDueDate),
                          style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const Spacer(),
                        Text('Change', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Late Penalty Configuration Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HomeColors.cardElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: HomeColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.alarm_add_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Late Penalty / Patong (Optional)',
                            style: TextStyle(color: HomeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pumili kung may dagdag na penalty (None, Per Day, Per Week, o Per Month).',
                        style: TextStyle(color: HomeColors.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 10),
                      // Frequency selector row
                      Row(
                        children: [
                          _buildFrequencyChip(
                            label: 'None',
                            value: 'none',
                            selectedValue: selectedFrequency,
                            onSelected: (val) {
                              setDialogState(() {
                                selectedFrequency = val;
                                penaltyCtrl.clear();
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          _buildFrequencyChip(
                            label: 'Per Day',
                            value: 'daily',
                            selectedValue: selectedFrequency,
                            onSelected: (val) {
                              setDialogState(() {
                                selectedFrequency = val;
                                if (penaltyCtrl.text.isEmpty) penaltyCtrl.text = '10';
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          _buildFrequencyChip(
                            label: 'Per Week',
                            value: 'weekly',
                            selectedValue: selectedFrequency,
                            onSelected: (val) {
                              setDialogState(() {
                                selectedFrequency = val;
                                if (penaltyCtrl.text.isEmpty) penaltyCtrl.text = '50';
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          _buildFrequencyChip(
                            label: 'Per Month',
                            value: 'monthly',
                            selectedValue: selectedFrequency,
                            onSelected: (val) {
                              setDialogState(() {
                                selectedFrequency = val;
                                if (penaltyCtrl.text.isEmpty) penaltyCtrl.text = '100';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (selectedFrequency == 'none') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: HomeColors.cardBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: HomeColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Walang penalty (₱0) kahit lumampas sa takdang petsa.',
                                  style: TextStyle(color: HomeColors.textSecondary, fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: penaltyCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(color: HomeColors.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: selectedFrequency == 'daily'
                                      ? '₱ / Day'
                                      : selectedFrequency == 'weekly'
                                          ? '₱ / Week'
                                          : '₱ / Month',
                                  hintText: '0',
                                  labelStyle: TextStyle(color: HomeColors.textSecondary, fontSize: 11),
                                  filled: true,
                                  fillColor: HomeColors.cardBackground,
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<int>(
                                initialValue: selectedGraceDays,
                                dropdownColor: HomeColors.cardElevated,
                                style: TextStyle(color: HomeColors.textPrimary, fontSize: 12),
                                decoration: InputDecoration(
                                  labelText: 'Grace Period',
                                  labelStyle: TextStyle(color: HomeColors.textSecondary, fontSize: 11),
                                  filled: true,
                                  fillColor: HomeColors.cardBackground,
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 0, child: Text('No Grace')),
                                  DropdownMenuItem(value: 1, child: Text('1 Day Grace')),
                                  DropdownMenuItem(value: 2, child: Text('2 Days Grace')),
                                  DropdownMenuItem(value: 3, child: Text('3 Days Grace')),
                                  DropdownMenuItem(value: 7, child: Text('7 Days Grace')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => selectedGraceDays = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: selectedFrequency == 'daily'
                              ? [
                                  _buildPresetPenaltyChip('₱5/d', 5, penaltyCtrl, setDialogState),
                                  _buildPresetPenaltyChip('₱10/d', 10, penaltyCtrl, setDialogState),
                                  _buildPresetPenaltyChip('₱20/d', 20, penaltyCtrl, setDialogState),
                                ]
                              : selectedFrequency == 'weekly'
                                  ? [
                                      _buildPresetPenaltyChip('₱20/wk', 20, penaltyCtrl, setDialogState),
                                      _buildPresetPenaltyChip('₱50/wk', 50, penaltyCtrl, setDialogState),
                                      _buildPresetPenaltyChip('₱100/wk', 100, penaltyCtrl, setDialogState),
                                    ]
                                  : [
                                      _buildPresetPenaltyChip('₱50/mo', 50, penaltyCtrl, setDialogState),
                                      _buildPresetPenaltyChip('₱100/mo', 100, penaltyCtrl, setDialogState),
                                      _buildPresetPenaltyChip('₱200/mo', 200, penaltyCtrl, setDialogState),
                                    ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  style: TextStyle(color: HomeColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Notes / Items bought (Optional)',
                    labelStyle: TextStyle(color: HomeColors.textSecondary),
                    filled: true,
                    fillColor: HomeColors.cardElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: isSubmitting ? HomeColors.textSecondary.withValues(alpha: 0.5) : HomeColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final rawAmt = double.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                      final rate = selectedFrequency == 'none'
                          ? 0.0
                          : (double.tryParse(penaltyCtrl.text.replaceAll(',', '').trim()) ?? 0.0);

                      if (name.isEmpty) {
                        showStoraSnackBar(context, 'Please enter customer name');
                        return;
                      }
                      if (rawAmt <= 0) {
                        showStoraSnackBar(context, 'Please enter a valid amount');
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        await UtangStore.instance.addUtang(
                          customerName: name,
                          customerPhone: phone,
                          totalAmount: rawAmt,
                          dueDate: selectedDueDate,
                          penaltyFrequency: selectedFrequency,
                          penaltyRate: rate < 0 ? 0.0 : rate,
                          gracePeriodDays: selectedGraceDays,
                          notes: notesCtrl.text.trim(),
                          items: [
                            UtangItem(
                              productName: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : 'Store Purchase',
                              quantity: 1,
                              unitPrice: rawAmt,
                            ),
                          ],
                        );

                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
                          showStoraSnackBar(context, 'Utang recorded for $name', isError: false);
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                        if (mounted) {
                          showStoraSnackBar(context, 'Failed to save utang: $e');
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Entry', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ),
  );
    } finally {
      _isOpeningDialog = false;
      nameCtrl.dispose();
      phoneCtrl.dispose();
      amountCtrl.dispose();
      notesCtrl.dispose();
      penaltyCtrl.dispose();
    }
  }

  void _showRecordPaymentDialog(UtangRecord record) async {
    if (_isOpeningDialog) return;
    _isOpeningDialog = true;

    final effectiveDue = record.penaltyAmount > 0 ? record.totalDueWithPenalty : record.balance;
    final paymentCtrl = TextEditingController(text: effectiveDue.toStringAsFixed(2));
    final noteCtrl = TextEditingController();
    bool isSubmitting = false;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) => PopScope(
            canPop: !isSubmitting,
            child: AlertDialog(
              backgroundColor: HomeColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: HomeColors.cardBorder),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.price_check_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Record Payment',
                      style: TextStyle(color: HomeColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer: ${record.customerName}',
                    style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  if (record.penaltyAmount > 0) ...[
                    Text(
                      'Principal Balance: ₱${record.balance.toStringAsFixed(2)}',
                      style: TextStyle(color: HomeColors.textSecondary, fontSize: 12),
                    ),
                    Text(
                      'Late Penalty: +₱${record.penaltyAmount.toStringAsFixed(2)} (${record.overdueUnitsLabel} late @ ₱${record.penaltyRate.toStringAsFixed(0)}/${record.penaltyFrequencyShortUnit})',
                      style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total Collectible: ₱${record.totalDueWithPenalty.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ] else ...[
                    Text(
                      'Current Balance: ₱${record.balance.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: paymentCtrl,
                    enabled: !isSubmitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Amount Paid (₱)',
                      labelStyle: TextStyle(color: HomeColors.textSecondary),
                      filled: true,
                      fillColor: HomeColors.cardElevated,
                      prefixIcon: const Icon(Icons.attach_money_rounded, color: Color(0xFF10B981)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (record.penaltyAmount > 0) ...[
                        ActionChip(
                          label: Text('Pay Total (₱${record.totalDueWithPenalty.toStringAsFixed(2)})', style: const TextStyle(fontSize: 11)),
                          onPressed: isSubmitting ? null : () => setDialogState(() => paymentCtrl.text = record.totalDueWithPenalty.toStringAsFixed(2)),
                          backgroundColor: HomeColors.cardElevated,
                          labelStyle: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                        ),
                        ActionChip(
                          label: Text('Principal Only (₱${record.balance.toStringAsFixed(2)})', style: const TextStyle(fontSize: 11)),
                          onPressed: isSubmitting ? null : () => setDialogState(() => paymentCtrl.text = record.balance.toStringAsFixed(2)),
                          backgroundColor: HomeColors.cardElevated,
                          labelStyle: TextStyle(color: HomeColors.textPrimary),
                        ),
                      ] else ...[
                        ActionChip(
                          label: const Text('Exact Full Payment', style: TextStyle(fontSize: 11)),
                          onPressed: isSubmitting ? null : () => setDialogState(() => paymentCtrl.text = record.balance.toStringAsFixed(2)),
                          backgroundColor: HomeColors.cardElevated,
                          labelStyle: TextStyle(color: HomeColors.textPrimary),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    enabled: !isSubmitting,
                    style: TextStyle(color: HomeColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Payment Note (e.g. Cash, Online Payment)',
                      labelStyle: TextStyle(color: HomeColors.textSecondary),
                      filled: true,
                      fillColor: HomeColors.cardElevated,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: isSubmitting ? HomeColors.textSecondary.withValues(alpha: 0.5) : HomeColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final paid = double.tryParse(paymentCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                          final maxAllowed = record.penaltyAmount > 0 ? record.totalDueWithPenalty : record.balance;
                          if (paid <= 0) {
                            showStoraSnackBar(context, 'Please enter a valid payment amount');
                            return;
                          }
                          if (paid > maxAllowed + 0.01) {
                            showStoraSnackBar(context, 'Payment cannot exceed total due of ₱${maxAllowed.toStringAsFixed(2)}');
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            await UtangStore.instance.recordPayment(
                              recordId: record.id,
                              amount: paid,
                              note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                            );
                            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                            if (mounted) {
                              showStoraSnackBar(context, 'Payment of ₱${paid.toStringAsFixed(2)} recorded!', isError: false);
                            }
                          } catch (e) {
                            if (dialogCtx.mounted) {
                              setDialogState(() => isSubmitting = false);
                            }
                            if (mounted) {
                              showStoraSnackBar(context, 'Error recording payment: $e');
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      _isOpeningDialog = false;
      paymentCtrl.dispose();
      noteCtrl.dispose();
    }
  }

  void _sendReminder(UtangRecord record) {
    final storeName = AuthStore.instance.businessName ?? 'Our Store';
    final dueFormatted = DateFormat('MMM dd, yyyy').format(record.dueDate);
    final totalDue = record.penaltyAmount > 0 ? record.totalDueWithPenalty : record.balance;

    String msg;
    if (record.isOverdue && record.penaltyAmount > 0) {
      msg =
          'Magandang araw po ${record.customerName}! Paalala lang po mula sa $storeName: Ang inyong utang na ₱${record.balance.toStringAsFixed(2)} ay lumampas sa takdang petsa noong $dueFormatted.\n\n'
          'May dagdag na late penalty na ₱${record.penaltyAmount.toStringAsFixed(2)} (${record.overdueUnitsTagalog} x ₱${record.penaltyRate.toStringAsFixed(0)}/${record.penaltyFrequencyTagalog}).\n'
          'Kabuuang dapat bayaran: ₱${totalDue.toStringAsFixed(2)}.\n\n'
          'Paki-settle po sa lalong madaling panahon. Maraming salamat po!';
    } else if (record.isOverdue) {
      msg =
          'Magandang araw po ${record.customerName}! Paalala lang po mula sa $storeName: Ang inyong balance na ₱${record.balance.toStringAsFixed(2)} ay lumampas sa takdang petsa noong $dueFormatted. Paki-settle po sa lalong madaling panahon. Maraming salamat po!';
    } else {
      msg =
          'Magandang araw po ${record.customerName}! Paalala lang po mula sa $storeName tungkol sa inyong balance na ₱${record.balance.toStringAsFixed(2)} na nakatakda sa $dueFormatted. Maraming salamat po!';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: HomeColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send Payment Reminder', style: TextStyle(color: HomeColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HomeColors.cardElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HomeColors.cardBorder),
                ),
                child: Text(msg, style: TextStyle(color: HomeColors.textSecondary, fontSize: 13, height: 1.4)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (record.customerPhone.isNotEmpty) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.sms_rounded, size: 18),
                        label: const Text('Send SMS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            final uri = Uri.parse('sms:${record.customerPhone}?body=${Uri.encodeComponent(msg)}');
                            final launched = await launchUrl(uri);
                            if (!launched) {
                              await Share.share(msg);
                            }
                          } catch (_) {
                            await Share.share(msg);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share App / Copy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HomeColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: HomeColors.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Share.share(msg);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(UtangRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: HomeColors.cardBorder),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete Utang Entry',
                style: TextStyle(color: HomeColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the record for "${record.customerName}"? This will permanently remove this entry and its payment history from your listahan.',
          style: TextStyle(color: HomeColors.textSecondary, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await UtangStore.instance.deleteUtang(record.id);
      if (mounted) {
        showStoraSnackBar(context, 'Entry deleted from listahan', isError: false);
      }
    }
  }

  void _showEditPenaltyDialog(UtangRecord record) async {
    String selectedFrequency = record.hasPenalty ? record.penaltyFrequency : 'none';
    final penaltyCtrl = TextEditingController(
      text: record.penaltyRate > 0 ? record.penaltyRate.toStringAsFixed(0) : '',
    );
    int graceDays = record.gracePeriodDays;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: HomeColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: HomeColors.cardBorder),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.alarm_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Set Late Penalty',
                style: TextStyle(color: HomeColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer: ${record.customerName}',
                  style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  'Frequency:',
                  style: TextStyle(color: HomeColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildFrequencyChip(
                      label: 'None',
                      value: 'none',
                      selectedValue: selectedFrequency,
                      onSelected: (val) {
                        setDialogState(() {
                          selectedFrequency = val;
                          penaltyCtrl.clear();
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildFrequencyChip(
                      label: 'Per Day',
                      value: 'daily',
                      selectedValue: selectedFrequency,
                      onSelected: (val) {
                        setDialogState(() {
                          selectedFrequency = val;
                          if (penaltyCtrl.text.isEmpty) penaltyCtrl.text = '10';
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildFrequencyChip(
                      label: 'Per Week',
                      value: 'weekly',
                      selectedValue: selectedFrequency,
                      onSelected: (val) {
                        setDialogState(() {
                          selectedFrequency = val;
                          if (penaltyCtrl.text.isEmpty) penaltyCtrl.text = '50';
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildFrequencyChip(
                      label: 'Per Month',
                      value: 'monthly',
                      selectedValue: selectedFrequency,
                      onSelected: (val) {
                        setDialogState(() {
                          selectedFrequency = val;
                          if (penaltyCtrl.text.isEmpty) penaltyCtrl.text = '100';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (selectedFrequency == 'none') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: HomeColors.cardElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: HomeColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Walang late penalty na sisingilin para sa utang na ito.',
                            style: TextStyle(color: HomeColors.textSecondary, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: penaltyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: HomeColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: selectedFrequency == 'daily'
                          ? 'Penalty Rate (₱ / day)'
                          : selectedFrequency == 'weekly'
                              ? 'Penalty Rate (₱ / week)'
                              : 'Penalty Rate (₱ / month)',
                      hintText: 'Enter amount',
                      labelStyle: TextStyle(color: HomeColors.textSecondary),
                      filled: true,
                      fillColor: HomeColors.cardElevated,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selectedFrequency == 'daily'
                        ? [
                            _buildPresetPenaltyChip('₱5/d', 5, penaltyCtrl, setDialogState),
                            _buildPresetPenaltyChip('₱10/d', 10, penaltyCtrl, setDialogState),
                            _buildPresetPenaltyChip('₱20/d', 20, penaltyCtrl, setDialogState),
                          ]
                        : selectedFrequency == 'weekly'
                            ? [
                                _buildPresetPenaltyChip('₱20/wk', 20, penaltyCtrl, setDialogState),
                                _buildPresetPenaltyChip('₱50/wk', 50, penaltyCtrl, setDialogState),
                                _buildPresetPenaltyChip('₱100/wk', 100, penaltyCtrl, setDialogState),
                              ]
                            : [
                                _buildPresetPenaltyChip('₱50/mo', 50, penaltyCtrl, setDialogState),
                                _buildPresetPenaltyChip('₱100/mo', 100, penaltyCtrl, setDialogState),
                                _buildPresetPenaltyChip('₱200/mo', 200, penaltyCtrl, setDialogState),
                              ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: graceDays,
                    dropdownColor: HomeColors.cardElevated,
                    style: TextStyle(color: HomeColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Grace Period',
                      labelStyle: TextStyle(color: HomeColors.textSecondary),
                      filled: true,
                      fillColor: HomeColors.cardElevated,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('No Grace (Immediate after due)')),
                      DropdownMenuItem(value: 1, child: Text('1 Day Grace')),
                      DropdownMenuItem(value: 2, child: Text('2 Days Grace')),
                      DropdownMenuItem(value: 3, child: Text('3 Days Grace')),
                      DropdownMenuItem(value: 7, child: Text('7 Days Grace')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => graceDays = val);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final rate = selectedFrequency == 'none'
                    ? 0.0
                    : (double.tryParse(penaltyCtrl.text.replaceAll(',', '').trim()) ?? 0.0);
                await UtangStore.instance.updatePenaltySettings(
                  record.id,
                  penaltyFrequency: selectedFrequency,
                  penaltyRate: rate < 0 ? 0.0 : rate,
                  gracePeriodDays: graceDays,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!mounted) return;
                showStoraSnackBar(this.context, 'Penalty settings updated for ${record.customerName}', isError: false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    penaltyCtrl.dispose();
  }

  void _showRecordDetailsSheet(UtangRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HomeColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.customerName,
                            style: TextStyle(color: HomeColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                        if (record.customerPhone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(record.customerPhone,
                              style: TextStyle(color: HomeColors.textSecondary, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                  _buildStatusChip(record),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
                    tooltip: 'Delete Entry',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDelete(record);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Balance summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade900.withValues(alpha: 0.35),
                      Colors.amber.shade700.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.penaltyAmount > 0 ? 'Total Collectible' : 'Remaining Balance',
                          style: TextStyle(color: HomeColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${record.totalDueWithPenalty.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                        if (record.penaltyAmount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Loan: ₱${record.balance.toStringAsFixed(2)} + Fee: ₱${record.penaltyAmount.toStringAsFixed(2)}',
                            style: TextStyle(color: HomeColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Original: ₱${record.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(color: HomeColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          'Paid: ₱${record.amountPaid.toStringAsFixed(2)}',
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Late Penalty Status Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HomeColors.cardElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: record.penaltyAmount > 0
                        ? AppColors.error.withValues(alpha: 0.4)
                        : HomeColors.cardBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.alarm_rounded,
                              color: record.penaltyAmount > 0 ? AppColors.error : Colors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Late Payment Penalty',
                              style: TextStyle(color: HomeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (record.hasPenalty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '₱${record.penaltyRate.toStringAsFixed(0)} / ${record.penaltyFrequencyShortUnit}',
                              style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!record.hasPenalty) ...[
                      Text(
                        'Walang late penalty na nakatakda para sa listahang ito.',
                        style: TextStyle(color: HomeColors.textSecondary, fontSize: 12),
                      ),
                    ] else if (record.isPenaltyWaived) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Late penalty has been waived for this customer by the store.',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (record.isOverdue) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${record.overdueDays} days past due date',
                                style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${record.overdueUnitsLabel} penalized (${record.gracePeriodDays}d grace period)',
                                style: TextStyle(color: HomeColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                          Text(
                            '+₱${record.penaltyAmount.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppColors.error, fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Penalty starts after grace period (${DateFormat('MMM dd').format(record.dueDate.add(Duration(days: record.gracePeriodDays)))}).',
                        style: TextStyle(color: HomeColors.textSecondary, fontSize: 12),
                      ),
                    ],
                    if (!record.isFullyPaid) ...[
                      const SizedBox(height: 10),
                      Divider(color: HomeColors.cardBorder, height: 1),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (record.hasPenalty)
                            TextButton.icon(
                              icon: Icon(
                                record.isPenaltyWaived ? Icons.undo_rounded : Icons.money_off_rounded,
                                size: 16,
                                color: record.isPenaltyWaived ? Colors.amber : const Color(0xFF10B981),
                              ),
                              label: Text(
                                record.isPenaltyWaived ? 'Restore Penalty' : 'Waive Penalty',
                                style: TextStyle(
                                  color: record.isPenaltyWaived ? Colors.amber : const Color(0xFF10B981),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () async {
                                await UtangStore.instance.waivePenalty(record.id, waived: !record.isPenaltyWaived);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (!mounted) return;
                                showStoraSnackBar(
                                  this.context,
                                  record.isPenaltyWaived
                                      ? 'Penalty restored for ${record.customerName}'
                                      : 'Penalty waived for ${record.customerName}!',
                                  isError: false,
                                );
                              },
                            ),
                          TextButton.icon(
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: Text(
                              record.hasPenalty ? 'Edit Rate' : 'Set Penalty Rate',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showEditPenaltyDialog(record);
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Due date row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: HomeColors.cardElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HomeColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      record.isOverdue ? Icons.warning_rounded : Icons.event_rounded,
                      color: record.isOverdue ? AppColors.error : HomeColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment Deadline', style: TextStyle(color: HomeColors.textSecondary, fontSize: 11)),
                        Text(
                          DateFormat('MMMM dd, yyyy').format(record.dueDate),
                          style: TextStyle(
                            color: record.isOverdue ? AppColors.error : HomeColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (!record.isFullyPaid)
                      TextButton(
                        onPressed: () async {
                          final now = DateTime.now();
                          final earliest = record.dueDate.isBefore(now.subtract(const Duration(days: 365)))
                              ? record.dueDate.subtract(const Duration(days: 30))
                              : now.subtract(const Duration(days: 365));
                          final latest = record.dueDate.isAfter(now.add(const Duration(days: 365 * 2)))
                              ? record.dueDate.add(const Duration(days: 365))
                              : now.add(const Duration(days: 365 * 2));
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: record.dueDate,
                            firstDate: earliest,
                            lastDate: latest,
                          );
                          if (picked != null) {
                            await UtangStore.instance.updateDueDate(record.id, picked);
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                        child: const Text('Change Date', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Items receipt breakdown
              Text('Items Breakdown', style: TextStyle(color: HomeColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (record.items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HomeColors.cardElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    record.notes.isNotEmpty ? record.notes : 'General store credit',
                    style: TextStyle(color: HomeColors.textSecondary, fontSize: 13),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: HomeColors.cardElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: HomeColors.cardBorder),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: record.items.length,
                    separatorBuilder: (_, _) => Divider(color: HomeColors.cardBorder, height: 1),
                    itemBuilder: (context, i) {
                      final item = record.items[i];
                      return ListTile(
                        dense: true,
                        title: Text(item.productName,
                            style: TextStyle(color: HomeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('${item.quantity}x @ ₱${item.unitPrice.toStringAsFixed(2)}',
                            style: TextStyle(color: HomeColors.textSecondary, fontSize: 11)),
                        trailing: Text('₱${item.totalPrice.toStringAsFixed(2)}',
                            style: TextStyle(color: HomeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              // Payment history
              if (record.payments.isNotEmpty) ...[
                Text('Payment History', style: TextStyle(color: HomeColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: HomeColors.cardElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: HomeColors.cardBorder),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: record.payments.length,
                    separatorBuilder: (_, _) => Divider(color: HomeColors.cardBorder, height: 1),
                    itemBuilder: (context, i) {
                      final p = record.payments[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                        title: Text('₱${p.amount.toStringAsFixed(2)}',
                            style: TextStyle(color: HomeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${DateFormat('MMM dd, yyyy h:mm a').format(p.paidAt)}${p.note != null ? ' · ${p.note}' : ''}',
                          style: TextStyle(color: HomeColors.textSecondary, fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Actions
              if (!record.isFullyPaid) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payments_rounded, size: 18),
                        label: const Text('Record Payment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showRecordPaymentDialog(record);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      tooltip: 'Remind Customer',
                      style: IconButton.styleFrom(
                        backgroundColor: HomeColors.cardElevated,
                        foregroundColor: HomeColors.textPrimary,
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sendReminder(record);
                      },
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                    label: const Text('Delete from Listahan',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDelete(record);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(UtangRecord record) {
    if (record.isFullyPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF10B981)),
        ),
        child: const Text('PAID IN FULL',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w800)),
      );
    }
    if (record.isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error),
        ),
        child: const Text('OVERDUE',
            style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w800)),
      );
    }
    if (record.isDueToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber),
        ),
        child: const Text('DUE TODAY',
            style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w800)),
      );
    }
    if (record.isDueSoon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange),
        ),
        child: const Text('DUE SOON',
            style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w800)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary),
      ),
      child: const Text('CURRENT',
          style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UtangStore.instance,
      builder: (context, _) {
        final store = UtangStore.instance;
        final allRecords = store.records;
        final filteredRecords = _filterRecords(allRecords);

        return Scaffold(
          backgroundColor: HomeColors.background,
          appBar: AppBar(
            backgroundColor: HomeColors.cardBackground,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: HomeColors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Utang Ledger (Listahan)',
              style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.amber),
                tooltip: 'Add New Utang',
                onPressed: _showNewUtangDialog,
              ),
            ],
          ),
          body: Column(
            children: [
              // Summary Banner
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFB45309), // amber-700
                      const Color(0xFF78350F), // amber-900
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB45309).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Collectible Utang',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '₱${store.totalOutstanding.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            store.totalAccruedPenalties > 0
                                ? '${store.activeRecords.length} active loans (incl. ₱${store.totalAccruedPenalties.toStringAsFixed(2)} late fees)'
                                : '${store.activeRecords.length} active credit loans · ${store.totalActiveDebtors} customers',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (store.overdueRecords.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${store.overdueRecords.length} Overdue',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(color: HomeColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search customer name or phone...',
                    hintStyle: TextStyle(color: HomeColors.textSecondary),
                    filled: true,
                    fillColor: HomeColors.cardBackground,
                    prefixIcon: Icon(Icons.search_rounded, color: HomeColors.textSecondary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: HomeColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: HomeColors.cardBorder),
                    ),
                  ),
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    _buildFilterChip('Active', '${store.activeRecords.length}'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Overdue', '${store.overdueRecords.length}', isAlert: store.overdueRecords.isNotEmpty),
                    const SizedBox(width: 8),
                    _buildFilterChip('Due Soon', '${store.dueTodayOrSoonRecords.length}'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Paid', '${store.paidRecords.length}'),
                    const SizedBox(width: 8),
                    _buildFilterChip('All', '${allRecords.length}'),
                  ],
                ),
              ),

              // Records List
              Expanded(
                child: filteredRecords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_turned_in_rounded, size: 54, color: HomeColors.textSecondary.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text('No records found',
                                style: TextStyle(color: HomeColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No utang matched your search.'
                                  : 'Tap + above to record a new walk-in credit.',
                              style: TextStyle(color: HomeColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                        itemCount: filteredRecords.length,
                        itemBuilder: (context, i) {
                          final record = filteredRecords[i];
                          return _buildRecordCard(record);
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showNewUtangDialog,
            backgroundColor: Colors.amber[700],
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Utang', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String count, {bool isAlert = false}) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = label),
      selectedColor: isAlert ? AppColors.error : AppColors.primary,
      backgroundColor: HomeColors.cardBackground,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : HomeColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(color: isAlert ? AppColors.error : HomeColors.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildRecordCard(UtangRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: record.isOverdue
              ? AppColors.error.withValues(alpha: 0.5)
              : record.isDueToday
                  ? Colors.amber.withValues(alpha: 0.5)
                  : HomeColors.cardBorder,
          width: record.isOverdue || record.isDueToday ? 1.5 : 1,
        ),
        boxShadow: HomeColors.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showRecordDetailsSheet(record),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.amber.withValues(alpha: 0.15),
                    child: Text(
                      record.customerName.isNotEmpty ? record.customerName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.customerName,
                          style: TextStyle(color: HomeColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 12, color: HomeColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              record.isOverdue
                                  ? 'Due: ${DateFormat('MMM dd').format(record.dueDate)} (${record.overdueDays}d late)'
                                  : 'Due: ${DateFormat('MMM dd, yyyy').format(record.dueDate)}',
                              style: TextStyle(
                                color: record.isOverdue
                                    ? AppColors.error
                                    : record.isDueToday
                                        ? Colors.amber
                                        : HomeColors.textSecondary,
                                fontSize: 12,
                                fontWeight: record.isOverdue || record.isDueToday ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱${(record.penaltyAmount > 0 ? record.totalDueWithPenalty : record.balance).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: record.isFullyPaid ? const Color(0xFF10B981) : Colors.amber,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (record.penaltyAmount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            '+₱${record.penaltyAmount.toStringAsFixed(0)} fee',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      _buildStatusChip(record),
                    ],
                  ),
                ],
              ),
              if (record.items.isNotEmpty || record.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: HomeColors.cardBorder, height: 1),
                const SizedBox(height: 10),
                Text(
                  record.items.isNotEmpty
                      ? record.items.map((i) => '${i.quantity}x ${i.productName}').join(', ')
                      : record.notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: HomeColors.textSecondary, fontSize: 12),
                ),
              ],
              if (record.hasPenalty && (record.isOverdue || record.isPenaltyWaived)) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: record.isPenaltyWaived
                        ? const Color(0xFF10B981).withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: record.isPenaltyWaived
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        record.isPenaltyWaived ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        size: 14,
                        color: record.isPenaltyWaived ? const Color(0xFF10B981) : AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          record.isPenaltyWaived
                              ? 'Late penalty waived by store'
                              : '${record.overdueUnitsLabel} late @ ₱${record.penaltyRate.toStringAsFixed(0)}/${record.penaltyFrequencyShortUnit} = +₱${record.penaltyAmount.toStringAsFixed(2)} fee',
                          style: TextStyle(
                            color: record.isPenaltyWaived ? const Color(0xFF10B981) : AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!record.isFullyPaid) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.notifications_active_rounded, size: 14),
                      label: const Text('Remind', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HomeColors.textPrimary,
                        side: BorderSide(color: HomeColors.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => _sendReminder(record),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.payments_rounded, size: 14),
                      label: const Text('Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      onPressed: () => _showRecordPaymentDialog(record),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.error),
                      label: const Text('Delete',
                          style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () => _confirmDelete(record),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
