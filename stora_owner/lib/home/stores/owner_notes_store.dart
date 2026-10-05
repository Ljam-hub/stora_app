import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/services/notification_service.dart';
import '../models/owner_note.dart';

class OwnerNotesStore extends ChangeNotifier {
  OwnerNotesStore._internal() {
    load();
  }

  static final OwnerNotesStore instance = OwnerNotesStore._internal();

  List<OwnerNote> _notes = [];
  bool _initialized = false;
  bool get isInitialized => _initialized;

  List<OwnerNote> get notes => List.unmodifiable(_notes);

  List<OwnerNote> get activeNotes =>
      _notes.where((n) => !n.isCompleted).toList();

  List<OwnerNote> get completedNotes =>
      _notes.where((n) => n.isCompleted).toList();

  List<OwnerNote> get pinnedNotes =>
      _notes.where((n) => !n.isCompleted && n.isPinned).toList();

  List<OwnerNote> get reminderNotes =>
      _notes.where((n) => !n.isCompleted && n.hasReminder).toList();

  List<OwnerNote> get remindersToday =>
      _notes.where((n) => !n.isCompleted && n.isReminderToday).toList();

  List<OwnerNote> get remindersOverdue =>
      _notes.where((n) => !n.isCompleted && n.isReminderDue).toList();

  int get activeCount => activeNotes.length;
  int get completedCount => completedNotes.length;
  int get remindersTodayCount => remindersToday.length;

  @visibleForTesting
  void setNotesForTesting(List<OwnerNote> notesList) {
    _notes = List.from(notesList);
    _sortNotes();
    notifyListeners();
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/stora_owner_notes.json');
  }

  void _sortNotes() {
    _notes.sort((a, b) {
      // 1. Completed notes go to the bottom
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      // 2. Pinned active notes go first
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      // 3. Notes with due/overdue reminders
      if (a.isReminderDue != b.isReminderDue) {
        return a.isReminderDue ? -1 : 1;
      }
      // 4. Notes with reminder today
      if (a.isReminderToday != b.isReminderToday) {
        return a.isReminderToday ? -1 : 1;
      }
      // 5. By created date descending
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Future<void> load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final list = jsonDecode(content) as List<dynamic>;
          _notes = list
              .map((e) => OwnerNote.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _sortNotes();
        }
      }
    } catch (e) {
      debugPrint('OwnerNotesStore load error: $e');
    } finally {
      _initialized = true;
      notifyListeners();
      _checkAndNotifyDueReminders();
    }
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      final data = jsonEncode(_notes.map((n) => n.toJson()).toList());
      await file.writeAsString(data);
    } catch (e) {
      debugPrint('OwnerNotesStore save error: $e');
    }
  }

  Future<void> _checkAndNotifyDueReminders() async {
    final overdue = remindersOverdue;
    if (overdue.isEmpty) return;

    for (final note in overdue) {
      // Schedule or refresh notifications
      OwnerNotificationService.instance.scheduleNoteReminder(
        noteId: note.id,
        title: note.title,
        content: note.content,
        reminderDateTime: note.reminderDateTime!,
      );
    }
  }

  Future<OwnerNote> addNote({
    required String title,
    String content = '',
    String category = 'General',
    bool isPinned = false,
    DateTime? reminderDateTime,
  }) async {
    final now = DateTime.now();
    final note = OwnerNote(
      id: 'note_${now.millisecondsSinceEpoch}',
      title: title.trim(),
      content: content.trim(),
      category: category,
      isPinned: isPinned,
      isCompleted: false,
      reminderDateTime: reminderDateTime,
      createdAt: now,
      updatedAt: now,
    );

    _notes.add(note);
    _sortNotes();
    notifyListeners();
    await _save();

    if (reminderDateTime != null) {
      await OwnerNotificationService.instance.scheduleNoteReminder(
        noteId: note.id,
        title: note.title,
        content: note.content,
        reminderDateTime: reminderDateTime,
      );
    }

    return note;
  }

  Future<void> updateNote(OwnerNote updated) async {
    final index = _notes.indexWhere((n) => n.id == updated.id);
    if (index == -1) return;

    final existing = _notes[index];
    final modified = updated.copyWith(updatedAt: DateTime.now());
    _notes[index] = modified;
    _sortNotes();
    notifyListeners();
    await _save();

    // Reschedule or cancel notification
    if (modified.isCompleted || modified.reminderDateTime == null) {
      await OwnerNotificationService.instance.cancelNoteReminder(modified.id);
    } else if (existing.reminderDateTime != modified.reminderDateTime ||
        existing.title != modified.title) {
      await OwnerNotificationService.instance.scheduleNoteReminder(
        noteId: modified.id,
        title: modified.title,
        content: modified.content,
        reminderDateTime: modified.reminderDateTime!,
      );
    }
  }

  Future<void> toggleComplete(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final existing = _notes[index];
    final updated = existing.copyWith(
      isCompleted: !existing.isCompleted,
      updatedAt: DateTime.now(),
    );
    _notes[index] = updated;
    _sortNotes();
    notifyListeners();
    await _save();

    if (updated.isCompleted) {
      await OwnerNotificationService.instance.cancelNoteReminder(updated.id);
    } else if (updated.reminderDateTime != null && updated.isUpcomingReminder) {
      await OwnerNotificationService.instance.scheduleNoteReminder(
        noteId: updated.id,
        title: updated.title,
        content: updated.content,
        reminderDateTime: updated.reminderDateTime!,
      );
    }
  }

  Future<void> togglePin(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final existing = _notes[index];
    final updated = existing.copyWith(
      isPinned: !existing.isPinned,
      updatedAt: DateTime.now(),
    );
    _notes[index] = updated;
    _sortNotes();
    notifyListeners();
    await _save();
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
    await _save();
    await OwnerNotificationService.instance.cancelNoteReminder(id);
  }
}
