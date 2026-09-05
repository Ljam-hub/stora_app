import 'package:flutter/material.dart';
import '../../stora_login/stora_login.dart';
import '../stores/category_store.dart';
import '../theme/home_colors.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const CategoryChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? HomeColors.purpleGradient : null,
          color: selected ? null : HomeColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : HomeColors.cardBorder,
            width: 1,
          ),
          boxShadow: selected ? HomeColors.glowShadow(AppColors.purple, opacity: 0.35) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black87 : AppColors.label,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Shared category filter strip used by both Inventory and Sales.
///
/// Uses `Wrap` instead of a fixed-height horizontal `ListView` so it has
/// no hard-coded height to overflow — chips just wrap onto a new line if
/// they don't fit, which behaves the same whether the screen is a narrow
/// phone or a wide browser window. A small "manage" (tune) icon opens a
/// dialog where categories can be hidden from this row or deleted
/// outright; both live off the same `CategoryStore`, so a change made
/// from Inventory is instantly reflected in Sales and vice versa.
class CategoryFilterRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final bool showManageButton;
  const CategoryFilterRow({
    super.key,
    required this.selected,
    required this.onSelect,
    this.showManageButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CategoryStore.instance,
      builder: (context, _) {
        final chips = ['All', ...CategoryStore.instance.visibleCategories];
        // If the category currently selected just got hidden or deleted
        // (possibly from the *other* screen's manage dialog), fall back
        // to "All" instead of leaving a dead filter selected.
        if (!chips.contains(selected)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!chips.contains(selected)) onSelect('All');
          });
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...chips.map((cat) => CategoryChip(
                    label: cat,
                    selected: cat == selected,
                    onTap: () => onSelect(cat),
                  )),
              if (showManageButton)
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) => const ManageCategoriesDialog(),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: HomeColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.fieldBorder),
                    ),
                    child: const Icon(Icons.tune_rounded, size: 16, color: AppColors.label),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ManageCategoriesDialog extends StatelessWidget {
  const ManageCategoriesDialog({super.key});

  void _confirmDelete(BuildContext context, String cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        title: const Text('Delete category?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Products already using "$cat" will keep it, but it won\'t be selectable for new products.',
          style: const TextStyle(color: AppColors.label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
          ),
          TextButton(
            onPressed: () {
              CategoryStore.instance.removeCategory(cat);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CategoryStore.instance,
      builder: (context, _) {
        final store = CategoryStore.instance;
        return AlertDialog(
          backgroundColor: HomeColors.cardBackground,
          title: const Text('Manage categories', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: store.categories.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No categories yet', style: TextStyle(color: AppColors.label)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: store.categories.length,
                      separatorBuilder: (_, _) => const Divider(color: AppColors.fieldBorder, height: 1),
                      itemBuilder: (context, i) {
                        final cat = store.categories[i];
                        final hidden = store.isHidden(cat);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    color: hidden ? AppColors.label : Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: hidden ? 'Unhide' : 'Hide',
                                onPressed: () => store.toggleHidden(cat),
                                icon: Icon(
                                  hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: AppColors.label,
                                  size: 20,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _confirmDelete(context, cat),
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done', style: TextStyle(color: AppColors.purpleLight)),
            ),
          ],
        );
      },
    );
  }
}
