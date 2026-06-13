import 'dart:convert';
import 'session_stats_model.dart';

/// Snapshot of one finished table session, archived for the yearly review.
class SessionSummary {
  final String id;
  final DateTime closedAt;
  final int hands;
  final double netProfit;
  final double bbPer100;
  final double vpip;
  final double pfr;
  final double threeBetPct;
  final double cBetPct;
  final double riverFoldPct;
  final int blunders;
  final double decisionScore;

  const SessionSummary({
    required this.id,
    required this.closedAt,
    required this.hands,
    required this.netProfit,
    required this.bbPer100,
    required this.vpip,
    required this.pfr,
    required this.threeBetPct,
    required this.cBetPct,
    required this.riverFoldPct,
    required this.blunders,
    required this.decisionScore,
  });

  factory SessionSummary.fromStats(SessionStats s) => SessionSummary(
        id: s.sessionId,
        closedAt: DateTime.now(),
        hands: s.handsPlayed,
        netProfit: s.netProfit,
        bbPer100: s.bbPer100,
        vpip: s.vpip,
        pfr: s.pfr,
        threeBetPct: s.threeBetPct,
        cBetPct: s.cBetPct,
        riverFoldPct: s.riverFoldPct,
        blunders: s.blunders,
        decisionScore: s.decisionScore,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': closedAt.millisecondsSinceEpoch,
        'h': hands,
        'np': netProfit,
        'bb': bbPer100,
        'v': vpip,
        'p': pfr,
        '3b': threeBetPct,
        'cb': cBetPct,
        'rf': riverFoldPct,
        'bl': blunders,
        'ds': decisionScore,
      };

  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
        id: j['id'] as String,
        closedAt: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
        hands: j['h'] as int,
        netProfit: (j['np'] as num).toDouble(),
        bbPer100: (j['bb'] as num).toDouble(),
        vpip: (j['v'] as num).toDouble(),
        pfr: (j['p'] as num).toDouble(),
        threeBetPct: (j['3b'] as num).toDouble(),
        cBetPct: (j['cb'] as num).toDouble(),
        riverFoldPct: (j['rf'] as num).toDouble(),
        blunders: j['bl'] as int,
        decisionScore: (j['ds'] as num).toDouble(),
      );

  static String encodeList(List<SessionSummary> list) =>
      jsonEncode(list.map((s) => s.toJson()).toList());

  static List<SessionSummary> decodeList(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => SessionSummary.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

/// el Puxi's yearly progress coach: compares your recent sessions
/// against the older ones and tells you (without mercy) what is actually
/// improving and what is still broken.
class YearCoach {
  static String progressReport(List<SessionSummary> all) {
    final sessions = all.where((s) => s.hands > 0).toList();
    if (sessions.length < 2) {
      return 'Necesito al menos 2 sesiones cerradas para medir tu evolución. '
          'Juega, cierra sesión y vuelve — la regularidad es la primera '
          'estadística que suspende la gente. — el Puxi';
    }

    sessions.sort((a, b) => a.closedAt.compareTo(b.closedAt));
    final half = sessions.length ~/ 2;
    final older = sessions.take(half).toList();
    final recent = sessions.skip(half).toList();

    double avg(List<SessionSummary> xs, double Function(SessionSummary) f) =>
        xs.isEmpty ? 0 : xs.map(f).reduce((a, b) => a + b) / xs.length;

    final totalHands = sessions.fold<int>(0, (a, s) => a + s.hands);
    final totalProfit = sessions.fold<double>(0, (a, s) => a + s.netProfit);
    final globalBB100 = totalHands > 0 ? (totalProfit / 2.0) / totalHands * 100 : 0.0;

    final bbOld = avg(older, (s) => s.bbPer100);
    final bbNew = avg(recent, (s) => s.bbPer100);
    final vpipOld = avg(older, (s) => s.vpip);
    final vpipNew = avg(recent, (s) => s.vpip);
    final blunderRateOld =
        avg(older, (s) => s.hands > 0 ? s.blunders / s.hands * 100 : 0);
    final blunderRateNew =
        avg(recent, (s) => s.hands > 0 ? s.blunders / s.hands * 100 : 0);
    final scoreOld = avg(older, (s) => s.decisionScore);
    final scoreNew = avg(recent, (s) => s.decisionScore);
    final riverFoldNew = avg(recent, (s) => s.riverFoldPct);
    final threeBetNew = avg(recent, (s) => s.threeBetPct);

    final b = StringBuffer();
    b.writeln('═══ EVOLUCIÓN ANUAL — EL PUXI ═══\n');
    b.writeln('Volumen total: ${sessions.length} sesiones · $totalHands manos');
    b.writeln(
        'Resultado global: ${totalProfit >= 0 ? "+" : ""}\$${totalProfit.toStringAsFixed(2)} (${globalBB100 >= 0 ? "+" : ""}${globalBB100.toStringAsFixed(1)} BB/100)\n');

    b.writeln('📈 WINRATE (BB/100)');
    if (bbNew > bbOld + 3) {
      b.writeln('✅ De ${bbOld.toStringAsFixed(1)} a ${bbNew.toStringAsFixed(1)}: estás mejorando de verdad. No me lo creía ni yo.');
    } else if (bbNew < bbOld - 3) {
      b.writeln('⚠️ De ${bbOld.toStringAsFixed(1)} a ${bbNew.toStringAsFixed(1)}: vas a peor. ¿Estudias o solo le das al botón?');
    } else {
      b.writeln('➡️ Estable (${bbNew.toStringAsFixed(1)}). Ni frío ni calor. La varianza manda a corto plazo, sigue sumando volumen.');
    }

    b.writeln('\n🧠 CALIDAD DE DECISIONES');
    if (scoreNew > scoreOld + 4) {
      b.writeln('✅ Tu nota media subió de ${scoreOld.toStringAsFixed(0)} a ${scoreNew.toStringAsFixed(0)}/100. Se nota que algo se te queda de mis broncas.');
    } else if (scoreNew < scoreOld - 4) {
      b.writeln('⚠️ Tu nota media bajó de ${scoreOld.toStringAsFixed(0)} a ${scoreNew.toStringAsFixed(0)}/100. Estás jugando en piloto automático (leak mental: Autopilot).');
    } else {
      b.writeln('➡️ Nota estable en ${scoreNew.toStringAsFixed(0)}/100.');
    }

    b.writeln('\n🚨 ERRORES GRAVES POR 100 MANOS');
    if (blunderRateNew < blunderRateOld - 1) {
      b.writeln('✅ Bajaron de ${blunderRateOld.toStringAsFixed(1)} a ${blunderRateNew.toStringAsFixed(1)}. Menos dinero al váter, así me gusta.');
    } else if (blunderRateNew > blunderRateOld + 1) {
      b.writeln('⚠️ Subieron de ${blunderRateOld.toStringAsFixed(1)} a ${blunderRateNew.toStringAsFixed(1)}. Repasa tus manos en ANALIZAR antes de la próxima sesión, sin excusas.');
    } else {
      b.writeln('➡️ Estables en ${blunderRateNew.toStringAsFixed(1)}.');
    }

    b.writeln('\n🎚️ DISCIPLINA PREFLOP (VPIP)');
    final vpipDelta = (vpipNew - vpipOld).abs();
    if (vpipNew >= 22 && vpipNew <= 28) {
      b.writeln('✅ VPIP reciente ${vpipNew.toStringAsFixed(1)}%: dentro del rango óptimo de 6-Max.');
    } else if (vpipDelta > 3 && (vpipNew - 25).abs() < (vpipOld - 25).abs()) {
      b.writeln('✅ VPIP acercándose al objetivo: de ${vpipOld.toStringAsFixed(1)}% a ${vpipNew.toStringAsFixed(1)}%. Camino correcto.');
    } else {
      b.writeln('⚠️ VPIP reciente ${vpipNew.toStringAsFixed(1)}% (objetivo 22–28%). El preflop sigue siendo tu asignatura pendiente.');
    }

    b.writeln('\n📋 PRIORIDADES PARA LAS PRÓXIMAS SESIONES');
    int n = 1;
    if (blunderRateNew > 5) {
      b.writeln('$n. Reducir blunders por debajo de 5/100 manos: revisa CADA error grave antes de volver a sentarte.');
      n++;
    }
    if (riverFoldNew > 55) {
      b.writeln('$n. Dejar de regalar rivers: tu fold medio en river es ${riverFoldNew.toStringAsFixed(0)}%. Los agresivos te tienen fichado.');
      n++;
    }
    if (threeBetNew < 6) {
      b.writeln('$n. Subir el 3-bet hacia 8–12%: añade A5s-A2s como faroles polarizados.');
      n++;
    }
    if (vpipNew > 30) {
      b.writeln('$n. Recortar el VPIP hacia 22–28%: menos manos basura desde posiciones tempranas.');
      n++;
    }
    if (n == 1) {
      b.writeln('1. Mantener la línea: sube el volumen de manos y la consistencia entre sesiones.');
    }
    b.writeln('\n— el Puxi, midiendo tu progreso aunque tú no lo hagas 🃏');

    return b.toString();
  }
}
