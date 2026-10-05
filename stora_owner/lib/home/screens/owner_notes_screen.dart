import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../stora_login/theme/app_colors.dart';
import '../models/owner_note.dart';
import '../stores/owner_notes_store.dart';
import '../theme/home_colors.dart';

class OwnerNotesScreen extends StatefulWidget {
  const OwnerNotesScreen({super.key});

  static void showAddEditNoteSheet(BuildContext context, {OwnerNote? noteToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditNoteSheet(note: noteToEdit),
    );
  }

  @override
  State<OwnerNotesScreen> createState() => _OwnerNotesScreenState();
}

class _OwnerNotesScreenState extends State<OwnerNotesScreen> {
  String _selectedFilter = 'All'; // 'All', 'Active', 'Reminders', 'Pinned', 'Completed'
  String _selectedCategory = 'All'; // 'All', 'General', 'Reminder', 'Restock', 'To-Do', 'Payment'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OwnerNote> _getFilteredNotes(List<OwnerNote> notes) {
    return notes.where((note) {
      // 1. Tab filter
      if (_selectedFilter == 'Active' && note.isCompleted) return false;
      if (_selectedFilter == 'Completed' && !note.isCompleted) return false;
      if (_selectedFilter == 'Reminders' && (!note.hasReminder || note.isCompleted)) return false;
      if (_selectedFilter == 'Pinned' && (!note.isPinned || note.isCompleted)) return false;

      // 2. Category filter
      if (_selectedCategory != 'All' &&
          note.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }

      // 3. Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = note.title.toLowerCase().contains(q);
        final matchesContent = note.content.toLowerCase().contains(q);
        final matchesCategory = note.category.toLowerCase().contains(q);
        if (!matchesTitle && !matchesContent && !matchesCategory) return false;
      }

      return true;
    }).toList();
  }

  void _showAddOrEditNoteSheet({OwnerNote? noteToEdit}) {
    OwnerNotesScreen.showAddEditNoteSheet(context, noteToEdit: noteToEdit);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: OwnerNotesStore.instance,
      builder: (context, _) {
        final store = OwnerNotesStore.instance;
        final filteredNotes = _getFilteredNotes(store.notes);

        return Scaffold(
          backgroundColor: HomeColors.background,
          appBar: AppBar(
            backgroundColor: HomeColors.cardBackground,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: HomeColors.textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: HomeColors.purpleGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sticky_note_2_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Owner Notes & Reminders',
                  style: TextStyle(
                    color: HomeColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Add Note',
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.purpleLight, size: 24),
                onPressed: () => _showAddOrEditNoteSheet(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddOrEditNoteSheet(),
            backgroundColor: AppColors.purple,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'New Note',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          body: Column(
            children: [
              // Search Bar
              Container(
                color: HomeColors.cardBackground,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: HomeColors.textPrimary, fontSize: 13.5),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search notes, reminders, memos...',
                    hintStyle: TextStyle(color: HomeColors.textMuted, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: HomeColors.textMuted, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: HomeColors.textMuted, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: HomeColors.cardElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: HomeColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: HomeColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.purpleLight, width: 1.5),
                    ),
                  ),
                ),
              ),

              // Filter Tabs Row
              Container(
                color: HomeColors.cardBackground,
                padding: const EdgeInsets.only(bottom: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterTab('All', store.notes.length),
                      _buildFilterTab('Active', store.activeNotes.length),
                      _buildFilterTab(
                        'Reminders',
                        store.reminderNotes.length,
                        icon: Icons.notifications_active_rounded,
                        badgeColor: const Color(0xFFF59E0B),
                      ),
                      _buildFilterTab('Pinned', store.pinnedNotes.length, icon: Icons.push_pin_rounded),
                      _buildFilterTab('Completed', store.completedNotes.length, icon: Icons.check_circle_rounded),
                    ],
                  ),
                ),
              ),

              // Category Selector Chips
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      'All',
                      'Reminder',
                      'Restock',
                      'To-Do',
                      'Payment',
                      'General',
                    ].map((cat) {
                      final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : HomeColors.textSecondary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.purple,
                        backgroundColor: HomeColors.cardBackground,
                        side: BorderSide(
                          color: isSelected ? AppColors.purple : HomeColors.cardBorder,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedCategory = cat);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const Divider(height: 1),

            // Note List
            Expanded(
              child: filteredNotes.isEmpty
                  ? _buildEmptyState(store.notes.isEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                      itemCount: filteredNotes.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final note = filteredNotes[index];
                        return _NoteCard(
                          note: note,
                          onToggleComplete: () {
                            HapticFeedback.lightImpact();
                            store.toggleComplete(note.id);
                          },
                          onTogglePin: () {
                            HapticFeedback.selectionClick();
                            store.togglePin(note.id);
                          },
                          onTap: () => _showAddOrEditNoteSheet(noteToEdit: note),
                          onDelete: () => _confirmDelete(note),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
    );
  }

  Widget _buildFilterTab(String label, int count, {IconData? icon, Color? badgeColor}) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _selectedFilter = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.purple.withValues(alpha: 0.15)
                : HomeColors.cardElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.purpleLight : HomeColors.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? AppColors.purpleLight : HomeColors.textMuted,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.purpleLight : HomeColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor != null
                      ? badgeColor.withValues(alpha: 0.2)
                      : (isSelected ? AppColors.purple : HomeColors.cardBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: badgeColor ?? (isSelected ? Colors.white : HomeColors.textSecondary),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isCompletelyEmpty) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sticky_note_2_outlined, color: AppColors.purpleLight, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              isCompletelyEmpty ? 'No Notes Yet' : 'No Matching Notes',
              style: TextStyle(
                color: HomeColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCompletelyEmpty
                  ? 'Keep track of store reminders, restock memos, supplier visits, and daily to-dos in one place.'
                  : 'Try adjusting your search query or filter criteria.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HomeColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (isCompletelyEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _showAddOrEditNoteSheet(),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: const Text('Create First Note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(OwnerNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Note?',
          style: TextStyle(color: HomeColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete "${note.title}"? This cannot be undone.',
          style: TextStyle(color: HomeColors.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              OwnerNotesStore.instance.deleteNote(note.id);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final OwnerNote note;
  final VoidCallback onToggleComplete;
  final VoidCallback onTogglePin;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onToggleComplete,
    required this.onTogglePin,
    required this.onTap,
    required this.onDelete,
  });

  String _formatReminder(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDay = DateTime(dt.year, dt.month, dt.day);
    final timeStr = DateFormat('h:mm a').format(dt);

    if (reminderDay == today) {
      return 'Today at $timeStr';
    } else if (reminderDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow at $timeStr';
    } else {
      return '${DateFormat('MMM d').format(dt)} at $timeStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDue = note.isReminderDue;
    final isToday = note.isReminderToday;

    Color reminderColor = AppColors.purpleLight;
    if (isDue) {
      reminderColor = AppColors.error;
    } else if (isToday) {
      reminderColor = const Color(0xFFF59E0B);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HomeColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: note.isPinned
                ? AppColors.purpleLight.withValues(alpha: 0.6)
                : HomeColors.cardBorder,
            width: note.isPinned ? 1.5 : 1,
          ),
          boxShadow: note.isPinned
              ? [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: InkWell(
                onTap: onToggleComplete,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: note.isCompleted ? AppColors.purple : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: note.isCompleted ? AppColors.purple : HomeColors.textMuted,
                      width: 1.8,
                    ),
                  ),
                  child: note.isCompleted
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Main Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (note.isPinned) ...[
                        Icon(Icons.push_pin_rounded, color: AppColors.purpleLight, size: 14),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          note.title,
                          style: TextStyle(
                            color: note.isCompleted
                                ? HomeColors.textMuted
                                : HomeColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            decoration: note.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: note.isCompleted ? HomeColors.textMuted : HomeColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Metadata Badges (Category & Reminder)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: note.categoryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: note.categoryColor.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(note.categoryIcon, size: 11, color: note.categoryColor),
                            const SizedBox(width: 4),
                            Text(
                              note.category,
                              style: TextStyle(
                                color: note.categoryColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Reminder Badge
                      if (note.reminderDateTime != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: reminderColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: reminderColor.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDue ? Icons.alarm_on_rounded : Icons.alarm_rounded,
                                size: 11,
                                color: reminderColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isDue
                                    ? 'Overdue: ${_formatReminder(note.reminderDateTime!)}'
                                    : _formatReminder(note.reminderDateTime!),
                                style: TextStyle(
                                  color: reminderColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions (Pin and Delete Menu)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: HomeColors.textMuted, size: 18),
              color: HomeColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'pin') onTogglePin();
                if (val == 'edit') onTap();
                if (val == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(
                        note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                        size: 16,
                        color: HomeColors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        note.isPinned ? 'Unpin' : 'Pin to top',
                        style: TextStyle(color: HomeColors.textPrimary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16, color: HomeColors.textPrimary),
                      const SizedBox(width: 8),
                      Text('Edit', style: TextStyle(color: HomeColors.textPrimary, fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: const Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppColors.error, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddEditNoteSheet extends StatefulWidget {
  final OwnerNote? note;
  const AddEditNoteSheet({super.key, this.note});

  @override
  State<AddEditNoteSheet> createState() => _AddEditNoteSheetState();
}

class _AddEditNoteSheetState extends State<AddEditNoteSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late String _category;
  late bool _isPinned;
  DateTime? _reminderDateTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _category = widget.note?.category ?? 'General';
    _isPinned = widget.note?.isPinned ?? false;
    _reminderDateTime = widget.note?.reminderDateTime;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomReminder() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _reminderDateTime ?? now.add(const Duration(hours: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _reminderDateTime != null
          ? TimeOfDay(hour: _reminderDateTime!.hour, minute: _reminderDateTime!.minute)
          : TimeOfDay(hour: now.hour + 1, minute: 0),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _reminderDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a note title')),
      );
      return;
    }

    if (widget.note != null) {
      OwnerNotesStore.instance.updateNote(
        widget.note!.copyWith(
          title: title,
          content: _contentController.text.trim(),
          category: _category,
          isPinned: _isPinned,
          reminderDateTime: _reminderDateTime,
          clearReminder: _reminderDateTime == null,
        ),
      );
    } else {
      OwnerNotesStore.instance.addNote(
        title: title,
        content: _contentController.text.trim(),
        category: _category,
        isPinned: _isPinned,
        reminderDateTime: _reminderDateTime,
      );
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null;
    final now = DateTime.now();

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                  color: HomeColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_note_rounded : Icons.note_add_rounded,
                  color: AppColors.purpleLight,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Edit Note / Reminder' : 'New Note / Reminder',
                  style: TextStyle(
                    color: HomeColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: HomeColors.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Title Field
            TextField(
              controller: _titleController,
              autofocus: !isEditing,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: HomeColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Note title (e.g. Restock Eggs, Supplier visit)',
                hintStyle: TextStyle(color: HomeColors.textMuted, fontSize: 14, fontWeight: FontWeight.normal),
                filled: true,
                fillColor: HomeColors.cardElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: HomeColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.purpleLight, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Content Field
            TextField(
              controller: _contentController,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: HomeColors.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Details or memos (optional)...',
                hintStyle: TextStyle(color: HomeColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: HomeColors.cardElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: HomeColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.purpleLight, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Category Selector
            Text(
              'CATEGORY',
              style: TextStyle(color: HomeColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'Reminder',
                  'Restock',
                  'To-Do',
                  'Payment',
                  'General',
                ].map((cat) {
                  final isSelected = _category.toLowerCase() == cat.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : HomeColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.purple,
                      backgroundColor: HomeColors.cardElevated,
                      side: BorderSide(color: isSelected ? AppColors.purple : HomeColors.cardBorder),
                      onSelected: (val) {
                        if (val) setState(() => _category = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Reminder Scheduler Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HomeColors.cardElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _reminderDateTime != null
                      ? AppColors.purpleLight.withValues(alpha: 0.5)
                      : HomeColors.cardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.alarm_rounded,
                        color: _reminderDateTime != null ? const Color(0xFFF59E0B) : HomeColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _reminderDateTime != null
                              ? 'Reminder: ${DateFormat('EEE, MMM d • h:mm a').format(_reminderDateTime!)}'
                              : 'Set Reminder',
                          style: TextStyle(
                            color: _reminderDateTime != null ? HomeColors.textPrimary : HomeColors.textSecondary,
                            fontSize: 13,
                            fontWeight: _reminderDateTime != null ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_reminderDateTime != null)
                        IconButton(
                          tooltip: 'Clear Reminder',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.cancel_rounded, color: HomeColors.textMuted, size: 18),
                          onPressed: () => setState(() => _reminderDateTime = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Quick Preset Buttons
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('Later Today (5 PM)', style: TextStyle(fontSize: 11)),
                        backgroundColor: HomeColors.cardBackground,
                        side: BorderSide(color: HomeColors.cardBorder),
                        onPressed: () {
                          final today5pm = DateTime(now.year, now.month, now.day, 17, 0);
                          setState(() {
                            _reminderDateTime = today5pm.isAfter(now)
                                ? today5pm
                                : now.add(const Duration(hours: 2));
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('Tomorrow (9 AM)', style: TextStyle(fontSize: 11)),
                        backgroundColor: HomeColors.cardBackground,
                        side: BorderSide(color: HomeColors.cardBorder),
                        onPressed: () {
                          final tomorrow9am = DateTime(now.year, now.month, now.day + 1, 9, 0);
                          setState(() => _reminderDateTime = tomorrow9am);
                        },
                      ),
                      ActionChip(
                        label: const Text('In 2 Days', style: TextStyle(fontSize: 11)),
                        backgroundColor: HomeColors.cardBackground,
                        side: BorderSide(color: HomeColors.cardBorder),
                        onPressed: () {
                          final in2Days = DateTime(now.year, now.month, now.day + 2, 9, 0);
                          setState(() => _reminderDateTime = in2Days);
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_today_rounded, size: 12),
                        label: const Text('Custom...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        backgroundColor: HomeColors.cardBackground,
                        side: BorderSide(color: AppColors.purpleLight.withValues(alpha: 0.5)),
                        onPressed: _pickCustomReminder,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Pin to top toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Pin to top of Home', style: TextStyle(color: HomeColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Text('Keep this note prominently visible on dashboard', style: TextStyle(color: HomeColors.textSecondary, fontSize: 11.5)),
              value: _isPinned,
              activeTrackColor: AppColors.purpleLight,
              activeThumbColor: Colors.white,
              onChanged: (val) => setState(() => _isPinned = val),
            ),
            const SizedBox(height: 16),

            // Save Button
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                isEditing ? 'Save Changes' : 'Create Note',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
