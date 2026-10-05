import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stora/home/models/owner_note.dart';
import 'package:stora/home/screens/owner_notes_screen.dart';
import 'package:stora/home/stores/owner_notes_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OwnerNote Model Tests', () {
    test('creates and serializes/deserializes correctly', () {
      final now = DateTime.now();
      final reminder = now.add(const Duration(hours: 3));

      final note = OwnerNote(
        id: 'note-1',
        title: 'Restock Eggs',
        content: 'Get 5 trays from Mang Tony',
        category: 'Restock',
        isPinned: true,
        isCompleted: false,
        reminderDateTime: reminder,
        createdAt: now,
        updatedAt: now,
      );

      final json = note.toJson();
      final fromJson = OwnerNote.fromJson(json);

      expect(fromJson.id, equals('note-1'));
      expect(fromJson.title, equals('Restock Eggs'));
      expect(fromJson.content, equals('Get 5 trays from Mang Tony'));
      expect(fromJson.category, equals('Restock'));
      expect(fromJson.isPinned, isTrue);
      expect(fromJson.isCompleted, isFalse);
      expect(fromJson.reminderDateTime, isNotNull);
      expect(fromJson.hasReminder, isTrue);
      expect(fromJson.isUpcomingReminder, isTrue);
      expect(fromJson.categoryColor, equals(const Color(0xFF10B981)));
      expect(fromJson.categoryIcon, equals(Icons.inventory_2_rounded));
    });

    test('detects reminder status correctly', () {
      final now = DateTime.now();

      // Past reminder (due/overdue)
      final pastNote = OwnerNote(
        id: 'note-past',
        title: 'Overdue Note',
        isCompleted: false,
        reminderDateTime: now.subtract(const Duration(minutes: 30)),
        createdAt: now,
        updatedAt: now,
      );
      expect(pastNote.isReminderDue, isTrue);
      expect(pastNote.isUpcomingReminder, isFalse);

      // Completed note should not be considered reminder due
      final completedNote = pastNote.copyWith(isCompleted: true);
      expect(completedNote.isReminderDue, isFalse);

      // Future reminder today
      final futureToday = DateTime(now.year, now.month, now.day, 23, 59);
      final todayNote = OwnerNote(
        id: 'note-today',
        title: 'Due Later Today',
        isCompleted: false,
        reminderDateTime: futureToday,
        createdAt: now,
        updatedAt: now,
      );
      expect(todayNote.isReminderToday, isTrue);
    });

    test('copyWith updates fields and clearReminder works', () {
      final now = DateTime.now();
      final note = OwnerNote(
        id: 'note-1',
        title: 'Buy Milk',
        reminderDateTime: now.add(const Duration(hours: 1)),
        createdAt: now,
        updatedAt: now,
      );

      final updated = note.copyWith(
        title: 'Buy Almond Milk',
        isPinned: true,
        clearReminder: true,
      );

      expect(updated.title, equals('Buy Almond Milk'));
      expect(updated.isPinned, isTrue);
      expect(updated.reminderDateTime, isNull);
      expect(updated.hasReminder, isFalse);
    });
  });

  group('OwnerNotesStore Tests', () {
    late OwnerNotesStore store;

    setUp(() {
      store = OwnerNotesStore.instance;
    });

    test('sorting places pinned and active notes above completed notes', () {
      final now = DateTime.now();
      final regular = OwnerNote(
        id: 'note-reg',
        title: 'Regular note',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now,
      );
      final pinned = OwnerNote(
        id: 'note-pinned',
        title: 'Pinned Note',
        isPinned: true,
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now,
      );
      final completed = OwnerNote(
        id: 'note-comp',
        title: 'Completed Note',
        isCompleted: true,
        isPinned: true,
        createdAt: now,
        updatedAt: now,
      );

      store.setNotesForTesting([regular, completed, pinned]);

      expect(store.notes.first.id, equals('note-pinned'));
      expect(store.notes.last.id, equals('note-comp'));
      expect(store.activeCount, equals(2));
      expect(store.completedCount, equals(1));
      expect(store.pinnedNotes.length, equals(1));
    });

    test('toggleComplete updates completion state', () async {
      final now = DateTime.now();
      final note = OwnerNote(
        id: 'toggle-test',
        title: 'Task to finish',
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      );

      store.setNotesForTesting([note]);
      expect(store.activeCount, equals(1));

      await store.toggleComplete('toggle-test');
      expect(store.activeCount, equals(0));
      expect(store.completedCount, equals(1));

      await store.toggleComplete('toggle-test');
      expect(store.activeCount, equals(1));
      expect(store.completedCount, equals(0));
    });

    test('togglePin updates pinned state', () async {
      final now = DateTime.now();
      final note = OwnerNote(
        id: 'pin-test',
        title: 'Task to pin',
        isPinned: false,
        createdAt: now,
        updatedAt: now,
      );

      store.setNotesForTesting([note]);
      expect(store.pinnedNotes.isEmpty, isTrue);

      await store.togglePin('pin-test');
      expect(store.pinnedNotes.length, equals(1));
      expect(store.notes.first.isPinned, isTrue);
    });

    test('deleteNote removes note from store', () async {
      final now = DateTime.now();
      final note = OwnerNote(
        id: 'del-test',
        title: 'To be removed',
        createdAt: now,
        updatedAt: now,
      );

      store.setNotesForTesting([note]);
      expect(store.notes.length, equals(1));

      await store.deleteNote('del-test');
      expect(store.notes.isEmpty, isTrue);
    });
  });

  group('OwnerNotesScreen Widget Tests', () {
    testWidgets('renders screen and displays notes and filter tabs', (tester) async {
      final now = DateTime.now();
      final store = OwnerNotesStore.instance;
      store.setNotesForTesting([
        OwnerNote(
          id: 'w-note-1',
          title: 'Restock Cooking Oil',
          content: 'Order 2 boxes from distributor',
          category: 'Restock',
          isPinned: true,
          createdAt: now,
          updatedAt: now,
        ),
        OwnerNote(
          id: 'w-note-2',
          title: 'Remind Mang Kiko',
          content: 'Utang balance ₱250',
          category: 'Reminder',
          reminderDateTime: now.add(const Duration(hours: 1)),
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerNotesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Owner Notes & Reminders'), findsOneWidget);
      expect(find.text('Restock Cooking Oil'), findsOneWidget);
      expect(find.text('Remind Mang Kiko'), findsOneWidget);
      expect(find.text('New Note'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Reminders'), findsOneWidget);
    });
  });
}
