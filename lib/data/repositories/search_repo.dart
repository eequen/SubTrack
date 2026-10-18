import 'package:drift/drift.dart';
import 'package:subtrack/data/db/app_database.dart';

/// One activity matching the query, with its subject for the result path.
class ActivityHit {
  const ActivityHit({required this.activity, required this.subjectName});

  final Activity activity;
  final String subjectName;
}

/// One file matching the query, with the "subject > activity" path.
class FileHit {
  const FileHit({
    required this.file,
    required this.subjectName,
    required this.activityTitle,
  });

  final DbFile file;
  final String subjectName;
  final String activityTitle;
}

/// One commit matching the query, with the path of the file it belongs to.
class CommitHit {
  const CommitHit({
    required this.commit,
    required this.fileName,
    required this.subjectName,
    required this.activityTitle,
  });

  final Commit commit;
  final String fileName;
  final String subjectName;
  final String activityTitle;
}

/// Everything found in one semester, grouped by type (screen 9).
class SearchResults {
  const SearchResults({
    this.files = const [],
    this.activities = const [],
    this.commits = const [],
  });

  static const empty = SearchResults();

  final List<FileHit> files;
  final List<ActivityHit> activities;
  final List<CommitHit> commits;

  bool get isEmpty => files.isEmpty && activities.isEmpty && commits.isEmpty;
}

/// Search inside one semester (AGENTS.md section 9, Phase 4).
///
/// Matching is case-insensitive. Each item matches on its own visible name
/// and on its path: every hit also matches its subject name, files and
/// commits match their activity title, and commits match their file name.
/// This is how "search by subject" works: typing a subject name lists what
/// is filed under it.
///
/// A semester holds a school-sized amount of rows, so results are filtered
/// in Dart after one join per type. Newest first, at most [limit] per type.
class SearchRepo {
  SearchRepo(this.db);

  final AppDatabase db;

  Future<SearchResults> search(
    int semesterId,
    String query, {
    int limit = 50,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || semesterId <= 0) return SearchResults.empty;
    bool matches(String text) => text.toLowerCase().contains(q);
    bool reachedLimit(int count) => limit > 0 && count >= limit;

    final activityRows =
        await (db.select(db.activities).join([
                innerJoin(
                  db.subjects,
                  db.subjects.id.equalsExp(db.activities.subjectId),
                ),
              ])
              ..where(db.subjects.semesterId.equals(semesterId))
              ..orderBy([OrderingTerm.desc(db.activities.id)]))
            .get();

    final activities = <ActivityHit>[];
    for (final row in activityRows) {
      final activity = row.readTable(db.activities);
      final subjectName = row.readTable(db.subjects).name;
      if (!matches(activity.title) && !matches(subjectName)) continue;
      activities.add(ActivityHit(activity: activity, subjectName: subjectName));
      if (reachedLimit(activities.length)) break;
    }

    final fileRows =
        await (db.select(db.files).join([
                innerJoin(
                  db.activities,
                  db.activities.id.equalsExp(db.files.activityId),
                ),
                innerJoin(
                  db.subjects,
                  db.subjects.id.equalsExp(db.activities.subjectId),
                ),
              ])
              ..where(db.subjects.semesterId.equals(semesterId))
              ..orderBy([OrderingTerm.desc(db.files.id)]))
            .get();

    final files = <FileHit>[];
    for (final row in fileRows) {
      final file = row.readTable(db.files);
      final activity = row.readTable(db.activities);
      final subjectName = row.readTable(db.subjects).name;
      if (!matches(file.displayName) &&
          !matches(activity.title) &&
          !matches(subjectName)) {
        continue;
      }
      files.add(
        FileHit(
          file: file,
          subjectName: subjectName,
          activityTitle: activity.title,
        ),
      );
      if (reachedLimit(files.length)) break;
    }

    final commitRows =
        await (db.select(db.commits).join([
                innerJoin(db.files, db.files.id.equalsExp(db.commits.fileId)),
                innerJoin(
                  db.activities,
                  db.activities.id.equalsExp(db.files.activityId),
                ),
                innerJoin(
                  db.subjects,
                  db.subjects.id.equalsExp(db.activities.subjectId),
                ),
              ])
              ..where(db.subjects.semesterId.equals(semesterId))
              ..orderBy([
                OrderingTerm.desc(db.commits.createdAt),
                OrderingTerm.desc(db.commits.id),
              ]))
            .get();

    final commits = <CommitHit>[];
    for (final row in commitRows) {
      final commit = row.readTable(db.commits);
      final file = row.readTable(db.files);
      final activity = row.readTable(db.activities);
      final subjectName = row.readTable(db.subjects).name;
      if (!matches(commit.message) &&
          !matches(file.displayName) &&
          !matches(activity.title) &&
          !matches(subjectName)) {
        continue;
      }
      commits.add(
        CommitHit(
          commit: commit,
          fileName: file.displayName,
          subjectName: subjectName,
          activityTitle: activity.title,
        ),
      );
      if (reachedLimit(commits.length)) break;
    }

    return SearchResults(
      files: files,
      activities: activities,
      commits: commits,
    );
  }
}
