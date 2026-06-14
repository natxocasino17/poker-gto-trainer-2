/// Daily goals + achievements logic. Pure data layer (no Flutter), so it can
/// be reused and tested independently of the UI.

class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String desc;
  const Achievement(this.id, this.emoji, this.title, this.desc);
}

class DailyGoal {
  final String emoji;
  final String title;
  final int current;
  final int target;
  const DailyGoal(this.emoji, this.title, this.current, this.target);

  bool get done => current >= target;
  double get progress => target <= 0 ? 1 : (current / target).clamp(0, 1).toDouble();
}

/// Aggregate facts about the player's lifetime, fed by the UI from the
/// session archive + the live session.
class ProgressFacts {
  final int lifetimeHands;
  final int sessionsPlayed;
  final double totalProfit;
  final double bestSessionProfit;
  final double bestDecisionScore;
  final bool hadFlawlessSession; // a session of 5+ hands with 0 blunders
  final int streak;

  const ProgressFacts({
    required this.lifetimeHands,
    required this.sessionsPlayed,
    required this.totalProfit,
    required this.bestSessionProfit,
    required this.bestDecisionScore,
    required this.hadFlawlessSession,
    required this.streak,
  });
}

class ProgressService {
  static const List<Achievement> all = [
    Achievement('first_session', '🎓', 'Primera sesión', 'Juega tu primera sesión'),
    Achievement('hands_100', '🃏', '100 manos', 'Juega 100 manos en total'),
    Achievement('hands_500', '🎴', '500 manos', 'Juega 500 manos en total'),
    Achievement('grinder', '⏱️', 'Grinder', 'Completa 10 sesiones'),
    Achievement('big_win', '💰', 'Gran sesión', 'Cierra una sesión con +\$300'),
    Achievement('profit_500', '📈', 'En verde', 'Acumula +\$500 de beneficio'),
    Achievement('flawless', '✨', 'Impecable', 'Una sesión (5+ manos) sin blunders'),
    Achievement('sharp', '🎯', 'Afilado', 'Llega a 90+ de Decision Score'),
    Achievement('streak_3', '🔥', 'Racha x3', 'Juega 3 días seguidos'),
    Achievement('streak_7', '🔥', 'Racha x7', 'Juega 7 días seguidos'),
  ];

  static Set<String> evaluate(ProgressFacts f) {
    final ids = <String>{};
    if (f.sessionsPlayed >= 1) ids.add('first_session');
    if (f.lifetimeHands >= 100) ids.add('hands_100');
    if (f.lifetimeHands >= 500) ids.add('hands_500');
    if (f.sessionsPlayed >= 10) ids.add('grinder');
    if (f.bestSessionProfit >= 300) ids.add('big_win');
    if (f.totalProfit >= 500) ids.add('profit_500');
    if (f.hadFlawlessSession) ids.add('flawless');
    if (f.bestDecisionScore >= 90) ids.add('sharp');
    if (f.streak >= 3) ids.add('streak_3');
    if (f.streak >= 7) ids.add('streak_7');
    return ids;
  }

  static List<DailyGoal> daily({
    required int todayHands,
    required double todayProfit,
    required int todayBlunders,
  }) {
    return [
      DailyGoal('🃏', 'Juega 15 manos', todayHands.clamp(0, 15), 15),
      DailyGoal('💵', 'Termina el día en verde', todayProfit >= 0 ? 1 : 0, 1),
      DailyGoal('🧠', 'Disciplina: 0 blunders', todayBlunders == 0 ? 1 : 0, 1),
    ];
  }
}
