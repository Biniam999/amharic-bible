import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Read-only access to the pre-built bible.db (see tools/build_bible_db.py).
///
/// The schema is created by the Python build, not by drift, so this class is
/// written by hand instead of generated: it declares no tables and only runs
/// raw SQL through drift's `customSelect`.
class BibleDatabase extends GeneratedDatabase {
  BibleDatabase(super.executor, {required int version}) : _version = version;

  /// Opens [file] on a background isolate with writes disabled.
  ///
  /// [version] must equal the file's `PRAGMA user_version`; drift then sees
  /// nothing to migrate and never writes to the file.
  factory BibleDatabase.open(File file, {required int version}) => BibleDatabase(
        NativeDatabase.createInBackground(
          file,
          setup: (db) {
            db.execute('PRAGMA query_only = ON');
            db.execute('PRAGMA temp_store = MEMORY');
          },
        ),
        version: version,
      );

  final int _version;

  @override
  int get schemaVersion => _version;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (_) async => throw StateError('bible.db is empty — it must be built with tools/build_bible_db.py'),
        onUpgrade: (_, from, to) async =>
            throw StateError('bible.db version $from does not match the expected version $to'),
      );
}
