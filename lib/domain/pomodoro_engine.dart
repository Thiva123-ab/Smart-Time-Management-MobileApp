enum PomodoroPhase { focus, shortBreak, longBreak }

class PomodoroEngine {
  int focusMinutes;
  int breakMinutes;
  int longBreakMinutes;
  int remainingSeconds;
  PomodoroPhase currentPhase;
  bool isRunning;
  int completedCycles;

  PomodoroEngine({
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    this.longBreakMinutes = 15,
  })  : remainingSeconds = 25 * 60,
        currentPhase = PomodoroPhase.focus,
        isRunning = false,
        completedCycles = 0;

  void applyPreset(int focus, int shortBreak, int longBreak) {
    focusMinutes = focus;
    breakMinutes = shortBreak;
    longBreakMinutes = longBreak;
    remainingSeconds = focus * 60;
    currentPhase = PomodoroPhase.focus;
    isRunning = false;
  }

  void start() => isRunning = true;
  void pause() => isRunning = false;
  void reset() {
    isRunning = false;
    currentPhase = PomodoroPhase.focus;
    remainingSeconds = focusMinutes * 60;
  }

  /// Returns true if phase transition happened
  bool tick() {
    if (!isRunning) return false;

    if (remainingSeconds > 1) {
      remainingSeconds--;
      return false;
    }

    // Phase completed!
    if (currentPhase == PomodoroPhase.focus) {
      completedCycles++;
      final isLong = (completedCycles % 4 == 0);
      currentPhase = isLong ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak;
      remainingSeconds = (isLong ? longBreakMinutes : breakMinutes) * 60;
      return true;
    } else {
      currentPhase = PomodoroPhase.focus;
      remainingSeconds = focusMinutes * 60;
      return true;
    }
  }
}

class FocusSessionManager {
  bool isActive = false;
  bool isPaused = false;
  String taskName = '';
  int plannedMinutes = 25;
  int elapsedSeconds = 0;
  int distractionCount = 0;

  void start(String task, int minutes) {
    isActive = true;
    isPaused = false;
    taskName = task;
    plannedMinutes = minutes;
    elapsedSeconds = 0;
    distractionCount = 0;
  }

  void pause() => isPaused = true;
  void resume() => isPaused = false;
  void logDistraction() => distractionCount++;

  bool tick() {
    if (!isActive || isPaused) return false;
    elapsedSeconds++;
    return elapsedSeconds >= (plannedMinutes * 60);
  }

  Map<String, dynamic> finish(bool completed) {
    final completedMinutes = (elapsedSeconds ~/ 60).clamp(1, 999);
    final summary = {
      'taskName': taskName,
      'plannedMinutes': plannedMinutes,
      'completedMinutes': completedMinutes,
      'distractionCount': distractionCount,
      'completed': completed,
    };
    isActive = false;
    isPaused = false;
    return summary;
  }
}
