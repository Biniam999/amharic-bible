import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'user_database.g.dart';

// Verse positions are stored without a translation, so a highlight or note
// made in Amharic also shows in KJV (and any translation added later).

@DataClassName('BookmarkRow')
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Translation that was open when the bookmark was made.
  TextColumn get translationId => text()();
  IntColumn get bookId => integer()();
  IntColumn get chapter => integer()();
  IntColumn get verse => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {bookId, chapter, verse},
      ];
}

@DataClassName('HighlightRow')
class Highlights extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer()();
  IntColumn get chapter => integer()();
  IntColumn get verse => integer()();

  /// Index into HighlightColor (0 = yellow … 4 = orange).
  IntColumn get color => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {bookId, chapter, verse},
      ];
}

@DataClassName('NoteRow')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer()();
  IntColumn get chapter => integer()();
  IntColumn get verse => integer()();
  TextColumn get noteText => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {bookId, chapter, verse},
      ];
}

@DriftDatabase(tables: [Bookmarks, Highlights, Notes])
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.e);

  /// Opens (or creates) user.db on a background isolate.
  factory UserDatabase.open(File file) => UserDatabase(
        NativeDatabase.createInBackground(
          file,
          setup: (db) {
            db.execute('PRAGMA journal_mode = WAL');
            db.execute('PRAGMA temp_store = MEMORY');
          },
        ),
      );

  /// Bump this and add a step in [migration] whenever a table changes.
  /// Never edit an old step: users may upgrade from any earlier version.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Example for a future version 2:
          // if (from < 2) {
          //   await m.addColumn(notes, notes.title);
          // }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
