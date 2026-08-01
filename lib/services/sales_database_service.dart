import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class SalesRecord {
  final int? id;
  final String sessionId;
  final DateTime startedAt;
  final String pricingTier;
  final int price;
  final int photoCount;
  final int copies;
  final String uploadStatus; // pending, uploaded, failed
  final DateTime? uploadedAt;
  final int retryCount;
  final String? errorMessage;

  SalesRecord({
    this.id,
    required this.sessionId,
    required this.startedAt,
    required this.pricingTier,
    required this.price,
    required this.photoCount,
    this.copies = 1,
    this.uploadStatus = 'pending',
    this.uploadedAt,
    this.retryCount = 0,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'session_id': sessionId,
        'started_at': startedAt.toIso8601String(),
        'pricing_tier': pricingTier,
        'price': price,
        'photo_count': photoCount,
        'copies': copies,
        'upload_status': uploadStatus,
        'uploaded_at': uploadedAt?.toIso8601String(),
        'retry_count': retryCount,
        'error_message': errorMessage,
      };

  factory SalesRecord.fromMap(Map<String, dynamic> map) => SalesRecord(
        id: map['id'] as int?,
        sessionId: map['session_id'] as String,
        startedAt: DateTime.parse(map['started_at'] as String),
        pricingTier: map['pricing_tier'] as String,
        price: map['price'] as int,
        photoCount: map['photo_count'] as int,
        copies: map['copies'] as int? ?? 1,
        uploadStatus: map['upload_status'] as String? ?? 'pending',
        uploadedAt: map['uploaded_at'] != null
            ? DateTime.parse(map['uploaded_at'] as String)
            : null,
        retryCount: map['retry_count'] as int? ?? 0,
        errorMessage: map['error_message'] as String?,
      );

  SalesRecord copyWith({
    int? id,
    String? sessionId,
    DateTime? startedAt,
    String? pricingTier,
    int? price,
    int? photoCount,
    int? copies,
    String? uploadStatus,
    DateTime? uploadedAt,
    int? retryCount,
    String? errorMessage,
  }) =>
      SalesRecord(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        startedAt: startedAt ?? this.startedAt,
        pricingTier: pricingTier ?? this.pricingTier,
        price: price ?? this.price,
        photoCount: photoCount ?? this.photoCount,
        copies: copies ?? this.copies,
        uploadStatus: uploadStatus ?? this.uploadStatus,
        uploadedAt: uploadedAt ?? this.uploadedAt,
        retryCount: retryCount ?? this.retryCount,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class SalesDatabaseService {
  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'skyeloop_sales.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL UNIQUE,
            started_at TEXT NOT NULL,
            pricing_tier TEXT NOT NULL,
            price INTEGER NOT NULL,
            photo_count INTEGER NOT NULL,
            copies INTEGER NOT NULL DEFAULT 1,
            upload_status TEXT NOT NULL DEFAULT 'pending',
            uploaded_at TEXT,
            retry_count INTEGER NOT NULL DEFAULT 0,
            error_message TEXT
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_sessions_upload_status
          ON sessions(upload_status)
        ''');
        await db.execute('''
          CREATE INDEX idx_sessions_started_at
          ON sessions(started_at)
        ''');
      },
    );
  }

  /// Insert a completed session as a sales record.
  Future<void> insertSession(SalesRecord record) async {
    final db = await database;
    await db.insert('sessions', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Get all sessions with pending (or failed) upload status,
  /// grouped by date ascending, oldest first.
  Future<List<SalesRecord>> getPendingSessions({bool includeFailed = true}) async {
    final db = await database;
    final statuses = includeFailed
        ? ["'pending'", "'failed'"]
        : ["'pending'"];
    final maps = await db.query(
      'sessions',
      where: 'upload_status IN (${statuses.join(',')})',
      orderBy: 'started_at ASC',
    );
    return maps.map((m) => SalesRecord.fromMap(m)).toList();
  }

  /// Get all sessions for a specific date (YYYY-MM-DD).
  Future<List<SalesRecord>> getSessionsByDate(String date) async {
    final db = await database;
    final maps = await db.query(
      'sessions',
      where: 'started_at LIKE ?',
      whereArgs: ['$date%'],
      orderBy: 'started_at ASC',
    );
    return maps.map((m) => SalesRecord.fromMap(m)).toList();
  }

  /// Mark a session as uploaded.
  Future<void> markUploaded(int id) async {
    final db = await database;
    await db.update(
      'sessions',
      {
        'upload_status': 'uploaded',
        'uploaded_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'error_message': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark a session upload as failed.
  Future<void> markFailed(int id, {String? error}) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE sessions
      SET upload_status = 'failed',
          retry_count = retry_count + 1,
          error_message = ?
      WHERE id = ?
    ''', [error, id]);
  }

  /// Get distinct dates that have at least one pending/failed session.
  Future<List<String>> getPendingDates() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT DISTINCT substr(started_at, 1, 10) AS date
      FROM sessions
      WHERE upload_status IN ('pending', 'failed')
      ORDER BY date ASC
    ''');
    return maps.map((m) => m['date'] as String).toList();
  }

  /// Check if all sessions for a given date have been uploaded.
  Future<bool> isDateFullyUploaded(String date) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS pending
      FROM sessions
      WHERE started_at LIKE ? AND upload_status IN ('pending', 'failed')
    ''', ['$date%']);
    return (result.first['pending'] as int) == 0;
  }

  /// Get total count of pending/failed sessions.
  Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM sessions WHERE upload_status IN ('pending', 'failed')",
    );
    return result.first['count'] as int;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
