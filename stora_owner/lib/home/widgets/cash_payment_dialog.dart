import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/barcode_scanner_screen.dart';
import '../stores/store_status_store.dart';
import '../theme/home_colors.dart';
import 'payment_qr_modal.dart';

class CashPaymentResult {
  final double tendered;
  final double change;
  final String customerName;
  final String customerPhone;
  final bool isUtang;
  final DateTime? dueDate;
  final String penaltyFrequency;
  final double penaltyRate;
  final int gracePeriodDays;
  final String paymentMethod; // 'cash' or 'online'
  final String referenceNumber;
  final String notes;

  const CashPaymentResult({
    required this.tendered,
    required this.change,
    this.customerName = 'Walk-in Customer',
    this.customerPhone = '',
    this.isUtang = false,
    this.dueDate,
    this.penaltyFrequency = 'none',
    this.penaltyRate = 0.0,
    this.gracePeriodDays = 0,
    this.paymentMethod = 'cash',
    this.referenceNumber = '',
    this.notes = '',
  });
}

class CashPaymentDialog extends StatefulWidget {
  final double totalAmount;

  const CashPaymentDialog({super.key, required this.totalAmount});

  static bool _isShowing = false;

  static Future<CashPaymentResult?> show(
    BuildContext context, {
    required double totalAmount,
  }) async {
    if (_isShowing) return null;
    _isShowing = true;
    try {
      return await showModalBottomSheet<CashPaymentResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CashPaymentDialog(totalAmount: totalAmount),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<CashPaymentDialog> createState() => _CashPaymentDialogState();
}

class _CashPaymentDialogState extends State<CashPaymentDialog> {
  late final TextEditingController _controller;
  late final TextEditingController _customerNameController;
  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;
  double _tendered = 0.0;
  bool _isSubmitted = false;
  bool _isOnlinePayment = false;

  @override
  void initState() {
    super.initState();
    // Default to exact amount for quick 1-tap checkout
    _tendered = widget.totalAmount;
    _controller = TextEditingController(
      text: widget.totalAmount.toStringAsFixed(2),
    );
    _customerNameController = TextEditingController();
    _referenceController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _customerNameController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTenderedChanged(String val) {
    final raw = double.tryParse(val.replaceAll(',', '').trim()) ?? 0.0;
    final parsed = raw < 0.0 ? 0.0 : raw;
    setState(() {
      _tendered = parsed;
    });
  }

  void _selectAmount(double amount) {
    HapticFeedback.lightImpact();
    setState(() {
      _tendered = amount;
      _controller.text = amount.toStringAsFixed(2);
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  List<double> _buildQuickOptions() {
    final total = widget.totalAmount;
    final options = <double>{};

    // 1. Exact amount
    options.add(total);

    // 2. Next nearest rounded amounts (e.g., next 50, next 100)
    final next50 = (total / 50).ceil() * 50.0;
    if (next50 > total) options.add(next50);

    final next100 = (total / 100).ceil() * 100.0;
    if (next100 > total && next100 != next50) options.add(next100);

    final next500 = (total / 500).ceil() * 500.0;
    if (next500 > total) options.add(next500);

    final next1000 = (total / 1000).ceil() * 1000.0;
    if (next1000 > total) options.add(next1000);

    // 3. Standard Philippine Peso bills that can cover the total
    const standardBills = [50.0, 100.0, 200.0, 500.0, 1000.0];
    for (final bill in standardBills) {
      if (bill >= total) {
        options.add(bill);
      }
    }

    // Sort ascending
    final sorted = options.toList()..sort();
    return sorted;
  }

  Widget _buildStoreQrActionCard(BuildContext context) {
    final status = StoreStatusStore.instance;
    final accounts = status.paymentAccounts;
    final hasAccounts = accounts.isNotEmpty ||
        status.paymentPhoneNumber.isNotEmpty ||
        (status.paymentQrUrl != null && status.paymentQrUrl!.isNotEmpty);

    final labels = accounts.isNotEmpty
        ? accounts.map((a) => a.label.trim()).where((l) => l.isNotEmpty).toList()
        : ['GCash / Online'];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          showPaymentQrModal(context);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2563EB).withValues(alpha: 0.12),
                const Color(0xFF06B6D4).withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Show Store Payment QR',
                            style: TextStyle(
                              color: HomeColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'READY',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasAccounts
                          ? 'Customer can scan phone now (${labels.take(3).join(', ')})'
                          : 'Tap to view or setup store payment QR',
                      style: TextStyle(
                        color: HomeColors.textSecondary,
                        fontSize: 11,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fullscreen_rounded, color: Colors.white, size: 15),
                    SizedBox(width: 4),
                    Text(
                      'Show',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmPayment() {
    if (_isSubmitted) return;
    final name = _customerNameController.text.trim();
    final customerDisplayName = name.isNotEmpty ? name : 'Walk-in Customer';
    final notes = _notesController.text.trim();

    if (_isOnlinePayment) {
      _isSubmitted = true;
      final ref = _referenceController.text.trim();
      Navigator.of(context).pop(
        CashPaymentResult(
          tendered: widget.totalAmount,
          change: 0.0,
          customerName: customerDisplayName,
          paymentMethod: 'online',
          referenceNumber: ref,
          notes: notes,
        ),
      );
      return;
    }

    final change = _tendered - widget.totalAmount;
    if (change < -0.001) return;
    _isSubmitted = true;

    Navigator.of(context).pop(
      CashPaymentResult(
        tendered: _tendered,
        change: change < 0 ? 0.0 : change,
        customerName: customerDisplayName,
        paymentMethod: 'cash',
        referenceNumber: '',
        notes: notes,
      ),
    );
  }

  Widget _buildUtangFrequencyChip({
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

  Widget _buildUtangPresetPenaltyChip(
    String label,
    double amount,
    TextEditingController ctrl,
    StateSetter setDialogState,
  ) {
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

  void _chargeToUtang() async {
    if (_isSubmitted) return;
    final currentName = _customerNameController.text.trim();
    final nameCtrl = TextEditingController(text: currentName.isEmpty ? '' : currentName);
    final phoneCtrl = TextEditingController();
    final penaltyCtrl = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    String selectedFrequency = 'none';
    int selectedGraceDays = 0;

    String? nameError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                'Charge to Utang',
                style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Amount: ₱${widget.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: HomeColors.textPrimary),
                  onChanged: (_) {
                    if (nameError != null) setDialogState(() => nameError = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Customer Name *',
                    labelStyle: TextStyle(color: HomeColors.textSecondary),
                    errorText: nameError,
                    filled: true,
                    fillColor: HomeColors.cardElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: HomeColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    labelStyle: TextStyle(color: HomeColors.textSecondary),
                    filled: true,
                    fillColor: HomeColors.cardElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Payment Due Date', style: TextStyle(color: HomeColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dueDate.isBefore(today) ? today : dueDate,
                      firstDate: today,
                      lastDate: DateTime(now.year + 2, now.month, now.day),
                    );
                    if (picked != null) {
                      setDialogState(() => dueDate = picked);
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
                        const Icon(Icons.event_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${dueDate.month}/${dueDate.day}/${dueDate.year}',
                          style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        const Text('Change', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Penalty Selection
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HomeColors.cardElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HomeColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.alarm_add_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
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
                      // Frequency selector row with compact FittedBox chip sizing
                      Row(
                        children: [
                          _buildUtangFrequencyChip(
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
                          _buildUtangFrequencyChip(
                            label: 'Per Day',
                            value: 'daily',
                            selectedValue: selectedFrequency,
                            onSelected: (val) {
                              setDialogState(() {
                                selectedFrequency = val;
                                if (penaltyCtrl.text.isEmpty || penaltyCtrl.text == '50' || penaltyCtrl.text == '100' || penaltyCtrl.text == '10.00' || penaltyCtrl.text == '50.00' || penaltyCtrl.text == '100.00') {
                                  penaltyCtrl.text = '10';
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          _buildUtangFrequencyChip(
                            label: 'Per Week',
                            value: 'weekly',
                            selectedValue: selectedFrequency,
                            onSelected: (val) {
                              setDialogState(() {
                                selectedFrequency = val;
                                if (penaltyCtrl.text.isEmpty || penaltyCtrl.text == '10' || penaltyCtrl.text == '100' || penaltyCtrl.text == '10.00' || penaltyCtrl.text == '50.00' || penaltyCtrl.text == '100.00') {
                                  penaltyCtrl.text = '50';
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          _buildUtangFrequencyChip(
                            label: 'Per Month',
                            value: 'monthly',
                            selectedValue: selectedFrequency,
                            onSelected: (val) {
                              setDialogState(() {
                                selectedFrequency = val;
                                if (penaltyCtrl.text.isEmpty || penaltyCtrl.text == '10' || penaltyCtrl.text == '50' || penaltyCtrl.text == '10.00' || penaltyCtrl.text == '50.00' || penaltyCtrl.text == '100.00') {
                                  penaltyCtrl.text = '100';
                                }
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
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                  _buildUtangPresetPenaltyChip('₱5/d', 5, penaltyCtrl, setDialogState),
                                  _buildUtangPresetPenaltyChip('₱10/d', 10, penaltyCtrl, setDialogState),
                                  _buildUtangPresetPenaltyChip('₱20/d', 20, penaltyCtrl, setDialogState),
                                  _buildUtangPresetPenaltyChip('₱50/d', 50, penaltyCtrl, setDialogState),
                                ]
                              : selectedFrequency == 'weekly'
                                  ? [
                                      _buildUtangPresetPenaltyChip('₱20/wk', 20, penaltyCtrl, setDialogState),
                                      _buildUtangPresetPenaltyChip('₱50/wk', 50, penaltyCtrl, setDialogState),
                                      _buildUtangPresetPenaltyChip('₱100/wk', 100, penaltyCtrl, setDialogState),
                                      _buildUtangPresetPenaltyChip('₱200/wk', 200, penaltyCtrl, setDialogState),
                                    ]
                                  : [
                                      _buildUtangPresetPenaltyChip('₱50/mo', 50, penaltyCtrl, setDialogState),
                                      _buildUtangPresetPenaltyChip('₱100/mo', 100, penaltyCtrl, setDialogState),
                                      _buildUtangPresetPenaltyChip('₱200/mo', 200, penaltyCtrl, setDialogState),
                                      _buildUtangPresetPenaltyChip('₱500/mo', 500, penaltyCtrl, setDialogState),
                                    ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) {
                  setDialogState(() => nameError = 'Customer name is required');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Utang'),
            ),
          ],
        ),
      ),
    );

    final rate = selectedFrequency == 'none'
        ? 0.0
        : (double.tryParse(penaltyCtrl.text.replaceAll(',', '').trim()) ?? 0.0);
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    penaltyCtrl.dispose();

    if (confirmed == true && mounted) {
      if (_isSubmitted) return;
      _isSubmitted = true;
      Navigator.of(context).pop(
        CashPaymentResult(
          tendered: 0.0,
          change: 0.0,
          customerName: name.isNotEmpty ? name : 'Walk-in Customer',
          customerPhone: phone,
          isUtang: true,
          dueDate: dueDate,
          penaltyFrequency: selectedFrequency,
          penaltyRate: rate < 0 ? 0.0 : rate,
          gracePeriodDays: selectedGraceDays,
          paymentMethod: 'cash',
          referenceNumber: '',
          notes: _notesController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final total = widget.totalAmount;
    final change = _tendered - total;
    final isSufficient = change >= -0.001;
    final quickOptions = _buildQuickOptions();

    return Container(
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HomeColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_isOnlinePayment ? const Color(0xFF2196F3) : HomeColors.primary).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isOnlinePayment ? Icons.qr_code_scanner_rounded : Icons.payments_rounded,
                          color: _isOnlinePayment ? const Color(0xFF2196F3) : HomeColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isOnlinePayment ? 'Online Payment' : 'Cash Payment',
                        style: TextStyle(
                          color: HomeColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: HomeColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Payment Method Selector Tabs
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: HomeColors.cardElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HomeColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isOnlinePayment = false);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: !_isOnlinePayment ? HomeColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !_isOnlinePayment
                                ? [
                                    BoxShadow(
                                      color: HomeColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payments_rounded,
                                size: 16,
                                color: !_isOnlinePayment ? Colors.white : HomeColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Cash',
                                style: TextStyle(
                                  color: !_isOnlinePayment ? Colors.white : HomeColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isOnlinePayment = true);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _isOnlinePayment ? const Color(0xFF2196F3) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _isOnlinePayment
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.smartphone_rounded,
                                size: 16,
                                color: _isOnlinePayment ? Colors.white : HomeColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Online / E-Wallet',
                                style: TextStyle(
                                  color: _isOnlinePayment ? Colors.white : HomeColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Total Due Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: HomeColors.cardElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isOnlinePayment
                        ? const Color(0xFF2196F3).withValues(alpha: 0.3)
                        : HomeColors.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL DUE',
                      style: TextStyle(
                        color: HomeColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '₱${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: _isOnlinePayment ? const Color(0xFF64B5F6) : HomeColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Customer Name / Sender Label & Input (Optional)
              Text(
                _isOnlinePayment ? 'SENDER / CUSTOMER NAME (OPTIONAL)' : 'CUSTOMER NAME (OPTIONAL)',
                style: TextStyle(
                  color: HomeColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _customerNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: TextStyle(
                  color: HomeColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: _isOnlinePayment ? 'e.g. Maria Santos (Sender)' : 'Walk-in Customer',
                  hintStyle: TextStyle(
                    color: HomeColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                  ),
                  prefixIcon: Icon(Icons.person_outline_rounded, color: HomeColors.textMuted, size: 20),
                  filled: true,
                  fillColor: HomeColors.cardElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: HomeColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: _isOnlinePayment ? const Color(0xFF2196F3) : HomeColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Online Payment Specific Section (Store QR & Reference Number)
              if (_isOnlinePayment) ...[
                _buildStoreQrActionCard(context),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REFERENCE NUMBER (SENDER REF #)',
                      style: TextStyle(
                        color: HomeColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      'GCash / Maya',
                      style: TextStyle(
                        color: const Color(0xFF2196F3),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _referenceController,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    color: HomeColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. 1029 3847 5612',
                    hintStyle: TextStyle(
                      color: HomeColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                    ),
                    prefixIcon: const Icon(Icons.receipt_rounded, color: Color(0xFF2196F3), size: 20),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Color(0xFF2196F3)),
                          tooltip: 'Scan QR / Barcode',
                          onPressed: () async {
                            final scanned = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                            );
                            if (scanned != null && scanned.trim().isNotEmpty && mounted) {
                              setState(() => _referenceController.text = scanned.trim());
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.content_paste_rounded, size: 18),
                          tooltip: 'Paste Reference Number',
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text != null && mounted) {
                              setState(() => _referenceController.text = data!.text!.trim());
                            }
                          },
                        ),
                      ],
                    ),
                    filled: true,
                    fillColor: HomeColors.cardElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: HomeColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined, color: Color(0xFF2196F3), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Payment will be recorded as settled via online transfer (₱${total.toStringAsFixed(2)}).',
                          style: TextStyle(
                            color: HomeColors.textPrimary,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Cash Payment Specific Section (Tendered, Shortcuts, Sukli)
              if (!_isOnlinePayment) ...[
                // Cash Tendered Label & Input
                Text(
                  'CASH TENDERED',
                  style: TextStyle(
                    color: HomeColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _confirmPayment(),
                  onChanged: _onTenderedChanged,
                  autofocus: false,
                  style: TextStyle(
                    color: HomeColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    prefixText: '₱ ',
                    prefixStyle: TextStyle(
                      color: HomeColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: HomeColors.textMuted, size: 18),
                            onPressed: () {
                              _controller.clear();
                              _onTenderedChanged('0');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: HomeColors.cardElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: HomeColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: HomeColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Quick Denomination Shortcuts
                Text(
                  'QUICK CASH SHORTCUTS',
                  style: TextStyle(
                    color: HomeColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickOptions.map((opt) {
                    final isExact = (opt - total).abs() < 0.001;
                    final isSelected = (_tendered - opt).abs() < 0.001;
                    final label = isExact ? 'Exact (₱${opt.toStringAsFixed(2)})' : '₱${opt.toStringAsFixed(0)}';

                    return InkWell(
                      onTap: () => _selectAmount(opt),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? HomeColors.primary
                              : (isExact
                                  ? HomeColors.primary.withValues(alpha: 0.15)
                                  : HomeColors.cardElevated),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? HomeColors.primary
                                : (isExact
                                    ? HomeColors.primary.withValues(alpha: 0.5)
                                    : HomeColors.cardBorder),
                            width: isSelected || isExact ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isExact ? HomeColors.primary : HomeColors.textPrimary),
                            fontWeight: isSelected || isExact ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Change (Sukli) or Lacking Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSufficient ? HomeColors.successBg : HomeColors.dangerBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSufficient
                          ? HomeColors.successText.withValues(alpha: 0.5)
                          : HomeColors.dangerText.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSufficient ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                            color: isSufficient ? HomeColors.successText : HomeColors.dangerText,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isSufficient ? 'CHANGE (SUKLI)' : 'AMOUNT LACKING',
                            style: TextStyle(
                              color: isSufficient ? HomeColors.successText : HomeColors.dangerText,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isSufficient
                            ? '₱${change.toStringAsFixed(2)}'
                            : '-₱${(-change).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isSufficient ? HomeColors.successText : HomeColors.dangerText,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Sale / Receipt Note (Optional)
              Text(
                'SALE / RECEIPT NOTE (OPTIONAL)',
                style: TextStyle(
                  color: HomeColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                minLines: 1,
                textInputAction: TextInputAction.done,
                style: TextStyle(color: HomeColors.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'e.g. Senior discount, Wholesale, Suki promo, Cash out fee ₱10',
                  hintStyle: TextStyle(
                    color: HomeColors.textMuted,
                    fontSize: 12,
                  ),
                  prefixIcon: Icon(Icons.receipt_long_rounded, color: HomeColors.textMuted, size: 20),
                  filled: true,
                  fillColor: HomeColors.cardElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: HomeColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: _isOnlinePayment ? const Color(0xFF2196F3) : HomeColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Preset Note Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'Senior Discount',
                    'Employee Purchase',
                    'Wholesale',
                    'Cash Out',
                    'GCash Send',
                    'Maya Transfer',
                  ].map((preset) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(
                          preset,
                          style: TextStyle(
                            color: HomeColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: HomeColors.cardElevated,
                        side: BorderSide(color: HomeColors.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          final current = _notesController.text.trim();
                          if (current.isEmpty) {
                            _notesController.text = preset;
                          } else if (!current.contains(preset)) {
                            _notesController.text = '$current • $preset';
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Complete Sale Button
              ElevatedButton(
                key: const Key('confirm_payment_button'),
                onPressed: _isOnlinePayment
                    ? _confirmPayment
                    : (isSufficient ? _confirmPayment : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOnlinePayment ? const Color(0xFF2196F3) : HomeColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: HomeColors.cardBorder,
                  disabledForegroundColor: HomeColors.textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: (_isOnlinePayment || isSufficient) ? 2 : 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isOnlinePayment ? Icons.check_circle_rounded : Icons.receipt_long_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOnlinePayment
                          ? 'Complete Online Sale'
                          : (isSufficient ? 'Complete Sale & Receipt' : 'Enter Sufficient Cash'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isOnlinePayment) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _chargeToUtang,
                  icon: const Icon(Icons.menu_book_rounded, size: 18, color: Colors.amber),
                  label: const Text(
                    'Charge to Utang / Credit (Listahan)',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.amber.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
