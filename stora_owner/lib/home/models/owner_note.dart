import 'package:flutter/material.dart';

/// Represents an owner's personal note, reminder, or store memo.
class OwnerNote {
  final String id;
  final String title;
  final String content;
  final String category; // 'General', 'Reminder', 'Restock', 'To-Do', 'Payment'
  final bool isPinned;
  final bool isCompleted;
  final DateTime? reminderDateTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OwnerNote({
    required this.id,
    required this.title,
    this.content = '',
    this.category = 'General',
    this.isPinned = false,
    this.isCompleted = false,
    this.reminderDateTime,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasReminder => reminderDateTime != null;

  /// Returns true if the reminder is set and its scheduled time is past or now, and note is not completed.
  bool get isReminderDue {
    if (reminderDateTime == null || isCompleted) return false;
    return DateTime.now().isAfter(reminderDateTime!);
  }

  /// Returns true if the reminder is scheduled for today.
  bool get isReminderToday {
    if (reminderDateTime == null) return false;
    final now = DateTime.now();
    final r = reminderDateTime!;
    return r.year == now.year && r.month == now.month && r.day == now.day;
  }

  /// Returns true if the reminder is in the future.
  bool get isUpcomingReminder {
    if (reminderDateTime == null || isCompleted) return false;
    return reminderDateTime!.isAfter(DateTime.now());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'category': category,
        'is_pinned': isPinned,
        'is_completed': isCompleted,
        'reminder_date_time': reminderDateTime?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory OwnerNote.fromJson(Map<String, dynamic> json) {
    return OwnerNote(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Untitled Note',
      content: json['content'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      isPinned: json['is_pinned'] as bool? ?? false,
      isCompleted: json['is_completed'] as bool? ?? false,
      reminderDateTime: json['reminder_date_time'] != null
          ? DateTime.tryParse(json['reminder_date_time'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  OwnerNote copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    bool? isPinned,
    bool? isCompleted,
    DateTime? reminderDateTime,
    bool clearReminder = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OwnerNote(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      isCompleted: isCompleted ?? this.isCompleted,
      reminderDateTime: clearReminder
          ? null
          : (reminderDateTime ?? this.reminderDateTime),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Color accent associated with category
  Color get categoryColor {
    switch (category.toLowerCase()) {
      case 'reminder':
        return const Color(0xFFF59E0B); // Amber
      case 'restock':
        return const Color(0xFF10B981); // Emerald
      case 'to-do':
      case 'todo':
        return const Color(0xFF6366F1); // Indigo
      case 'payment':
        return const Color(0xFFEC4899); // Pink
      default:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'reminder':
        return Icons.notifications_active_rounded;
      case 'restock':
        return Icons.inventory_2_rounded;
      case 'to-do':
      case 'todo':
        return Icons.check_circle_outline_rounded;
      case 'payment':
        return Icons.payments_rounded;
      default:
        return Icons.note_alt_rounded;
    }
  }
}
