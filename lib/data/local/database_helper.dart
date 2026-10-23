import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/app_usage.dart';
import '../models/time_budget.dart';
import '../models/goal.dart';
import '../models/focus_session.dart';
import '../models/daily_score.dart';
import '../models/time_block.dart';
import '../models/time_sub_task.dart';
import '../models/daily_note.dart';
import '../models/daily_habit_activity.dart';

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
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // Ensure time_sub_tasks table exists without affecting any existing tables or rows
        await db.execute('''
          CREATE TABLE IF NOT EXISTS time_sub_tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            blockId INTEGER NOT NULL,
            title TEXT NOT NULL,
            durationMinutes INTEGER NOT NULL,
            startTime TEXT,
            endTime TEXT,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            isUrgent INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER
          )
        ''');

        // Ensure daily_notes table exists for day-to-day notes and ideas
        await db.execute('''
          CREATE TABLE IF NOT EXISTS daily_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'Idea',
            colorHex TEXT,
            isPinned INTEGER NOT NULL DEFAULT 0,
            createdAt INTEGER,
            updatedAt INTEGER
          )
        ''');
      },
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS time_sub_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        blockId INTEGER NOT NULL,
        title TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        startTime TEXT,
        endTime TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        isUrgent INTEGER NOT NULL DEFAULT 1,
        createdAt INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Idea',
        colorHex TEXT,
        isPinned INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER,
        updatedAt INTEGER
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
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS time_sub_tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          blockId INTEGER NOT NULL,
          title TEXT NOT NULL,
          durationMinutes INTEGER NOT NULL,
          startTime TEXT,
          endTime TEXT,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          isUrgent INTEGER NOT NULL DEFAULT 1,
          createdAt INTEGER
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'Idea',
          colorHex TEXT,
          isPinned INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER,
          updatedAt INTEGER
        )
      ''');
    }
  }

  // App Usage
  Future<void> replaceAppUsageForDate(String date, List<AppUsage> list) async {
    final db = await instance.database;
    await db.delete('app_usage', where: 'date = ?', whereArgs: [date]);
    if (list.isNotEmpty) {
      final batch = db.batch();
      for (var item in list) {
        batch.insert('app_usage', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    }
  }

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

  Future<Goal?> getGoalById(int id) async {
    final db = await instance.database;
    final result = await db.query('goals', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return Goal.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateGoalProgress(int id, int completedMinutes, {bool? markCompleted}) async {
    final db = await instance.database;
    final values = <String, dynamic>{
      'completedMinutes': completedMinutes,
    };
    if (markCompleted != null) {
      values['status'] = markCompleted ? 'COMPLETED' : 'IN_PROGRESS';
    }
    return await db.update('goals', values, where: 'id = ?', whereArgs: [id]);
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
    await db.delete('time_sub_tasks', where: 'blockId = ?', whereArgs: [id]);
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

  // Time Sub-Tasks (Urgent in-block allocations)
  Future<int> insertTimeSubTask(TimeSubTask subTask) async {
    final db = await instance.database;
    return await db.insert('time_sub_tasks', subTask.toMap());
  }

  Future<int> updateTimeSubTask(TimeSubTask subTask) async {
    final db = await instance.database;
    return await db.update(
      'time_sub_tasks',
      subTask.toMap(),
      where: 'id = ?',
      whereArgs: [subTask.id],
    );
  }

  Future<int> deleteTimeSubTask(int id) async {
    final db = await instance.database;
    return await db.delete('time_sub_tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleTimeSubTask(int id, bool isCompleted) async {
    final db = await instance.database;
    await db.update(
      'time_sub_tasks',
      {'isCompleted': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TimeSubTask>> getSubTasksForBlock(int blockId) async {
    final db = await instance.database;
    final result = await db.query(
      'time_sub_tasks',
      where: 'blockId = ?',
      whereArgs: [blockId],
      orderBy: 'createdAt ASC',
    );
    return result.map((json) => TimeSubTask.fromMap(json)).toList();
  }

  Future<Map<int, List<TimeSubTask>>> getSubTasksForDate(String date) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT s.* FROM time_sub_tasks s
      INNER JOIN time_blocks b ON s.blockId = b.id
      WHERE b.date = ?
      ORDER BY s.createdAt ASC
    ''', [date]);

    final map = <int, List<TimeSubTask>>{};
    for (var row in result) {
      final subTask = TimeSubTask.fromMap(row);
      map.putIfAbsent(subTask.blockId, () => []).add(subTask);
    }
    return map;
  }

  // Daily Notes & Ideas
  Future<int> insertDailyNote(DailyNote note) async {
    final db = await instance.database;
    return await db.insert('daily_notes', note.toMap());
  }

  Future<int> updateDailyNote(DailyNote note) async {
    final db = await instance.database;
    return await db.update(
      'daily_notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteDailyNote(int id) async {
    final db = await instance.database;
    return await db.delete('daily_notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> togglePinDailyNote(int id, bool isPinned) async {
    final db = await instance.database;
    await db.update(
      'daily_notes',
      {'isPinned': isPinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<DailyNote>> getDailyNotesForDate(String date) async {
    final db = await instance.database;
    final result = await db.query(
      'daily_notes',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'isPinned DESC, createdAt DESC',
    );
    return result.map((json) => DailyNote.fromMap(json)).toList();
  }

  Future<List<DailyNote>> getAllDailyNotes() async {
    final db = await instance.database;
    final result = await db.query(
      'daily_notes',
      orderBy: 'date DESC, isPinned DESC, createdAt DESC',
    );
    return result.map((json) => DailyNote.fromMap(json)).toList();
  }

  Future<List<TimeBlock>> getAllTimeBlocksWithNotes() async {
    final db = await instance.database;
    final result = await db.query(
      'time_blocks',
      where: 'notes IS NOT NULL AND notes != ?',
      whereArgs: [''],
      orderBy: 'date DESC, startTime DESC',
    );
    return result.map((json) => TimeBlock.fromMap(json)).toList();
  }

  /// Returns set of dates ('yyyy-MM-dd') that have recorded activities (time blocks, focus sessions, app usage, or scores).
  Future<Set<String>> getDatesWithActivity({required String startDate, required String endDate}) async {
    final db = await instance.database;
    final dates = <String>{};

    try {
      final blockDates = await db.rawQuery(
        'SELECT DISTINCT date FROM time_blocks WHERE date BETWEEN ? AND ?',
        [startDate, endDate],
      );
      for (final row in blockDates) {
        final d = row['date'];
        if (d != null && d is String) dates.add(d);
      }

      final focusDates = await db.rawQuery(
        'SELECT DISTINCT date FROM focus_sessions WHERE date BETWEEN ? AND ?',
        [startDate, endDate],
      );
      for (final row in focusDates) {
        final d = row['date'];
        if (d != null && d is String) dates.add(d);
      }

      final scoreDates = await db.rawQuery(
        'SELECT DISTINCT date FROM daily_scores WHERE date BETWEEN ? AND ?',
        [startDate, endDate],
      );
      for (final row in scoreDates) {
        final d = row['date'];
        if (d != null && d is String) dates.add(d);
      }

      final noteDates = await db.rawQuery(
        'SELECT DISTINCT date FROM daily_notes WHERE date BETWEEN ? AND ?',
        [startDate, endDate],
      );
      for (final row in noteDates) {
        final d = row['date'];
        if (d != null && d is String) dates.add(d);
      }
    } catch (e) {
      debugPrint('Error getting dates with activity: $e');
    }

    return dates;
  }

  /// Fetches aggregated daily habit activity and computes streaks for a trailing window of days.
  Future<HabitHeatmapStats> getHabitHeatmapStats({int daysCount = 30}) async {
    final db = await instance.database;
    final now = DateTime.now();
    final startDateDt = now.subtract(Duration(days: daysCount - 1));

    String formatDate(DateTime dt) {
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    final startDate = formatDate(startDateDt);
    final endDate = formatDate(now);

    final focusMap = <String, int>{};
    final blocksMap = <String, int>{};
    final goalsMap = <String, int>{};
    final scoresMap = <String, int>{};
    final prodUsageMap = <String, int>{};

    try {
      // 1. Focus sessions
      final focusRows = await db.rawQuery(
        'SELECT date, SUM(durationMinutes) as totalMins FROM focus_sessions WHERE completed = 1 AND date BETWEEN ? AND ? GROUP BY date',
        [startDate, endDate],
      );
      for (final r in focusRows) {
        final d = r['date'] as String?;
        final m = (r['totalMins'] as num?)?.toInt() ?? 0;
        if (d != null) focusMap[d] = m;
      }

      // 2. Completed Time Blocks
      final blockRows = await db.rawQuery(
        'SELECT date, COUNT(*) as count FROM time_blocks WHERE isCompleted = 1 AND date BETWEEN ? AND ? GROUP BY date',
        [startDate, endDate],
      );
      for (final r in blockRows) {
        final d = r['date'] as String?;
        final c = (r['count'] as num?)?.toInt() ?? 0;
        if (d != null) blocksMap[d] = c;
      }

      // 3. Completed Goals
      final goalRows = await db.rawQuery(
        "SELECT date, COUNT(*) as count FROM goals WHERE status = 'COMPLETED' AND date BETWEEN ? AND ? GROUP BY date",
        [startDate, endDate],
      );
      for (final r in goalRows) {
        final d = r['date'] as String?;
        final c = (r['count'] as num?)?.toInt() ?? 0;
        if (d != null) goalsMap[d] = c;
      }

      // 4. Daily scores
      final scoreRows = await db.rawQuery(
        'SELECT date, score FROM daily_scores WHERE date BETWEEN ? AND ?',
        [startDate, endDate],
      );
      for (final r in scoreRows) {
        final d = r['date'] as String?;
        final s = (r['score'] as num?)?.toInt() ?? 0;
        if (d != null) scoresMap[d] = s;
      }

      // 5. Productive app usage
      final usageRows = await db.rawQuery(
        "SELECT date, SUM(durationMinutes) as prodMins FROM app_usage WHERE category IN ('Productivity', 'Education', 'Work', 'Study') AND date BETWEEN ? AND ? GROUP BY date",
        [startDate, endDate],
      );
      for (final r in usageRows) {
        final d = r['date'] as String?;
        final m = (r['prodMins'] as num?)?.toInt() ?? 0;
        if (d != null) prodUsageMap[d] = m;
      }
    } catch (e) {
      debugPrint('Error gathering habit heatmap stats: $e');
    }

    final activityMap = <String, DailyHabitActivity>{};
    int totalFocusMinutes = 0;
    int activeDaysCount = 0;
    int scoreSum = 0;
    int scoredDays = 0;

    final dateList = <String>[];
    for (int i = daysCount - 1; i >= 0; i--) {
      final dt = now.subtract(Duration(days: i));
      final dStr = formatDate(dt);
      dateList.add(dStr);

      final fMins = focusMap[dStr] ?? 0;
      final cBlocks = blocksMap[dStr] ?? 0;
      final cGoals = goalsMap[dStr] ?? 0;
      final dScore = scoresMap[dStr] ?? 0;
      final pUsage = prodUsageMap[dStr] ?? 0;

      final activity = DailyHabitActivity(
        date: dStr,
        focusMinutes: fMins,
        completedTasks: cBlocks,
        completedGoals: cGoals,
        productivityScore: dScore,
        productiveAppMinutes: pUsage,
      );

      activityMap[dStr] = activity;
      totalFocusMinutes += fMins;
      if (activity.hasActivity) {
        activeDaysCount++;
      }
      if (dScore > 0) {
        scoreSum += dScore;
        scoredDays++;
      }
    }

    // Calculate current streak
    final todayStr = formatDate(now);
    final yesterdayStr = formatDate(now.subtract(const Duration(days: 1)));
    int currentStreak = 0;

    final hasTodayActivity = activityMap[todayStr]?.hasActivity ?? false;
    final startIdx = hasTodayActivity
        ? dateList.indexOf(todayStr)
        : dateList.indexOf(yesterdayStr);

    if (startIdx >= 0) {
      for (int i = startIdx; i >= 0; i--) {
        final dStr = dateList[i];
        if (activityMap[dStr]?.hasActivity ?? false) {
          currentStreak++;
        } else {
          break;
        }
      }
    }

    // Calculate longest streak
    int longestStreak = 0;
    int tempStreak = 0;
    for (final dStr in dateList) {
      if (activityMap[dStr]?.hasActivity ?? false) {
        tempStreak++;
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
      } else {
        tempStreak = 0;
      }
    }

    final avgScore = scoredDays > 0 ? (scoreSum / scoredDays) : 0.0;

    return HabitHeatmapStats(
      activityMap: activityMap,
      totalDays: daysCount,
      activeDaysCount: activeDaysCount,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalFocusMinutes: totalFocusMinutes,
      averageDailyScore: avgScore,
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
