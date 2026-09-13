import 'package:flutter/material.dart';
import '../data/api/api_client.dart';
import '../home/theme/home_colors.dart';
import '../home/utils/date_utils.dart';
import '../stora_login/stora_login.dart';
import 'subscription_receipt_modal.dart';

class PastReceiptsSheet extends StatefulWidget {
  const PastReceiptsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: HomeColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const PastReceiptsSheet(),
    );
  }

  @override
  State<PastReceiptsSheet> createState() => _PastReceiptsSheetState();
}

class _PastReceiptsSheetState extends State<PastReceiptsSheet> {
  bool _loading = true;
  String? _error;
  List<dynamic> _receipts = [];

  @override
  void initState() {
    super.initState();
    _fetchReceipts();
  }

  Future<void> _fetchReceipts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiClient.instance.getSubscriptionReceipts();
      if (mounted) {
        setState(() {
          _receipts = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('ApiException: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.fieldBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.6), width: 1.2),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF34D399), size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Past Subscription Receipts',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Only approved subscriptions generate official receipts',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _fetchReceipts,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFFC084FC)),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.fieldBorder, height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.purpleLight),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchReceipts,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purpleLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_receipts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF9333EA).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.5), width: 1.4),
                ),
                child: const Icon(Icons.receipt_long_outlined, color: Color(0xFFC084FC), size: 44),
              ),
              const SizedBox(height: 14),
              const Text(
                'No Past Subscription Receipts',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Receipts are generated after your GCash payment proof is reviewed and accepted by the admin. Unverified or pending proofs will not show receipts in advance.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _receipts.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _receipts[index] as Map<String, dynamic>;
        final ref = (item['reference_number'] as String?) ?? 'N/A';
        final rawAmount = item['amount'];
        final amountNum = rawAmount is num
            ? rawAmount.toDouble()
            : double.tryParse(rawAmount?.toString() ?? '100.0') ?? 100.0;
        final dateStr = (item['reviewed_at'] ?? item['submitted_at']) as String?;
        final date = dateStr != null ? (DateTime.tryParse(dateStr) ?? DateTime.now()) : DateTime.now();

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            SubscriptionReceiptModal.show(
              context,
              amount: amountNum,
              referenceNumber: ref,
              date: date,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F172E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.35), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA855F7).withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.5), width: 1),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stora Premium (Monthly)',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Ref: $ref',
                        style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatManilaShortDateTime(date),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PHP ${amountNum.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.6), width: 0.8),
                      ),
                      child: const Text(
                        'APPROVED',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFC084FC), size: 22),
              ],
            ),
          ),
        );
      },
    );
  }
}
