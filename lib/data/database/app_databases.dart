import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../../core/constants/app_constants.dart';
import 'bible_database.dart';
import 'user_database.dart';

/// Opens both databases at startup. Copies bible.db out of the APK on first
/// launch and whenever a newer one ships with an app update.
class AppDatabases {
  AppDatabases({required this.bible, required this.user});

  final BibleDatabase bible;
  final UserDatabase user;

  static Future<AppDatabases> open() async {
    if (Platform.isAndroid) {
      // Lets very old Android versions (6 and below) load the bundled SQLite.
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    // Application support, not Documents: on iOS, Documents is visible to the
    // user and backed up to iCloud, which a 14 MB read-only file shouldn't be.
    final dir = await getApplicationSupportDirectory();
    final installed = await BibleDbInstaller(dir).ensureInstalled();

    return AppDatabases(
      bible: BibleDatabase.open(installed.file, version: installed.version),
      user: UserDatabase.open(File(p.join(dir.path, AppConstants.userDbFile))),
    );
  }

  Future<void> close() async {
    await bible.close();
    await user.close();
  }
}

class BibleDbInstaller {
  BibleDbInstaller(this.directory, {AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final Directory directory;
  final AssetBundle _bundle;

  File get file => File(p.join(directory.path, AppConstants.bibleDbFile));

  /// Returns the installed file and its `user_version`, copying from assets if
  /// the file is missing, unreadable or older than [AppConstants.bibleDbVersion].
  Future<({File file, int version})> ensureInstalled() async {
    final current = readVersion(file);
    if (current != null && current >= AppConstants.bibleDbVersion) {
      return (file: file, version: current);
    }

    await _copyFromAssets();
    final version = readVersion(file);
    if (version == null) {
      throw StateError('bible.db was copied but cannot be opened. Rebuild it with tools/build_bible_db.py.');
    }
    if (version < AppConstants.bibleDbVersion) {
      // The shipped file is older than the code expects: someone bumped
      // AppConstants.bibleDbVersion without rebuilding with --db-version.
      throw StateError(
        'assets/db/bible.db has version $version but AppConstants.bibleDbVersion is '
        '${AppConstants.bibleDbVersion}. Rebuild with --db-version ${AppConstants.bibleDbVersion}.',
      );
    }
    return (file: file, version: version);
  }

  Future<void> _copyFromAssets() async {
    await directory.create(recursive: true);
    final data = await _bundle.load(AppConstants.bibleDbAsset);
    // Write to a temp file and rename, so a crash mid-copy never leaves a
    // half-written bible.db behind.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final old = File('${file.path}$suffix');
      if (await old.exists()) await old.delete();
    }
    await tmp.rename(file.path);
    if (kDebugMode) debugPrint('bible.db installed (${data.lengthInBytes ~/ 1024} KB)');
  }

  /// `PRAGMA user_version` of [f], or null if it is missing or not a database.
  static int? readVersion(File f) {
    if (!f.existsSync()) return null;
    try {
      final db = sqlite3.open(f.path, mode: OpenMode.readOnly);
      try {
        final hasVerses = db
            .select("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'verses'")
            .isNotEmpty;
        return hasVerses ? db.userVersion : null;
      } finally {
        db.dispose();
      }
    } on SqliteException {
      return null;
    }
  }
}
