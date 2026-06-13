/// BOARD TEXTURE LIBRARY — canonical flop archetypes as structured knowledge.
///
/// Pure content (no UI). Classifies common flop textures and prescribes the
/// strategic approach (who has range/nut advantage, c-bet sizing & frequency,
/// how the equity shifts on turns). Complements the runtime [BoardTexture]
/// analyzer in poker_concepts.dart with human-readable coaching.
class BoardArchetype {
  final String id;
  final String title;
  final String example;       // representative flop
  final String texture;       // 'dry' | 'wet' | 'dynamic' | 'paired' | 'monotone'
  final String rangeAdvantage; // who the board favors and why
  final String cbetPlan;       // sizing + frequency guidance
  final String turnDynamics;   // how equity shifts on later streets
  final double wetness;        // 0.0 dry .. 1.0 wet (mirrors BoardTexture.wetness)

  const BoardArchetype({
    required this.id,
    required this.title,
    required this.example,
    required this.texture,
    required this.rangeAdvantage,
    required this.cbetPlan,
    required this.turnDynamics,
    required this.wetness,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'example': example,
        'texture': texture,
        'range_advantage': rangeAdvantage,
        'cbet_plan': cbetPlan,
        'turn_dynamics': turnDynamics,
        'wetness': wetness,
      };
}

class BoardLibrary {
  static const List<BoardArchetype> archetypes = [
    BoardArchetype(
      id: 'ace_high_dry',
      title: 'As alto seco',
      example: 'A♠7♦2♣',
      texture: 'dry',
      rangeAdvantage: 'Fuerte ventaja del agresor preflop: su rango tiene muchos '
          'más Ax (AK, AQ, AJ, AA) que el defensor. Ventaja de rango Y de nueces.',
      cbetPlan: 'C-bet ⅓ del bote con casi todo tu rango (~80-90%). Apuesta barata '
          'que cobra de Kx/Qx, niega equity a backdoors y mantiene tu rango ancho.',
      turnDynamics: 'Cartas que emparejan (A, 7, 2) o broadways (K,Q) siguen '
          'favoreciéndote: double barrel. Cartas bajas/conectadas dan menos miedo.',
      wetness: 0.05,
    ),
    BoardArchetype(
      id: 'king_high_dry',
      title: 'Rey alto seco',
      example: 'K♦8♣3♥',
      texture: 'dry',
      rangeAdvantage: 'Ventaja del agresor: más Kx y overpairs (AA) en su rango. '
          'El defensor rara vez tiene Kx fuerte (KQ/KJ a veces).',
      cbetPlan: 'C-bet pequeña (⅓) alta frecuencia. En boards K-high tu rango '
          'merged apuesta barato y cobra de pares medios que pagan una calle.',
      turnDynamics: 'Un A en el turn es scare card que favorece tu rango '
          '(double barrel creíble). Cartas bajas no cambian nada: sigue tu plan.',
      wetness: 0.08,
    ),
    BoardArchetype(
      id: 'low_connected',
      title: 'Bajo y conectado',
      example: '7♦6♣5♠',
      texture: 'dynamic',
      rangeAdvantage: 'Favorece al DEFENSOR (BB): su rango de calls tiene más '
          '87, 98, 65, 44, 55 que pegan straights/sets. El opener tight no conecta.',
      cbetPlan: 'C-bet de baja frecuencia (~35%) y polarizada: apuesta valor real '
          '(overpairs, sets) + algunos semi-bluffs. Checkea mucho tu rango medio: '
          'aquí te check-raisean sin piedad.',
      turnDynamics: 'Muchísimas cartas cambian el ganador. Un 8/9/4 completa '
          'straights. Cautela extrema con manos medias OOP; las nuts cobran grande.',
      wetness: 0.75,
    ),
    BoardArchetype(
      id: 'monotone',
      title: 'Monocolor',
      example: 'Q♠9♠4♠',
      texture: 'monotone',
      rangeAdvantage: 'Equity comprimida: alguien puede ya tener color. El que '
          'tiene el A♠ (nut flush blocker) controla la dinámica de faroles.',
      cbetPlan: 'C-bet de frecuencia media, sizing pequeño (⅓). No infles el bote '
          'sin el color o un blocker fuerte. El A♠ desnudo es buen farol; sets sin '
          'el palo prefieren pot control.',
      turnDynamics: 'Una cuarta carta del palo mata la acción (todos temen el '
          'color). Cartas de otro palo permiten seguir representando el color alto.',
      wetness: 0.55,
    ),
    BoardArchetype(
      id: 'two_tone_high',
      title: 'Dos tonos alto',
      example: 'A♥T♥6♣',
      texture: 'wet',
      rangeAdvantage: 'Ventaja del agresor por los Ax, pero el board está húmedo '
          '(flush draw + broadway). Ventaja de rango sí, de nueces compartida.',
      cbetPlan: 'C-bet ⅔ del bote (sizing mayor por la humedad) con valor y '
          'proyectos fuertes. Protege tus Ax de los flush/straight draws. Frecuencia '
          'media-alta pero NO apuestes todo: las manos medias prefieren check.',
      turnDynamics: 'Una carta de corazón o un J/K/Q completa proyectos. Double '
          'barrel con valor + nut flush draws; frena manos marginales que pierden '
          'valor cuando llegan los proyectos.',
      wetness: 0.62,
    ),
    BoardArchetype(
      id: 'paired_high',
      title: 'Emparejado alto',
      example: 'K♠K♦6♣',
      texture: 'paired',
      rangeAdvantage: 'Ventaja del agresor: más Kx (trips) y overpairs. El '
          'defensor rara vez tiene el K. Pocos proyectos posibles.',
      cbetPlan: 'C-bet pequeña (⅓-¼) altísima frecuencia (~85%): board seco '
          'emparejado, casi nadie te check-raisea sin trips. Roba mucho bote barato.',
      turnDynamics: 'Estático: pocas cartas cambian el ganador. Sigue barreleando '
          'con tu rango; el rival con par medio está en un aprieto constante.',
      wetness: 0.12,
    ),
    BoardArchetype(
      id: 'paired_low',
      title: 'Emparejado bajo',
      example: '8♣8♦3♠',
      texture: 'paired',
      rangeAdvantage: 'Ligeramente al agresor por los overpairs (AA-99) y broadways. '
          'El defensor tiene algunos 8x pero su rango es más capado.',
      cbetPlan: 'C-bet pequeña, frecuencia alta. Tu rango de overcards/overpairs '
          'domina. Cuidado con stations que pagan con cualquier par.',
      turnDynamics: 'Estático. Overcards (A,K,Q) en el turn favorecen tu rango y '
          'permiten double barrel; pueden darte top pair además.',
      wetness: 0.10,
    ),
    BoardArchetype(
      id: 'middle_connected',
      title: 'Medio conectado',
      example: 'J♠T♦8♣',
      texture: 'wet',
      rangeAdvantage: 'Mixto, ligeramente al defensor: hay muchos straight draws y '
          'two-pair posibles. El agresor tiene overpairs y broadways pero el board '
          'es muy dinámico.',
      cbetPlan: 'C-bet selectiva (~50%), sizing ⅔. Apuesta valor + proyectos '
          'fuertes; checkea overpairs marginales para controlar. El board pega a '
          'ambos rangos: no sobre-apuestes.',
      turnDynamics: 'Q, 9, 7 completan straights. Equity muy volátil. Las manos '
          'hechas medias se devalúan rápido; los proyectos cobran botes grandes.',
      wetness: 0.78,
    ),
    BoardArchetype(
      id: 'broadway_dry',
      title: 'Broadway seco',
      example: 'K♦Q♠5♣',
      texture: 'dry',
      rangeAdvantage: 'Ventaja del agresor: más KQ, KK, QQ, AK, AQ. El defensor '
          'tiene algunos Qx/Kx pero llega capado.',
      cbetPlan: 'C-bet ⅓-½, frecuencia alta. Tu rango de broadways conecta de '
          'sobra. Buen board para apostar barato con todo tu rango.',
      turnDynamics: 'Un A favorece a ambos pero más a ti; un J trae draws de '
          'straight. Cartas bajas no cambian nada: sigue presionando.',
      wetness: 0.20,
    ),
    BoardArchetype(
      id: 'low_disconnected',
      title: 'Bajo desconectado',
      example: '9♦5♣2♥',
      texture: 'dry',
      rangeAdvantage: 'Ventaja del agresor por overcards y overpairs (AA-TT). El '
          'defensor pega algún 9x/par bajo pero su rango es débil.',
      cbetPlan: 'C-bet pequeña (⅓), frecuencia muy alta (~80%): board seco que no '
          'conecta con casi nadie. Tu rango de overcards roba el bote barato.',
      turnDynamics: 'Estático. Overcards en el turn te dan equity y mantienen la '
          'presión; el rival con 9x marginal no aguanta dos barriles.',
      wetness: 0.15,
    ),
    BoardArchetype(
      id: 'double_broadway_two_tone',
      title: 'Doble broadway dos tonos',
      example: 'A♦K♦7♣',
      texture: 'dynamic',
      rangeAdvantage: 'Fuerte ventaja del agresor: AK, AA, KK, AQ, AJ pueblan su '
          'rango. Nut advantage marcada (sets de A/K). El diamante añade humedad.',
      cbetPlan: 'C-bet ½-⅔ con frecuencia alta. Tienes ventaja de rango y nueces; '
          'el flush draw justifica subir el sizing. Excelente board para barrelear.',
      turnDynamics: 'Un diamante completa color (frena con manos medias). '
          'Broadways siguen favoreciéndote. Overbets de río con tus sets/AK por nut '
          'advantage.',
      wetness: 0.50,
    ),
    BoardArchetype(
      id: 'trips_board',
      title: 'Trío en el board',
      example: '7♣7♦7♠',
      texture: 'paired',
      rangeAdvantage: 'Decidido por kickers y overpairs. El que tiene el A o un '
          'overpair (88+) domina. Rangos muy comprimidos.',
      cbetPlan: 'C-bet pequeña, frecuencia media-alta. El juego es de kicker y '
          'fold equity: un A alto o un overpair apuestan por valor fino; faroles '
          'con buenos blockers presionan rangos capados.',
      turnDynamics: 'Muy estático. La cuarta carta rara vez cambia algo salvo que '
          'empareje al rival. Triple barrel con overpairs creíble.',
      wetness: 0.08,
    ),
  ];

  /// Find an archetype by id.
  static BoardArchetype? byId(String id) {
    for (final a in archetypes) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Archetypes filtered by texture family.
  static List<BoardArchetype> byTexture(String texture) =>
      archetypes.where((a) => a.texture == texture).toList();

  /// Returns the closest archetype to a given runtime wetness value — lets the
  /// analysis layer attach human coaching to an arbitrary flop.
  static BoardArchetype closestByWetness(double wetness,
      {bool? paired, bool? monotone}) {
    Iterable<BoardArchetype> pool = archetypes;
    if (paired == true) {
      pool = archetypes.where((a) => a.texture == 'paired');
    } else if (monotone == true) {
      pool = archetypes.where((a) => a.texture == 'monotone');
    }
    if (pool.isEmpty) pool = archetypes;
    BoardArchetype best = pool.first;
    double bestDiff = (best.wetness - wetness).abs();
    for (final a in pool) {
      final d = (a.wetness - wetness).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = a;
      }
    }
    return best;
  }

  static List<Map<String, dynamic>> exportJson() =>
      archetypes.map((a) => a.toJson()).toList();
}
