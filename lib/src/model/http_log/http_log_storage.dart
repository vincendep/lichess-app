import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/db/database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

part 'http_log_storage.g.dart';
part 'http_log_storage.freezed.dart';

/// Provides an instance of [HttpLogStorage] using Riverpod.
@Riverpod(keepAlive: true)
Future<HttpLogStorage> httpLogStorage(Ref ref) async {
  final db = await ref.read(databaseProvider.future);
  return HttpLogStorage(db);
}

const kHttpLogStorageTable = 'http_log';

/// Manages the storage of HTTP logs in a SQLite database.
class HttpLogStorage {
  const HttpLogStorage(this._db);
  final Database _db;

  /// Retrieves a paginated list of [HttpLog] entries from the database.
  Future<HttpLogs> page({int? cursor, int limit = 100}) async {
    final res = await _db.query(
      kHttpLogStorageTable,
      limit: limit + 1,
      orderBy: 'id DESC',
      where: cursor != null ? 'id <= $cursor' : null,
    );
    final next = res.elementAtOrNull(limit);
    res.remove(next);
    return HttpLogs(items: res.map(HttpLog.fromJson).toIList(), next: next?['id'] as int?);
  }

  /// Saves an [HttpLog] entry to the database.
  Future<void> save(HttpLog httpLog) async {
    await _db.insert(kHttpLogStorageTable, {
      ...httpLog.toJson(),
      'lastModified': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(
    String httpLogId, {
    required int responseCode,
    required DateTime responseDateTime,
  }) async {
    await _db.update(
      kHttpLogStorageTable,
      {
        'responseCode': responseCode,
        'responseDateTime': responseDateTime.toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'httpLogId = ?',
      whereArgs: [httpLogId],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAll() async {
    await _db.delete(kHttpLogStorageTable);
  }
}

/// Represents an HTTP log entry.
@Freezed(fromJson: true, toJson: true)
class HttpLog with _$HttpLog {
  const HttpLog._();

  const factory HttpLog({
    required String httpLogId,
    required String requestMethod,
    required String requestUrl,
    required DateTime requestDateTime,
    int? responseCode,
    DateTime? responseDateTime,
  }) = _HttpLog;

  bool get hasResponse => responseCode != null;

  Duration? get elapsed {
    if (responseDateTime == null) return null;
    return responseDateTime!.difference(requestDateTime);
  }

  factory HttpLog.fromJson(Map<String, dynamic> json) => _$HttpLogFromJson(json);
}

/// A class representing a collection of HTTP logs.
///
/// The `HttpLogs` class contains the following properties:
/// - `items`: A required list of `HttpLog` items.
/// - `next`: An optional integer representing the next cursor.
@Freezed(fromJson: true, toJson: true)
class HttpLogs with _$HttpLogs {
  const factory HttpLogs({required IList<HttpLog> items, required int? next}) = _HttpLogs;

  factory HttpLogs.fromJson(Map<String, dynamic> json) => _$HttpLogsFromJson(json);
}
