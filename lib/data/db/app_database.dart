import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Terms from AGENTS.md section 8: first, second, summer.
class Semesters extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get term => text()();
  TextColumn get schoolYear => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Subjects extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get semesterId =>
      integer().references(Semesters, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  TextColumn get icon => text().withDefault(const Constant(''))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Activities extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId =>
      integer().references(Subjects, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get deadline => dateTime().nullable()();

  /// draft, in_progress, final, submitted.
  TextColumn get status => text().withDefault(const Constant('draft'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('DbFile')
class Files extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get activityId =>
      integer().references(Activities, #id, onDelete: KeyAction.cascade)();
  TextColumn get displayName => text()();

  /// Points to the latest commit. Nullable with no FK constraint because
  /// commits reference files (cycle); repos keep it in sync.
  IntColumn get currentCommitId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Commits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fileId =>
      integer().references(Files, #id, onDelete: KeyAction.cascade)();
  IntColumn get versionNo => integer()();
  TextColumn get message => text()();
  TextColumn get blobHash => text()();
  IntColumn get sizeBytes => integer()();
  TextColumn get mimeType => text().withDefault(const Constant(''))();
  IntColumn get restoredFromCommitId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// The signed-in account's local settings and display info (AGENTS.md
/// section 8). One row per account inside that account's database file.
/// The avatar and display name stay on this device only and are never
/// backed up to the cloud.
@DataClassName('DbProfile')
class Profiles extends Table {
  TextColumn get userId => text()();
  TextColumn get username => text()();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  TextColumn get avatarPath => text().nullable()();

  /// light, dark, or system.
  TextColumn get themeMode => text().withDefault(const Constant('system'))();

  /// indigo, teal, orange, or purple.
  TextColumn get accentKey => text().withDefault(const Constant('indigo'))();
  BoolColumn get remindDeadlines =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get remindBackupWeekly =>
      boolean().withDefault(const Constant(true))();

  /// Backup check-box settings, moved here from SharedPreferences in
  /// Phase 5A so each account keeps its own.
  BoolColumn get wifiOnlyBackup =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get includeOlderVersions =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {userId};
}

@DriftDatabase(
  tables: [Semesters, Subjects, Activities, Files, Commits, Profiles],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _local('shared'));

  AppDatabase.forUser(String userId) : super(_local('subtrack_$userId.sqlite'));

  AppDatabase.memory() : super(NativeDatabase.memory());

  static QueryExecutor _local(String name) => driftDatabase(name: name);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(profiles);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
