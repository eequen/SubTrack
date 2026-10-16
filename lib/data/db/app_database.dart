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

@DriftDatabase(tables: [Semesters, Subjects, Activities, Files, Commits])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _local('shared'));

  AppDatabase.forUser(String userId) : super(_local('subtrack_$userId.sqlite'));

  AppDatabase.memory() : super(NativeDatabase.memory());

  static QueryExecutor _local(String name) => driftDatabase(name: name);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async => m.createAll(),
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
