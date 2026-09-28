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

  void _showNewUtangDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 7));

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
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final rawAmt = double.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

                if (name.isEmpty) {
                  showStoraSnackBar(context, 'Please enter customer name');
                  return;
                }
                if (rawAmt <= 0) {
                  showStoraSnackBar(context, 'Please enter a valid amount');
                  return;
                }

                await UtangStore.instance.addUtang(
                  customerName: name,
                  customerPhone: phone,
                  totalAmount: rawAmt,
                  dueDate: selectedDueDate,
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
                if (context.mounted) {
                  showStoraSnackBar(context, 'Utang recorded for $name', isError: false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save Entry', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    amountCtrl.dispose();
    notesCtrl.dispose();
  }

  void _showRecordPaymentDialog(UtangRecord record) async {
    final paymentCtrl = TextEditingController(text: record.balance.toStringAsFixed(2));
    final noteCtrl = TextEditingController();

    await showDialog(
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
            const SizedBox(height: 4),
            Text(
              'Current Balance: ₱${record.balance.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: paymentCtrl,
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
            Row(
              children: [
                ActionChip(
                  label: const Text('Exact Full Payment', style: TextStyle(fontSize: 11)),
                  onPressed: () => paymentCtrl.text = record.balance.toStringAsFixed(2),
                  backgroundColor: HomeColors.cardElevated,
                  labelStyle: TextStyle(color: HomeColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              style: TextStyle(color: HomeColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Payment Note (e.g. Cash, Gcash)',
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final paid = double.tryParse(paymentCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
              if (paid <= 0) {
                showStoraSnackBar(context, 'Please enter a valid payment amount');
                return;
              }
              if (paid > record.balance + 0.01) {
                showStoraSnackBar(context, 'Payment cannot exceed remaining balance of ₱${record.balance.toStringAsFixed(2)}');
                return;
              }
              await UtangStore.instance.recordPayment(
                recordId: record.id,
                amount: paid,
                note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                showStoraSnackBar(context, 'Payment of ₱${paid.toStringAsFixed(2)} recorded!', isError: false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    paymentCtrl.dispose();
    noteCtrl.dispose();
  }

  void _sendReminder(UtangRecord record) {
    final storeName = AuthStore.instance.businessName ?? 'Our Store';
    final dueFormatted = DateFormat('MMM dd, yyyy').format(record.dueDate);
    final msg =
        'Magandang araw po ${record.customerName}! Paalala lang po mula sa $storeName tungkol sa inyong balance na ₱${record.balance.toStringAsFixed(2)} na nakatakda sa $dueFormatted. Maraming salamat po!';

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
                        Text('Remaining Balance', style: TextStyle(color: HomeColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '₱${record.balance.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
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
              const SizedBox(height: 20),
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
                            '${store.activeRecords.length} active credit loans · ${store.totalActiveDebtors} customers',
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
                              'Due: ${DateFormat('MMM dd, yyyy').format(record.dueDate)}',
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
                        '₱${record.balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: record.isFullyPaid ? const Color(0xFF10B981) : Colors.amber,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
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
