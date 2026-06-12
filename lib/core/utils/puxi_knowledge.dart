import '../i18n/i18n.dart';

/// Offline poker fundamentals knowledge base for the "el Puxi" chatbot.
/// Each topic has trigger keywords (any language) and an answer per locale
/// (es/en filled; other locales fall back to en). Poker jargon stays in
/// English everywhere.
class PuxiTopic {
  final String id;
  final String title; // shown as a suggestion chip (localized via I18n key)
  final List<String> keywords;
  final Map<String, String> answer;
  const PuxiTopic({required this.id, required this.title, required this.keywords, required this.answer});

  String get localizedAnswer => answer[I18n.locale] ?? answer['en'] ?? answer['es']!;
}

class PuxiKnowledge {
  static const List<PuxiTopic> topics = [
    PuxiTopic(
      id: 'equity',
      title: 'Equity',
      keywords: ['equity', 'equidad', 'porcentaje', 'probabilidad de ganar', 'chance'],
      answer: {
        'es': 'La equity es el % de veces que ganarías el bote si la mano llegara al showdown ahora mismo contra el rango del rival. Ej: AKs en un flop A♠7♦2♣ tiene ~85% de equity contra un rango amplio. Se compara con las pot odds: si tu equity > pot odds que te dan, pagar es +EV. En el Simulador puedes calcular la tuya carta a carta.',
        'en': 'Equity is the % of the time you would win the pot if the hand went to showdown right now against villain\'s range. E.g. AKs on A♠7♦2♣ has ~85% equity vs a wide range. You compare it to your pot odds: if equity > the pot odds offered, calling is +EV. Use the Simulator to compute yours street by street.',
      },
    ),
    PuxiTopic(
      id: 'potodds',
      title: 'Pot Odds',
      keywords: ['pot odds', 'odds', 'precio', 'cuanto pagar', 'rentable pagar'],
      answer: {
        'es': 'Las pot odds son el precio que te dan para pagar: call / (bote + call). Si el bote es \$100 y te apuestan \$50, pagas \$50 para ganar \$150 → necesitas ganar 50/200 = 25% de equity para que el call sea rentable. Regla rápida: apuesta de ½ bote = necesitas 25%, apuesta de bote = necesitas 33%.',
        'en': 'Pot odds are the price you get to call: call / (pot + call). If the pot is \$100 and you face a \$50 bet, you risk \$50 to win \$150 → you need 50/200 = 25% equity for the call to be profitable. Quick rule: ½-pot bet = need 25%, full-pot bet = need 33%.',
      },
    ),
    PuxiTopic(
      id: 'mdf',
      title: 'MDF',
      keywords: ['mdf', 'minimum defense', 'defensa minima', 'cuanto defender', 'frecuencia de defensa'],
      answer: {
        'es': 'MDF (Minimum Defense Frequency) = bote / (bote + apuesta). Es el % MÍNIMO de tu rango que debes defender (call o raise) para que el rival no pueda farolear con cualquier carta de forma rentable. Ej: te apuestan ½ bote → MDF = 100/150 = 67%, así que solo puedes foldear el 33%. Si foldeas de más, te explotan con faroles.',
        'en': 'MDF (Minimum Defense Frequency) = pot / (pot + bet). It is the MINIMUM % of your range you must defend (call or raise) so villain can\'t profitably bluff any two cards. E.g. facing a ½-pot bet → MDF = 100/150 = 67%, so you may only fold 33%. Over-fold and you get exploited by bluffs.',
      },
    ),
    PuxiTopic(
      id: 'alpha',
      title: 'Alpha (faroles)',
      keywords: ['alpha', 'farol rentable', 'bluff rentable', 'cuanto tiene que foldear', 'break even bluff'],
      answer: {
        'es': 'Alpha = apuesta / (bote + apuesta). Es el % de veces que el rival debe foldear para que tu farol con 0% de equity sea rentable al instante. Ej: apuestas el bote → alpha = 100/200 = 50%, necesitas que foldee la mitad. Apuestas ⅓ → solo necesitas 25% de folds. Por eso los faroles pequeños necesitan menos folds.',
        'en': 'Alpha = bet / (pot + bet). It is the % of the time villain must fold for your 0%-equity bluff to break even immediately. E.g. you bet pot → alpha = 100/200 = 50%, you need folds half the time. Bet ⅓ → you only need 25% folds. That\'s why small bluffs need fewer folds.',
      },
    ),
    PuxiTopic(
      id: 'spr',
      title: 'SPR',
      keywords: ['spr', 'stack to pot', 'compromiso', 'committed', 'stack pot ratio'],
      answer: {
        'es': 'SPR (Stack-to-Pot Ratio) = stack efectivo / bote. Mide cuán comprometido estás. SPR bajo (<3): con top pair o mejor ya estás casi obligado a meter las fichas; no hay sitio para foldear. SPR alto (>8): juega con más cautela, puedes maniobrar en varias calles y los proyectos/implied odds valen más. Planifica el tamaño del bote preflop pensando en el SPR que quieres postflop.',
        'en': 'SPR (Stack-to-Pot Ratio) = effective stack / pot. It measures commitment. Low SPR (<3): with top pair or better you\'re basically pot-committed; no room to fold. High SPR (>8): play more cautiously, you can maneuver across streets and draws/implied odds are worth more. Plan your preflop pot size around the postflop SPR you want.',
      },
    ),
    PuxiTopic(
      id: 'blockers',
      title: 'Blockers',
      keywords: ['blocker', 'bloqueador', 'card removal', 'bloqueo', 'combinatoria'],
      answer: {
        'es': 'Un blocker es una carta tuya que reduce las combinaciones fuertes del rival. Ej: en un board con color de picas, tener el A♠ bloquea el nut flush → eres un farol ideal porque el rival tiene menos nuts y tú no tienes showdown. Los mejores faroles llevan blockers de las manos que te pagarían. También sirve para 4-bet bluff con Axs (el As bloquea AA y AK).',
        'en': 'A blocker is a card you hold that removes strong combos from villain\'s range. E.g. on a spade-flush board, holding the A♠ blocks the nut flush → you\'re an ideal bluff because villain has fewer nuts and you have no showdown value. The best bluffs hold blockers to the hands that would call. Also key for 4-bet bluffing with Axs (the Ace blocks AA and AK).',
      },
    ),
    PuxiTopic(
      id: 'ranges',
      title: 'Rangos',
      keywords: ['rango', 'range', 'que tiene', 'manos posibles', 'range vs range'],
      answer: {
        'es': 'No juegas contra UNA mano, juegas contra el RANGO completo del rival: todas las manos con las que llegaría a esta situación. Piensa en frecuencias, no en certezas. En cada calle el rango se estrecha según las acciones: si subió UTG y 3-beteó, su rango es premium (QQ+, AK). Construye tu juego para que tu rango entero gane equity en cada board, no una mano concreta.',
        'en': 'You don\'t play against ONE hand, you play against villain\'s entire RANGE: all the hands they\'d take this line with. Think frequencies, not certainties. Each street the range narrows by the actions: if they opened UTG and 3-bet, the range is premium (QQ+, AK). Build your play so your whole range has equity on each board, not one specific hand.',
      },
    ),
    PuxiTopic(
      id: 'position',
      title: 'Posición',
      keywords: ['posicion', 'position', 'btn', 'boton', 'utg', 'in position', 'ip', 'oop'],
      answer: {
        'es': 'La posición es información: actuar el último (BTN) te deja ver lo que hacen los demás antes de decidir. Por eso abres MÁS manos cuanto más cerca del botón (UTG tight, BTN loose). En posición puedes controlar el tamaño del bote, robar más y farolear mejor. Fuera de posición (OOP) juega más cerrado y usa check-raises. Mira las tablas preflop: cada asiento tiene su rango.',
        'en': 'Position is information: acting last (BTN) lets you see what everyone does before you decide. That\'s why you open MORE hands the closer you are to the button (UTG tight, BTN loose). In position you control pot size, steal more and bluff better. Out of position (OOP) play tighter and use check-raises. Check the preflop charts: each seat has its own range.',
      },
    ),
    PuxiTopic(
      id: 'cbet',
      title: 'C-Bet',
      keywords: ['cbet', 'c-bet', 'continuation', 'apuesta de continuacion', 'continuar apostando'],
      answer: {
        'es': 'La c-bet (continuation bet) es apostar el flop tras haber subido preflop, manteniendo la iniciativa. Apuesta MÁS y pequeño (⅓) en boards secos que favorecen tu rango (A72 rainbow). Frena en boards húmedos y conectados (987 con color) donde el rival conecta más: ahí check-call o check-raise. No dispares por inercia: la textura manda.',
        'en': 'A c-bet (continuation bet) is betting the flop after raising preflop, keeping the initiative. Bet MORE and small (⅓) on dry boards that favor your range (A72 rainbow). Slow down on wet, connected boards (987 with a flush draw) where villain connects more: check-call or check-raise there. Don\'t fire on autopilot — texture rules.',
      },
    ),
    PuxiTopic(
      id: 'threebet',
      title: '3-Bet',
      keywords: ['3bet', '3-bet', 'tres bet', 'resubir', 'resubida', 'reraise'],
      answer: {
        'es': 'Un 3-bet es la primera resubida sobre una apertura. Un rango de 3-bet equilibrado es POLARIZADO: manos de valor (QQ+, AK) MÁS faroles con blockers (A5s-A2s, el As bloquea AA/AK). Objetivo ~8-12% en 6-Max. Si solo 3-beteas valor, te leen como un libro y foldean. Si abusas, te pagan y te quedas sin dobles barriles. Defiende tus ciegas 3-beteando vs robos del BTN.',
        'en': 'A 3-bet is the first re-raise over an open. A balanced 3-bet range is POLARIZED: value hands (QQ+, AK) PLUS blocker bluffs (A5s-A2s, the Ace blocks AA/AK). Target ~8-12% in 6-Max. If you only 3-bet value, you\'re an open book and they fold. If you overdo it, they call and you run out of barrels. Defend your blinds by 3-betting vs BTN steals.',
      },
    ),
    PuxiTopic(
      id: 'semibluff',
      title: 'Semi-bluff',
      keywords: ['semibluff', 'semi-bluff', 'semifarol', 'proyecto apostar', 'draw bet'],
      answer: {
        'es': 'Un semi-bluff es apostar/subir con un proyecto (flush draw, OESD) que aún no es la mejor mano pero puede mejorar. Ganas de DOS formas: cuando el rival foldea ya, o cuando ligas el proyecto. Por eso es mejor que pagar pasivo: sumas fold equity a tu equity real. Ej: con flush draw + overcards en el flop, un check-raise mete muchísima presión.',
        'en': 'A semi-bluff is betting/raising with a draw (flush draw, OESD) that isn\'t the best hand yet but can improve. You win TWO ways: when villain folds now, or when you hit your draw. That\'s why it beats a passive call: you add fold equity to your real equity. E.g. with a flush draw + overcards on the flop, a check-raise applies huge pressure.',
      },
    ),
    PuxiTopic(
      id: 'potcontrol',
      title: 'Pot Control',
      keywords: ['pot control', 'controlar bote', 'pareja media', 'checkear', 'pot management'],
      answer: {
        'es': 'Pot control es mantener el bote pequeño con manos de fuerza media (top pair kicker flojo, pares medios) para no inflar un bote que no quieres jugar grande. Se hace checkeando una calle o apostando pequeño (⅓). Evita el clásico error de pagar 3 calles grandes con un par medio. Antonio es el maestro: extrae valor milimétrico sin comprometerse.',
        'en': 'Pot control is keeping the pot small with medium-strength hands (weak-kicker top pair, middle pairs) so you don\'t bloat a pot you don\'t want to play big. You do it by checking a street or betting small (⅓). Avoids the classic mistake of calling 3 big streets with a medium pair. Antonio is the master: extracts surgical value without committing.',
      },
    ),
    PuxiTopic(
      id: 'tilt',
      title: 'Tilt',
      keywords: ['tilt', 'frustracion', 'emocional', 'mental', 'rabia'],
      answer: {
        'es': 'El tilt es jugar mal por frustración tras una mala racha (un bad beat, perder un bote grande). Te lleva a abrir rangos, farolear sin sentido y pagar por orgullo. El mejor jugador no es el que nunca se enfada, sino el que se levanta de la mesa antes de regalar fichas. Regla: si notas que quieres "recuperar ya", cierra la sesión. El EV se gana a largo plazo.',
        'en': 'Tilt is playing badly out of frustration after a bad run (a bad beat, losing a big pot). It makes you widen ranges, bluff senselessly and call out of ego. The best player isn\'t the one who never gets angry, but the one who leaves the table before donating chips. Rule: if you feel the urge to "win it back now", end the session. EV is won in the long run.',
      },
    ),
    PuxiTopic(
      id: 'bankroll',
      title: 'Bankroll',
      keywords: ['bankroll', 'banca', 'gestion dinero', 'cuanto arriesgar', 'money management'],
      answer: {
        'es': 'El bankroll es el dinero dedicado solo a jugar, separado de tu vida. La gestión de banca evita que la varianza te arruine: en cash NL la regla típica es tener 20-40 buy-ins del nivel que juegas. Nunca te sientes con todo tu dinero en una mesa. En iPT cada buy-in son \$200 exactos; tu bankroll absorbe los altibajos para que sobrevivas a las malas rachas.',
        'en': 'Your bankroll is money dedicated only to playing, separate from your life. Bankroll management keeps variance from busting you: in NL cash the typical rule is 20-40 buy-ins for your stake. Never sit with all your money at one table. In iPT each buy-in is exactly \$200; your bankroll absorbs the swings so you survive the downswings.',
      },
    ),
    PuxiTopic(
      id: 'rangeadv',
      title: 'Ventaja de rango',
      keywords: ['ventaja de rango', 'range advantage', 'nut advantage', 'overbet', 'quien gana el board'],
      answer: {
        'es': 'Ventaja de rango: cuando tu rango entero conecta mejor con el board que el del rival, puedes apostar con MÁS frecuencia. Ventaja de nueces (nut advantage): cuando solo TÚ puedes tener las manos máximas (escaleras, sets) que el rival no, lo que te permite overbets (apostar más que el bote). Ej: en A-K-x el que abrió tiene ventaja de rango y puede c-betear casi siempre.',
        'en': 'Range advantage: when your entire range connects better with the board than villain\'s, you can bet with HIGHER frequency. Nut advantage: when only YOU can hold the top hands (straights, sets) villain can\'t, which unlocks overbets (betting more than the pot). E.g. on A-K-x the preflop raiser has range advantage and can c-bet almost always.',
      },
    ),
    PuxiTopic(
      id: 'checkraise',
      title: 'Check-Raise',
      keywords: ['check raise', 'checkraise', 'pasar y subir', 'check-raise'],
      answer: {
        'es': 'Check-raise: pasas con la intención de subir cuando el rival apuesta. Es una de las líneas más potentes: maximiza valor con manos fuertes y mete presión brutal como farol (mejor con blockers y fold equity). Lo usas OOP para no quedar pasivo. Stephen es un experto aplicando check-raises técnicos. Cuidado: necesita un rango equilibrado o te explotan apostando menos.',
        'en': 'Check-raise: you check intending to raise when villain bets. One of the most powerful lines: maximizes value with strong hands and applies brutal pressure as a bluff (best with blockers and fold equity). Use it OOP to avoid playing passively. Stephen is an expert at technical check-raises. Careful: it needs a balanced range or they exploit you by betting smaller.',
      },
    ),
    PuxiTopic(
      id: 'showdown',
      title: 'El river y el showdown',
      keywords: ['river', 'showdown', 'ultima carta', 'quinta carta', 'se acaba la mano', 'cinco cartas'],
      answer: {
        'es': 'El river es la 5ª y ÚLTIMA carta comunitaria. Después solo queda la última ronda de apuestas y el showdown: ya no hay más cartas ni más calles, así que en el river no hay implied odds ni proyectos — o tienes la mano hecha o faroleas/foldeas. Tu mano final son las 5 mejores cartas entre tus 2 + las 5 del board. Si hay doble pareja, la 5ª carta (kicker) decide; solo es empate si ambos comparten exactamente las 5.',
        'en': 'The river is the 5th and FINAL community card. After it there\'s only the last betting round and showdown: no more cards, no more streets, so on the river there are no implied odds or draws — you either have it made or you bluff/fold. Your final hand is the best 5 cards out of your 2 + the 5 on the board. With two pair, the 5th card (kicker) decides; it\'s only a tie if both share the exact same 5.',
      },
    ),
  ];

  /// Matches a free-text question to the best topic by keyword overlap.
  static PuxiTopic? match(String query) {
    final q = query.toLowerCase();
    PuxiTopic? best;
    int bestScore = 0;
    for (final t in topics) {
      int score = 0;
      for (final k in t.keywords) {
        if (q.contains(k)) score += k.length; // longer keyword = stronger match
      }
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }
    return bestScore > 0 ? best : null;
  }
}
