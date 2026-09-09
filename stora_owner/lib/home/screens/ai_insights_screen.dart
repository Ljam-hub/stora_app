import 'package:flutter/material.dart';
import '../../data/api/api_client.dart';
import '../../stora_login/stora_login.dart';
import '../theme/home_colors.dart';
import 'inventory_list_screen.dart';
import 'pending_orders_screen.dart';

import 'sales_analytics_screen.dart';
import 'set_store_location_screen.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _insights = [];

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiClient.instance.fetchAiInsights();
      if (mounted) {
        setState(() {
          _insights = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('ApiException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _handleAction(String target) {
    switch (target) {
      case 'inventory':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InventoryListScreen()),
        );
        break;
      case 'orders':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PendingOrdersScreen()),
        );
        break;
      case 'analytics':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SalesAnalyticsScreen()),
        );
        break;
      case 'map':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SetStoreLocationScreen()),
        );
        break;
      default:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InventoryListScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppColors.purpleLight, size: 20),
            SizedBox(width: 8),
            Text(
              'AI Store Insights',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.label),
            onPressed: _loadInsights,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.purpleLight))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadInsights,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _insights.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: HomeColors.cardElevated,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle_outline_rounded,
                                  color: HomeColors.successText, size: 48),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Everything looks great!',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No critical stock alerts or issues detected right now. Keep recording sales to receive deeper AI recommendations.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.label, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.purpleLight,
                      backgroundColor: HomeColors.cardBackground,
                      onRefresh: _loadInsights,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                        children: [
                          // Header banner matching Stitch AI Insights Screen
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: HomeColors.heroGradient,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                              boxShadow: HomeColors.glowShadow(AppColors.purple, opacity: 0.2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Smart Store Assistant',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Actionable suggestions computed from your store orders and inventory.',
                                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'RECOMMENDATIONS',
                            style: TextStyle(
                              color: AppColors.label,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._insights.map((item) => _InsightCard(
                                insight: item,
                                onAction: () => _handleAction(item['action_target']?.toString() ?? ''),
                              )),
                        ],
                      ),
                    ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Map<String, dynamic> insight;
  final VoidCallback onAction;

  const _InsightCard({required this.insight, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final priority = (insight['priority'] as String?)?.toLowerCase() ?? 'medium';
    final category = (insight['category'] as String?)?.toLowerCase() ?? 'inventory';
    final title = insight['title'] as String? ?? 'Insight';
    final description = insight['description'] as String? ?? '';
    final actionLabel = insight['action_label'] as String? ?? 'Take Action';

    Color priorityColor;
    Color priorityBg;
    switch (priority) {
      case 'high':
        priorityColor = AppColors.error;
        priorityBg = HomeColors.dangerBg;
        break;
      case 'low':
        priorityColor = HomeColors.successText;
        priorityBg = HomeColors.successBg;
        break;
      case 'medium':
      default:
        priorityColor = HomeColors.warningText;
        priorityBg = HomeColors.warningBg;
        break;
    }

    IconData catIcon;
    Color catColor;
    switch (category) {
      case 'sales':
        catIcon = Icons.trending_up_rounded;
        catColor = const Color(0xFF38BDF8);
        break;
      case 'pricing':
        catIcon = Icons.sell_rounded;
        catColor = const Color(0xFFFBBF24);
        break;
      case 'growth':
        catIcon = Icons.rocket_launch_rounded;
        catColor = const Color(0xFFA78BFA);
        break;
      case 'inventory':
      default:
        catIcon = Icons.inventory_2_rounded;
        catColor = const Color(0xFF4ADE80);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeColors.cardBorder),
        boxShadow: HomeColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(catIcon, size: 16, color: catColor),
                ),
                const SizedBox(width: 8),
                Text(
                  category.toUpperCase(),
                  style: TextStyle(
                    color: catColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: HomeColors.cardBorder),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.label,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                    label: Text(
                      actionLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
