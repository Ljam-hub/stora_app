import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/home_colors.dart';

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
  double _tendered = 0.0;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    // Default to exact amount for quick 1-tap checkout
    _tendered = widget.totalAmount;
    _controller = TextEditingController(
      text: widget.totalAmount.toStringAsFixed(2),
    );
    _customerNameController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _customerNameController.dispose();
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

  void _confirmPayment() {
    if (_isSubmitted) return;
    final change = _tendered - widget.totalAmount;
    if (change < -0.001) return;
    _isSubmitted = true;

    final name = _customerNameController.text.trim();
    Navigator.of(context).pop(
      CashPaymentResult(
        tendered: _tendered,
        change: change < 0 ? 0.0 : change,
        customerName: name.isNotEmpty ? name : 'Walk-in Customer',
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
                          color: HomeColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          color: HomeColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Cash Payment',
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
              const SizedBox(height: 16),

              // Total Due Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: HomeColors.cardElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HomeColors.cardBorder),
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
                        color: HomeColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Customer Name Label & Input (Optional)
              Text(
                'CUSTOMER NAME (OPTIONAL)',
                style: TextStyle(
                  color: HomeColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customerNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: TextStyle(
                  color: HomeColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Walk-in Customer',
                  hintStyle: TextStyle(
                    color: HomeColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                  prefixIcon: Icon(Icons.person_outline_rounded, color: HomeColors.textMuted, size: 20),
                  filled: true,
                  fillColor: HomeColors.cardElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: HomeColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: HomeColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
              const SizedBox(height: 20),

              // Complete Sale Button
              ElevatedButton(
                key: const Key('confirm_payment_button'),
                onPressed: isSufficient ? _confirmPayment : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: HomeColors.cardBorder,
                  disabledForegroundColor: HomeColors.textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: isSufficient ? 2 : 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isSufficient ? 'Complete Sale & Receipt' : 'Enter Sufficient Cash',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
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
          ),
        ),
      ),
    );
  }
}
