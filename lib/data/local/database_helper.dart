import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/app_usage.dart';
import '../models/time_budget.dart';
import '../models/goal.dart';
import '../models/focus_session.dart';
import '../models/daily_score.dart';
import '../models/time_block.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('focusflow_flutter.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE app_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        packageName TEXT NOT NULL,
        appName TEXT NOT NULL,
        category TEXT NOT NULL,
        startTime INTEGER NOT NULL,
        endTime INTEGER NOT NULL,
        durationMinutes INTEGER NOT NULL,
        date TEXT NOT NULL,
        launchCount INTEGER NOT NULL,
        UNIQUE(date, packageName) ON CONFLICT REPLACE
      )
    ''');

    await db.execute('''
      CREATE TABLE time_budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        limitMinutes INTEGER NOT NULL,
        date TEXT NOT NULL,
        enabled INTEGER NOT NULL,
        UNIQUE(category, date) ON CONFLICT REPLACE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_limits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        packageName TEXT NOT NULL,
        appName TEXT NOT NULL,
        limitMinutes INTEGER NOT NULL,
        date TEXT NOT NULL,
        enabled INTEGER NOT NULL,
        UNIQUE(packageName, date) ON CONFLICT REPLACE
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        targetMinutes INTEGER NOT NULL,
        completedMinutes INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE focus_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskName TEXT NOT NULL,
        startTime INTEGER NOT NULL,
        endTime INTEGER NOT NULL,
        durationMinutes INTEGER NOT NULL,
        completed INTEGER NOT NULL,
        distractionCount INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pomodoro_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        focusMinutes INTEGER NOT NULL,
        breakMinutes INTEGER NOT NULL,
        startTime INTEGER NOT NULL,
        endTime INTEGER NOT NULL,
        completed INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_scores (
        date TEXT PRIMARY KEY,
        score INTEGER NOT NULL,
        productiveMinutes INTEGER NOT NULL,
        distractingMinutes INTEGER NOT NULL,
        goalCompletionPercentage INTEGER NOT NULL,
        focusMinutes INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE achievements (
        achievementId TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        isUnlocked INTEGER NOT NULL,
        unlockedDate INTEGER
      )
    ''');

    // Seed initial achievements
    final initialBadges = [
      Achievement(achievementId: 'first_focus', title: 'First Step', description: 'Complete your first Focus Session'),
      Achievement(achievementId: 'focus_10_hours', title: 'Deep Worker', description: 'Complete 10 hours of focused work'),
      Achievement(achievementId: 'streak_3_days', title: 'Momentum', description: 'Maintain a 3-day productivity streak'),
      Achievement(achievementId: 'streak_7_days', title: 'Unstoppable', description: 'Maintain a 7-day productivity streak'),
      Achievement(achievementId: 'digital_balance', title: 'Digital Balance', description: 'Stay within social media budget'),
      Achievement(achievementId: 'goals_master', title: 'Goal Crusher', description: 'Complete 20 daily study goals'),
    ];

    for (var badge in initialBadges) {
      await db.insert('achievements', badge.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Seed default budgets
    final defaultBudgets = [
      TimeBudget(category: 'Social Media', limitMinutes: 60),
      TimeBudget(category: 'Gaming', limitMinutes: 45),
      TimeBudget(category: 'Entertainment', limitMinutes: 90),
    ];

    for (var b in defaultBudgets) {
      await db.insert('time_budgets', b.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await db.execute('''
      CREATE TABLE time_blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        isCompleted INTEGER NOT NULL,
        notes TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS time_blocks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          category TEXT NOT NULL,
          date TEXT NOT NULL,
          startTime TEXT NOT NULL,
          endTime TEXT NOT NULL,
          durationMinutes INTEGER NOT NULL,
          isCompleted INTEGER NOT NULL,
          notes TEXT
        )
      ''');
    }
  }

  // App Usage
  Future<void> saveAppUsageList(List<AppUsage> list) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var item in list) {
      batch.insert('app_usage', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<AppUsage>> getUsageForDate(String date) async {
    final db = await instance.database;
    final result = await db.query(
      'app_usage',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'durationMinutes DESC',
    );
    return result.map((json) => AppUsage.fromMap(json)).toList();
  }

  // Goals
  Future<int> insertGoal(Goal goal) async {
    final db = await instance.database;
    return await db.insert('goals', goal.toMap());
  }

  Future<int> updateGoal(Goal goal) async {
    final db = await instance.database;
    return await db.update('goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
  }

  Future<List<Goal>> getGoalsForDate(String date) async {
    final db = await instance.database;
    final result = await db.query('goals', where: 'date = ?', whereArgs: [date]);
    return result.map((json) => Goal.fromMap(json)).toList();
  }

  Future<int> deleteGoal(int id) async {
    final db = await instance.database;
    return await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  // Focus & Pomodoro
  Future<int> insertFocusSession(FocusSession session) async {
    final db = await instance.database;
    return await db.insert('focus_sessions', session.toMap());
  }

  Future<List<FocusSession>> getFocusSessionsForDate(String date) async {
    final db = await instance.database;
    final result = await db.query('focus_sessions', where: 'date = ?', whereArgs: [date]);
    return result.map((json) => FocusSession.fromMap(json)).toList();
  }

  Future<int> insertPomodoroSession(PomodoroSession session) async {
    final db = await instance.database;
    return await db.insert('pomodoro_sessions', session.toMap());
  }

  Future<int> getTotalFocusMinutesAllTime() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT SUM(durationMinutes) as total FROM focus_sessions WHERE completed = 1');
    final val = result.first['total'];
    return val != null ? (val as num).toInt() : 0;
  }

  Future<int> getTotalCompletedGoalsCount() async {
    final db = await instance.database;
    final result = await db.rawQuery("SELECT COUNT(*) as count FROM goals WHERE status = 'COMPLETED'");
    final val = result.first['count'];
    return val != null ? (val as num).toInt() : 0;
  }

  // Budgets & Limits
  Future<List<TimeBudget>> getAllBudgets() async {
    final db = await instance.database;
    final result = await db.query('time_budgets');
    return result.map((json) => TimeBudget.fromMap(json)).toList();
  }

  Future<int> setBudget(TimeBudget budget) async {
    final db = await instance.database;
    return await db.insert('time_budgets', budget.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AppLimit>> getAllAppLimits() async {
    final db = await instance.database;
    final result = await db.query('app_limits');
    return result.map((json) => AppLimit.fromMap(json)).toList();
  }

  Future<int> setAppLimit(AppLimit limit) async {
    final db = await instance.database;
    return await db.insert('app_limits', limit.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Daily Scores
  Future<void> saveDailyScore(DailyScore score) async {
    final db = await instance.database;
    await db.insert('daily_scores', score.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DailyScore?> getDailyScore(String date) async {
    final db = await instance.database;
    final result = await db.query('daily_scores', where: 'date = ?', whereArgs: [date]);
    if (result.isNotEmpty) return DailyScore.fromMap(result.first);
    return null;
  }

  Future<List<DailyScore>> getRecentScores(int limit) async {
    final db = await instance.database;
    final result = await db.query('daily_scores', orderBy: 'date DESC', limit: limit);
    return result.map((json) => DailyScore.fromMap(json)).toList();
  }

  // Achievements
  Future<List<Achievement>> getAllAchievements() async {
    final db = await instance.database;
    final result = await db.query('achievements');
    return result.map((json) => Achievement.fromMap(json)).toList();
  }

  Future<void> updateAchievement(Achievement achievement) async {
    final db = await instance.database;
    await db.update(
      'achievements',
      achievement.toMap(),
      where: 'achievementId = ?',
      whereArgs: [achievement.achievementId],
    );
  }

  // Time Blocks (Scheduled Tasks)
  Future<int> insertTimeBlock(TimeBlock block) async {
    final db = await instance.database;
    return await db.insert('time_blocks', block.toMap());
  }

  Future<int> updateTimeBlock(TimeBlock block) async {
    final db = await instance.database;
    return await db.update('time_blocks', block.toMap(), where: 'id = ?', whereArgs: [block.id]);
  }

  Future<int> deleteTimeBlock(int id) async {
    final db = await instance.database;
    return await db.delete('time_blocks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TimeBlock>> getTimeBlocksForDate(String date) async {
    final db = await instance.database;
    final result = await db.query(
      'time_blocks',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'startTime ASC',
    );
    return result.map((json) => TimeBlock.fromMap(json)).toList();
  }

  Future<void> toggleTimeBlock(int id, bool isCompleted) async {
    final db = await instance.database;
    await db.update(
      'time_blocks',
      {'isCompleted': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Clear data
  Future<void> clearTodayUsage(String date) async {
    final db = await instance.database;
    await db.delete('app_usage', where: 'date = ?', whereArgs: [date]);
  }

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete('app_usage');
    await db.delete('goals');
    await db.delete('focus_sessions');
    await db.delete('pomodoro_sessions');
    await db.delete('daily_scores');
    await db.delete('time_blocks');
  }
}
