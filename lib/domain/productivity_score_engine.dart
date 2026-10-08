class ScoreResult {
  final int totalScore;
  final int goalPoints;
  final int productiveRatioPoints;
  final int focusPoints;
  final int distractionControlPoints;
  final int consistencyPoints;
  final String advice;

  ScoreResult({
    required this.totalScore,
    required this.goalPoints,
    required this.productiveRatioPoints,
    required this.focusPoints,
    required this.distractionControlPoints,
    required this.consistencyPoints,
    required this.advice,
  });
}

class ProductivityScoreEngine {
  static ScoreResult calculateScore({
    required int goalCompletionPercentage,
    required int productiveMinutes,
    required int distractingMinutes,
    required int focusMinutes,
    int streakDays = 1,
    int budgetViolations = 0,
  }) {
    // 1. Goal Completion (Max 30)
    final goalPoints = ((goalCompletionPercentage.clamp(0, 100) * 30) / 100).round();

    // 2. Productive Ratio (Max 25)
    final totalActive = productiveMinutes + distractingMinutes;
    final productiveRatioPoints = totalActive > 0
        ? ((productiveMinutes / totalActive) * 25).round().clamp(0, 25)
        : 15;

    // 3. Focus Sessions (Max 20, 120m target)
    const focusTarget = 120;
    final focusPoints = ((focusMinutes.clamp(0, focusTarget) / focusTarget) * 20).round().clamp(0, 20);

    // 4. Distraction Control (Max 15)
    int distractionPoints = 15;
    if (distractingMinutes > 120) {
      final excessHalfHours = (distractingMinutes - 120) ~/ 30;
      distractionPoints -= excessHalfHours * 3;
    }
    distractionPoints -= (budgetViolations * 4);
    final finalDistractionPoints = distractionPoints.clamp(0, 15);

    // 5. Consistency / Streak (Max 10)
    final consistencyPoints = streakDays >= 7
        ? 10
        : streakDays >= 3
            ? 8
            : streakDays >= 1
                ? 6
                : 4;

    final total = (goalPoints + productiveRatioPoints + focusPoints + finalDistractionPoints + consistencyPoints).clamp(0, 100);

    final advice = total >= 85
        ? 'Outstanding flow today! Deep concentration with minimum distractions.'
        : total >= 70
            ? 'Solid productive day. Try setting an app limit on entertainment apps to reach 90+.'
            : total >= 50
                ? 'Balanced day. Start a 45-minute Focus Session to boost your score.'
                : 'High distraction detected. Consider setting strict time budgets tomorrow.';

    return ScoreResult(
      totalScore: total,
      goalPoints: goalPoints,
      productiveRatioPoints: productiveRatioPoints,
      focusPoints: focusPoints,
      distractionControlPoints: finalDistractionPoints,
      consistencyPoints: consistencyPoints,
      advice: advice,
    );
  }
}
