import '../../data/gto/spot_record.dart';
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
    PuxiTopic(
      id: 'betsizing',
      title: 'Bet Sizing',
      keywords: ['bet sizing', 'tamaño de apuesta', 'cuanto apostar', 'sizing', 'que tamaño'],
      answer: {
        'es': 'El tamaño no es al azar: comunica tu rango. Apuestas PEQUEÑAS (⅓ bote) en boards secos donde tienes ventaja de rango y quieres apostar muchas manos baratas. Apuestas GRANDES o overbets en boards donde tienes ventaja de nueces (solo tú tienes las máximas). Regla: rango amplio → sizing pequeño; rango polarizado (valor + farol) → sizing grande. El mismo sizing para valor y farol es lo que te hace imposible de leer.',
        'en': 'Size isn\'t random: it communicates your range. Bet SMALL (⅓ pot) on dry boards where you have range advantage and want to bet many hands cheaply. Bet BIG or overbet on boards where you have nut advantage (only you hold the top hands). Rule: wide range → small sizing; polarized range (value + bluff) → big sizing. Using the same size for value and bluffs is what makes you unreadable.',
      },
    ),
    PuxiTopic(
      id: 'rangetypes',
      title: 'Rangos: polarizado vs lineal',
      keywords: ['polarizado', 'lineal', 'condensado', 'merged', 'tipo de rango', 'rango polar'],
      answer: {
        'es': 'POLARIZADO = solo nueces y faroles, sin medias (para apuestas grandes/overbets en river). LINEAL/MERGED = las mejores X manos seguidas, incluyendo valor medio (para apuestas pequeñas e iso-raises). CONDENSADO = manos medias y proyectos, sin monstruos ni aire total (típico de quien iguala en vez de subir). Identifica qué rango representa tu línea: una apuesta enorme polarizada con manos medias es un error clásico.',
        'en': 'POLARIZED = only nuts and bluffs, no medium hands (for big bets/overbets on the river). LINEAR/MERGED = the best X hands in a row, including medium value (for small bets and iso-raises). CONDENSED = medium hands and draws, no monsters or pure air (typical of someone who calls instead of raising). Identify which range your line represents: a huge polarized bet with medium hands is a classic mistake.',
      },
    ),
    PuxiTopic(
      id: 'barrels',
      title: 'Double y triple barrel',
      keywords: ['barrel', 'double barrel', 'triple barrel', 'seguir apostando', 'segundo disparo', 'tercera bala'],
      answer: {
        'es': 'Barrelear es seguir apostando en calles siguientes tras la c-bet. Double barrel (turn): dispara cuando la carta del turn MEJORA tu rango o empeora el del rival (scare cards: overcards, cartas de proyecto que completan). Triple barrel (river): solo con valor real o faroles con blockers — sin blockers, el triple barrel es quemar dinero. Pregúntate siempre: ¿esta carta ayuda más a mi rango o al suyo? Si te ayuda a ti, sigue presionando.',
        'en': 'Barreling is continuing to bet on later streets after the c-bet. Double barrel (turn): fire when the turn card IMPROVES your range or worsens villain\'s (scare cards: overcards, draw-completing cards). Triple barrel (river): only with real value or bluffs that hold blockers — without blockers, the triple barrel just burns money. Always ask: does this card help my range or theirs more? If it helps you, keep applying pressure.',
      },
    ),
    PuxiTopic(
      id: 'donk',
      title: 'Donk bet',
      keywords: ['donk', 'donk bet', 'apostar de cara', 'salir apostando', 'liderar'],
      answer: {
        'es': 'Donk bet = apostar de cara (OOP) en una calle nueva contra quien fue el agresor previo, quitándole la iniciativa. Normalmente es un error (rompes tu rango de check-call/check-raise), pero el GTO la justifica en boards muy específicos que favorecen MÁS a tu rango que al del agresor — ej: el que defiende la BB en un board bajo y conectado (754) que pega a su rango de calls pero no al del que abrió de UTG. Úsala con cuidado y plan.',
        'en': 'Donk bet = leading out (OOP) into the previous aggressor on a new street, taking away their initiative. Usually a mistake (it breaks your check-call/check-raise range), but GTO justifies it on very specific boards that favor YOUR range more than the aggressor\'s — e.g. the BB defender on a low connected board (754) that smashes their calling range but not the UTG opener\'s. Use it carefully and with a plan.',
      },
    ),
    PuxiTopic(
      id: 'blockerbet',
      title: 'Blocker bet',
      keywords: ['blocker bet', 'apuesta de bloqueo', 'apuesta pequeña river', 'bloquear apuesta'],
      answer: {
        'es': 'Una blocker bet (o blocking bet) es una apuesta PEQUEÑA (10-25% bote) que haces OOP en el river con una mano media para "ponerte tú el precio": ves la mano barato y evitas que el rival te haga una apuesta gigante que no podrías pagar cómodo. Funciona contra rivales que rara vez suben tu apuesta pequeña como farol. Cuidado: contra agresivos te pueden subir (raise) y ponerte en un aprieto.',
        'en': 'A blocker bet (or blocking bet) is a SMALL bet (10-25% pot) you make OOP on the river with a medium hand to "set your own price": you get to showdown cheaply and avoid villain making a huge bet you couldn\'t comfortably call. It works against opponents who rarely raise your small bet as a bluff. Careful: aggressive players can raise it and put you in a tough spot.',
      },
    ),
    PuxiTopic(
      id: 'overbet',
      title: 'Overbet',
      keywords: ['overbet', 'sobreapuesta', 'apostar mas del bote', 'apuesta gigante'],
      answer: {
        'es': 'Un overbet es apostar MÁS que el bote (125-200%+). Solo es correcto cuando tienes VENTAJA DE NUECES: tu rango contiene las manos máximas y el del rival no. Sirve para extraer valor máximo con monstruos Y como farol polarizado con blockers (pones al rival en una decisión imposible por todo su stack). Necesita un rango bien construido: si solo overbeteas valor, foldean; si solo faroleas, te pagan. Michael y Adrián son maestros del overbet.',
        'en': 'An overbet is betting MORE than the pot (125-200%+). It\'s only correct when you have NUT ADVANTAGE: your range holds the top hands and villain\'s doesn\'t. It extracts maximum value with monsters AND works as a polarized bluff with blockers (putting villain to an impossible decision for their stack). It needs a well-built range: overbet only for value and they fold; only bluff and they call. Michael and Adrián are overbet masters.',
      },
    ),
    PuxiTopic(
      id: 'float',
      title: 'Float',
      keywords: ['float', 'flotar', 'flotar el flop', 'pagar para robar'],
      answer: {
        'es': 'Flotar es pagar una apuesta (normalmente en posición) con una mano débil o proyecto flojo, SIN intención de mejorar necesariamente, sino para robar el bote en una calle posterior cuando el rival muestre debilidad (check). Funciona contra jugadores que c-betean mucho el flop pero se rinden en el turn. Es jugar la debilidad del rival, no tus cartas. En posición es mucho más fuerte porque ves su check antes de actuar.',
        'en': 'Floating is calling a bet (usually in position) with a weak hand or weak draw, NOT necessarily intending to improve, but to steal the pot on a later street when villain shows weakness (checks). It works against players who c-bet the flop a lot but give up on the turn. You\'re playing villain\'s weakness, not your cards. In position it\'s much stronger because you see their check before acting.',
      },
    ),
    PuxiTopic(
      id: 'setmining',
      title: 'Set mining',
      keywords: ['set mining', 'set', 'parejas pequeñas', 'minar sets', 'pocket pair'],
      answer: {
        'es': 'Set mining es pagar preflop con una pareja pequeña (22-66) buscando ligar trío (set) en el flop. Como solo ligas ~1 de cada 8.5 veces (~11.8%), necesitas IMPLIED ODDS: que el stack efectivo sea grande respecto a lo que pagas. Regla práctica: paga solo si puedes ganar al menos 10-15x lo que inviertes preflop. Si los stacks son cortos (SPR bajo) o el rival no paga cuando ligas, el set mining pierde dinero. Cuando ligas, los sets son una máquina de hacer billetes.',
        'en': 'Set mining is calling preflop with a small pocket pair (22-66) hoping to flop a set. Since you only hit ~1 in 8.5 times (~11.8%), you need IMPLIED ODDS: the effective stack must be large relative to what you call. Rule of thumb: only call if you can win at least 10-15x what you invest preflop. If stacks are short (low SPR) or villain won\'t pay you off when you hit, set mining loses money. When you do hit, sets are a money-printing machine.',
      },
    ),
    PuxiTopic(
      id: 'combinatorics',
      title: 'Combinatoria y card removal',
      keywords: ['combinatoria', 'combos', 'card removal', 'remocion de cartas', 'cuantas combinaciones'],
      answer: {
        'es': 'Pensar en COMBOS, no en manos. Hay 6 combos de cada par concreto (AA), 4 combos de cada mano no emparejada suited (AKs), y 12 de cada offsuit (AKo) → 16 de AK en total. La CARD REMOVAL: tus cartas y el board reducen los combos posibles del rival. Ej: en un board K-K-x, solo quedan 1 combo de KK (cuádruple) y pocos de trips → es difícil que tenga el K. Contar combos te dice si el rival tiene más manos de valor o de farol, y decide tu call/fold.',
        'en': 'Think in COMBOS, not hands. There are 6 combos of each specific pair (AA), 4 combos of each unpaired suited hand (AKs), and 12 of each offsuit (AKo) → 16 of AK total. CARD REMOVAL: your cards and the board reduce villain\'s possible combos. E.g. on a K-K-x board, only 1 combo of KK remains and few trips → it\'s unlikely they hold the K. Counting combos tells you whether villain has more value or bluff hands, and decides your call/fold.',
      },
    ),
    PuxiTopic(
      id: 'balance',
      title: 'Balance vs explotación',
      keywords: ['balance', 'equilibrio', 'explotar', 'explotativo', 'gto vs explotativo', 'desbalanceado'],
      answer: {
        'es': 'GTO/balance = jugar un rango equilibrado (valor + faroles en la proporción correcta) que NADIE puede explotar, aunque sepa lo que haces. EXPLOTATIVO = desviarte del equilibrio para castigar un error concreto del rival, a riesgo de quedar desprotegido. Contra buenos jugadores, juega más balanceado. Contra pescados (calling stations, fit-or-fold), EXPLOTA: deja de farolear al que paga todo y farolea sin parar al que foldea de más. El dinero grande está en explotar errores.',
        'en': 'GTO/balance = playing a balanced range (value + bluffs in the right proportion) that NOBODY can exploit, even knowing what you do. EXPLOITATIVE = deviating from equilibrium to punish a specific opponent mistake, at the risk of leaving yourself unprotected. Against good players, play more balanced. Against fish (calling stations, fit-or-fold), EXPLOIT: stop bluffing the guy who calls everything and bluff relentlessly the one who over-folds. The big money is in exploiting mistakes.',
      },
    ),
    PuxiTopic(
      id: 'rivercatch',
      title: 'River: bluff catching',
      keywords: ['bluff catch', 'bluff catcher', 'pagar river', 'atrapar farol', 'pagar en river', 'cazar farol'],
      answer: {
        'es': 'En el river ya no hay proyectos: tu mano media solo gana si pagas un farol. Para decidir, compara las pot odds con cuántos faroles tiene el rival en su rango: si te da 2:1 (necesitas 33%), pagar es correcto si crees que farolea más de 1 de cada 3 veces. Usa tus BLOCKERS: si tu carta bloquea sus combos de valor, hay más faroles en su rango → paga. La MDF te dice el mínimo que debes defender para no ser explotado. No pagues por "curiosidad", paga por matemática.',
        'en': 'On the river there are no more draws: your medium hand only wins if you call a bluff. To decide, compare the pot odds with how many bluffs villain has in range: if you\'re getting 2:1 (need 33%), calling is correct if you think they bluff more than 1 in 3 times. Use your BLOCKERS: if your card blocks their value combos, there are relatively more bluffs in range → call. MDF tells you the minimum you must defend to avoid being exploited. Don\'t call out of curiosity, call by math.',
      },
    ),
    PuxiTopic(
      id: 'initiative',
      title: 'Iniciativa y agresión',
      keywords: ['iniciativa', 'agresion', 'agresivo', 'initiative', 'quien apuesta gana', 'ser agresivo'],
      answer: {
        'es': 'La iniciativa es tenerla tú: ser el que apuesta y obliga al rival a tomar decisiones. Apostar gana de dos formas (el rival foldea, o llegas al showdown con la mejor mano); pagar solo gana de una. Por eso el póker ganador es AGRESIVO: el TAG (tight-agresivo) y el LAG seleccionan bien sus manos pero las juegan con fuerza. El factor de agresión (apuestas+subidas / igualadas) de un buen reg es alto. Pagar pasivo es de pescado: o subes con un plan, o foldeas.',
        'en': 'Initiative is having it: being the one who bets and forces villain to make decisions. Betting wins two ways (villain folds, or you reach showdown with the best hand); calling only wins one. That\'s why winning poker is AGGRESSIVE: TAG (tight-aggressive) and LAG players select their hands well but play them with force. A good reg\'s aggression factor (bets+raises / calls) is high. Passive calling is for fish: either raise with a plan, or fold.',
      },
    ),
    PuxiTopic(
      id: 'rangemath',
      title: 'Matemática de rangos',
      keywords: ['cuantas manos', 'porcentaje de rango', 'combos totales', 'matematica de rango', 'rango porcentaje', 'cuantos combos'],
      answer: {
        'es': 'Hay 1.326 combos posibles de mano inicial. Las parejas: 6 combos cada una (78 en total = 6%). Suited: 4 combos (312 = 24%). Offsuit: 12 combos (936 = 70%). Para traducir un rango a %: cuenta combos y divide entre 1.326. Ej: "QQ+, AK" = 6+6+6 (QQ,KK,AA) + 16 (AK) = 34 combos = 2,6% del total, un rango ULTRA premium. Un open del BTN ~45% son ~597 combos. Pensar en combos te da precisión que el "creo que tiene…" jamás te dará.',
        'en': 'There are 1,326 possible starting-hand combos. Pairs: 6 combos each (78 total = 6%). Suited: 4 combos (312 = 24%). Offsuit: 12 combos (936 = 70%). To turn a range into a %: count combos and divide by 1,326. E.g. "QQ+, AK" = 6+6+6 (QQ,KK,AA) + 16 (AK) = 34 combos = 2.6% of all hands, an ULTRA premium range. A BTN open of ~45% is ~597 combos. Thinking in combos gives precision that "I think they have…" never will.',
      },
    ),
    PuxiTopic(
      id: 'realization',
      title: 'Realización de equity (R)',
      keywords: ['realizacion', 'realization', 'realizar equity', 'equity realization', 'R factor'],
      answer: {
        'es': 'Tu equity en bruto NO es lo que ganas: la realizas según puedas LLEGAR al showdown. El factor R: en posición realizas MÁS del 100% de tu equity (R>1) porque controlas el bote y robas; fuera de posición realizas MENOS (R<0,9). Por eso 65s en el BTN vale más que su equity cruda, y la misma mano en UTG vale menos. Manos con buena realización: suited (ligan color y juegan fácil), conectores en posición. Mala realización: offsuit OOP que se foldean cuando fallan.',
        'en': 'Your raw equity is NOT what you win: you REALIZE it based on how often you get to showdown. The R factor: in position you realize MORE than 100% of your equity (R>1) because you control the pot and steal; out of position you realize LESS (R<0.9). That\'s why 65s on the BTN is worth more than its raw equity, and the same hand UTG is worth less. Good realization: suited hands (make flushes, play easily), connectors in position. Bad realization: offsuit OOP that folds when it misses.',
      },
    ),
    PuxiTopic(
      id: 'fourbet',
      title: '4-Bet',
      keywords: ['4bet', '4-bet', 'cuatro bet', 're-resubir', 'cuarta apuesta'],
      answer: {
        'es': 'Un 4-bet es la resubida sobre un 3-bet. Rango polarizado: VALOR (QQ+, AK) + FAROLES con blockers (A5s-A2s; el As bloquea AA/AK del rival, reduciendo sus combos de continuación). Tamaño: ~2,2-2,5x el 3-bet IP, algo más OOP. Contra un 3-bet bluff frecuente, 4-betea más ligero. Contra nits que solo 3-betean QQ+, foldea hasta AK y no 4-betees de farol: no tienen nada que foldear. El 4-bet bluff vive de los blockers.',
        'en': 'A 4-bet is the re-raise over a 3-bet. Polarized range: VALUE (QQ+, AK) + BLUFFS with blockers (A5s-A2s; the Ace blocks villain\'s AA/AK, cutting their continue combos). Sizing: ~2.2-2.5x the 3-bet IP, a bit more OOP. Against a frequent 3-bet bluffer, 4-bet lighter. Against nits who only 3-bet QQ+, fold even AK and don\'t 4-bet bluff: they have nothing to fold. The 4-bet bluff lives on blockers.',
      },
    ),
    PuxiTopic(
      id: 'squeeze',
      title: 'Squeeze',
      keywords: ['squeeze', 'apretar', 'resubir con caller', '3bet con call', 'squeeze play'],
      answer: {
        'es': 'Squeeze = 3-betear cuando hubo una apertura Y uno o más callers. La presión es brutal: el que abrió aún puede tener un 4-bet, y los callers casi nunca aguantan (entraron con manos de flat). Sube MÁS que un 3-bet normal (+1 tamaño por cada caller, ~4-5x). Buen rango: valor fuerte + suited con blockers. La posición de los callers importa: contra calls de jugadores tight, foldean más; contra fish loose, más valor y menos farol.',
        'en': 'Squeeze = 3-betting when there was an open AND one or more callers. The pressure is brutal: the opener can still have a 4-bet, and the callers rarely continue (they entered with flatting hands). Size BIGGER than a normal 3-bet (+1 sizing per caller, ~4-5x). Good range: strong value + suited hands with blockers. Caller position matters: against tight callers they fold more; against loose fish, more value and fewer bluffs.',
      },
    ),
    PuxiTopic(
      id: 'isolation',
      title: 'Aislamiento (iso-raise)',
      keywords: ['aislar', 'isolation', 'iso raise', 'subir al limp', 'isolar limper'],
      answer: {
        'es': 'Iso-raise = subir sobre un limp para AISLAR al limper (normalmente un fish) y jugar el bote contra él en posición. Sube más que un open normal (+1bb por limper) para que no entren más. Amplía tu rango de valor: el limper suele tener un rango débil y capped, así que QJ, KT, Axs ganan muchísimo. El objetivo no es robar las ciegas, es jugar botes postflop con ventaja contra el jugador más débil de la mesa.',
        'en': 'Iso-raise = raising over a limp to ISOLATE the limper (usually a fish) and play the pot against them in position. Raise bigger than a normal open (+1bb per limper) so others don\'t come along. Widen your value range: the limper usually has a weak, capped range, so QJ, KT, Axs print money. The goal isn\'t to steal the blinds, it\'s to play postflop pots with an edge against the weakest player at the table.',
      },
    ),
    PuxiTopic(
      id: 'protection',
      title: 'Protección y negación de equity',
      keywords: ['proteccion', 'protection', 'negar equity', 'equity denial', 'proteger mano', 'apostar para proteger'],
      answer: {
        'es': 'Apostar no es solo por valor o farol: también para NEGAR EQUITY. Con top pair en un board húmedo (proyectos de color y escalera), apuestas para que el rival no vea cartas gratis con su 35% de equity de proyecto. Cada vez que le haces foldear una mano que tenía outs, ganas EV. Por eso en boards mojados se apuesta más grande y más a menudo con manos vulnerables: las nuts pueden esperar, las manos medias necesitan cobrar y proteger YA.',
        'en': 'Betting isn\'t only for value or as a bluff: it also DENIES EQUITY. With top pair on a wet board (flush and straight draws), you bet so villain doesn\'t see free cards with their 35% draw equity. Every time you make them fold a hand that had outs, you gain EV. That\'s why on wet boards you bet bigger and more often with vulnerable hands: the nuts can wait, medium hands need to charge and protect NOW.',
      },
    ),
    PuxiTopic(
      id: 'multiway',
      title: 'Botes multiway',
      keywords: ['multiway', 'varios jugadores', 'bote multiple', 'tres jugadores', 'multi way'],
      answer: {
        'es': 'En botes con 3+ jugadores, todo cambia: los faroles pierden valor (alguien siempre puede pagar) y las manos marginales valen menos (necesitas más fuerza para apostar de valor). Regla: aprieta tu rango, farolea MUCHO menos y apuesta de valor más fuerte (top pair débil se convierte en bluff-catcher). La equity se reparte: tu 60% heads-up puede ser 40% contra dos rangos. Juega más directo, menos creativo. Las nuts valen oro; las manos medias, cautela.',
        'en': 'In pots with 3+ players everything changes: bluffs lose value (someone can always call) and marginal hands are worth less (you need more strength to value bet). Rule: tighten your range, bluff MUCH less and value bet stronger (weak top pair becomes a bluff-catcher). Equity splits: your 60% heads-up can be 40% against two ranges. Play more straightforward, less creative. The nuts are gold; medium hands, caution.',
      },
    ),
    PuxiTopic(
      id: 'commitment',
      title: 'Umbral de compromiso (stack-off)',
      keywords: ['stack off', 'comprometer stack', 'commitment', 'meter todo', 'umbral de compromiso', 'cuando ir all in'],
      answer: {
        'es': 'El umbral de stack-off es el punto donde tu mano vale para meter TODAS las fichas. Depende del SPR: con SPR 1-2, top pair buen kicker ya es suficiente para ir all-in; con SPR 6+, necesitas dos pares o mejor. Antes de comprometerte pregúntate: ¿qué rango me paga peor que yo? Si te pagan solo manos que te ganan (sets, dos pares) cuando vas con top pair, NO te comprometas. El SPR planificado preflop decide qué manos pueden jugar por stacks.',
        'en': 'The stack-off threshold is the point where your hand is worth getting ALL the chips in. It depends on SPR: at SPR 1-2, top pair good kicker is enough to get it in; at SPR 6+, you need two pair or better. Before committing ask: what range calls me that I beat? If only hands that beat you (sets, two pair) call when you have top pair, do NOT commit. The SPR you planned preflop decides which hands can play for stacks.',
      },
    ),
    PuxiTopic(
      id: 'leveling',
      title: 'Niveles y metajuego',
      keywords: ['niveles', 'leveling', 'metajuego', 'metagame', 'nivel de pensamiento', 'que piensa que pienso'],
      answer: {
        'es': 'Los niveles de pensamiento: Nivel 1 = "¿qué tengo yo?". Nivel 2 = "¿qué tiene él?". Nivel 3 = "¿qué cree él que tengo yo?". Nivel 4 = "¿qué cree él que creo yo que tiene?". Contra fish (nivel 1), juega EXPLOTATIVO simple: value bet fino y no farolees. Contra regs (nivel 3+), vuelve al GTO para no ser explotado. El error es "fancy play syndrome": niveles de más contra rivales que no piensan. Ajusta tu nivel UNO por encima del rival, no más.',
        'en': 'Levels of thinking: Level 1 = "what do I have?". Level 2 = "what do they have?". Level 3 = "what do they think I have?". Level 4 = "what do they think I think they have?". Against fish (level 1), play simple EXPLOITATIVE: thin value bet and don\'t bluff. Against regs (level 3+), return to GTO so you\'re not exploited. The mistake is "fancy play syndrome": too many levels against opponents who don\'t think. Set your level ONE above your opponent, no more.',
      },
    ),
    PuxiTopic(
      id: 'coolers',
      title: 'Coolers vs errores',
      keywords: ['cooler', 'mala suerte', 'set over set', 'bad beat', 'error vs cooler', 'perder con buena mano'],
      answer: {
        'es': 'Distingue COOLER de ERROR. Cooler: pierdes todo el stack en un spot donde cualquier jugador habría hecho lo mismo (set vs set, AA vs KK all-in preflop). No es un fallo, es varianza, suéltalo. Error: pierdes fichas por una decisión -EV (pagar sin odds, farolear a un calling station). En ANALIZAR, el Puxi solo te marca los ERRORES; los coolers no cuentan contra ti. Confundir ambos lleva al tilt: no te castigues por coolers ni te excuses los errores como "mala suerte".',
        'en': 'Tell a COOLER from a MISTAKE. Cooler: you lose your stack in a spot where any player would have done the same (set vs set, AA vs KK all-in preflop). It\'s not a leak, it\'s variance, let it go. Mistake: you lose chips to a -EV decision (calling without odds, bluffing a calling station). In ANALYZE, el Puxi only flags the MISTAKES; coolers don\'t count against you. Confusing the two leads to tilt: don\'t punish yourself for coolers, and don\'t excuse mistakes as "bad luck".',
      },
    ),
    PuxiTopic(
      id: 'bluffratio',
      title: 'Ratio valor/farol',
      keywords: ['ratio valor farol', 'value to bluff', 'cuantos faroles', 'proporcion farol', 'equilibrio valor farol'],
      answer: {
        'es': 'Un rango de apuesta equilibrado lleva la proporción correcta de faroles para cada tamaño, según las odds que le das al rival. En el RIVER: apuesta de ½ bote → 2 valor : 1 farol (33% faroles). Apuesta de bote → 1:1 (50% faroles). Overbet 2x → más faroles aún. ¿Por qué? Porque le das mejores odds para pagar, así que necesitas más faroles para que su bluff-catcher quede indiferente. En flop/turn llevas MÁS faroles (aún pueden mejorar). Equilibra y serás imposible de explotar.',
        'en': 'A balanced betting range carries the right proportion of bluffs for each size, based on the odds you give villain. On the RIVER: ½-pot bet → 2 value : 1 bluff (33% bluffs). Pot bet → 1:1 (50% bluffs). 2x overbet → even more bluffs. Why? Because you give better calling odds, so you need more bluffs to keep their bluff-catcher indifferent. On flop/turn you carry MORE bluffs (they can still improve). Balance this and you\'re impossible to exploit.',
      },
    ),
    PuxiTopic(
      id: 'wetdry',
      title: 'Boards: secos, mojados y dinámicos',
      keywords: ['board seco', 'board mojado', 'textura', 'dinamico', 'estatico', 'wet dry board', 'tipo de board'],
      answer: {
        'es': 'SECO/ESTÁTICO (K72 rainbow): pocas cartas cambian el ganador; el agresor c-betea pequeño y a menudo (tiene ventaja de rango). MOJADO/DINÁMICO (T98 con dos del mismo palo): muchísimas cartas cambian todo; apuesta más grande con valor para proteger y cobrar a los proyectos, y frena tus manos medias. MONOCOLOR: cuidado, alguien puede tener color ya. EMPAREJADO (KK7): reduce los proyectos, favorece c-bets baratas. La textura decide tu sizing, tu frecuencia y a quién favorece el board.',
        'en': 'DRY/STATIC (K72 rainbow): few cards change the winner; the aggressor c-bets small and often (range advantage). WET/DYNAMIC (T98 two-tone): tons of cards change everything; bet bigger with value to protect and charge draws, and slow down your medium hands. MONOTONE: careful, someone may already have a flush. PAIRED (KK7): fewer draws, favors cheap c-bets. Texture decides your sizing, your frequency and who the board favors.',
      },
    ),

    // ── New topics (Phase 3 expansion) ─────────────────────────────────────
    PuxiTopic(
      id: 'foldequity',
      title: 'Fold equity',
      keywords: ['fold equity', 'equity de fold', 'presion', 'que porcentaje foldea', 'cuanto foldea'],
      answer: {
        'es': 'Fold equity es el valor extra que añades a tu mano cuando el rival puede foldear. EV total de una apuesta = (fold% × bote ganado) + (call% × equity en el showdown). Por eso apostar con 0% de equity puede ser rentable si el rival foldea lo suficiente (alpha). Y una mano media gana MÁS apostando que checkeando: suma fold equity a su equity real. El semi-bluff vive de la fold equity: ni necesitas ganar el showdown necesariamente.',
        'en': 'Fold equity is the extra value you add to your hand when villain can fold. Total bet EV = (fold% × pot won) + (call% × showdown equity). That\'s why betting with 0% equity can be profitable if villain folds enough (alpha). And a medium hand wins MORE by betting than checking: it adds fold equity to its real equity. The semi-bluff lives on fold equity: you don\'t even need to win the showdown.',
      },
    ),
    PuxiTopic(
      id: 'impliedodds',
      title: 'Implied odds y reverse implied odds',
      keywords: ['implied odds', 'odds implicitas', 'reverse implied', 'odds inversas', 'cuanto pago si ligo'],
      answer: {
        'es': 'IMPLIED ODDS = lo que puedes ganar en calles futuras si ligas tu proyecto, además del bote actual. Por eso pagas un precio "malo" en pot odds directas pero la mano es rentable: si ligas el straight/color, cobras stacks. REVERSE IMPLIED ODDS = cuando ligas una mano que PARECE buena pero te cuesta stacks si el rival tiene mejor: ligar el segundo color o el straight bajo contra un board emparejado. Las reverse implied odds destruyen el EV de manos dominated. Ej: TPWK (top pair weak kicker) en un board húmedo tiene malas RIO: pagas 3 calles, liegas top pair y el rival tiene TPK o mejor.',
        'en': 'IMPLIED ODDS = what you can win on future streets if you hit your draw, beyond the current pot. That\'s why you pay a "bad" immediate price but the hand is still profitable: if you hit the straight/flush, you collect stacks. REVERSE IMPLIED ODDS = when you hit a hand that LOOKS good but costs you stacks if villain has better: making the second-nut flush or the low end of a straight on a paired board. Reverse implied odds destroy EV for dominated hands. E.g. TPWK (top pair weak kicker) on a wet board has bad RIO: you pay 3 streets, you have top pair, and villain has TPK or better.',
      },
    ),
    PuxiTopic(
      id: 'delayedcbet',
      title: 'Delayed c-bet (turno)',
      keywords: ['delayed cbet', 'delayed c-bet', 'cbet turno', 'checkear flop apostar turno', 'barrear turno'],
      answer: {
        'es': 'Una delayed c-bet es checkear el flop tras haber abierto (ceder iniciativa) y apostar el turn. Se usa cuando: el flop te falló pero el turn te mejora o te da una scare card; el board es muy mojado y no quieres inflar el bote con una hand marginal; o usas el check-flop para ocultar la fuerza de tus manos fuertes. OJO: al checkear el flop, el rival intentará robar con una apuesta; necesitas un plan para esa contingencia. Es una línea potente en la BB IP defensiva.',
        'en': 'A delayed c-bet is checking the flop after opening (giving up initiative) and betting the turn. Use it when: the flop missed you but the turn improves you or gives a scare card; the board is very wet and you don\'t want to bloat the pot with a marginal hand; or you check the flop to disguise the strength of your strong hands. CAREFUL: by checking the flop, villain will try to steal with a bet; you need a plan for that contingency. It\'s a powerful line in the BB defensive spot.',
      },
    ),
    PuxiTopic(
      id: 'probebet',
      title: 'Probe bet',
      keywords: ['probe bet', 'apuesta de sondeo', 'turno checked', 'sondear turno', 'ip chequeó flop'],
      answer: {
        'es': 'Probe bet = apostar el turn fuera de posición cuando el jugador IP checkeó detrás en el flop. Al no apostar el flop, mostró debilidad: su rango está lleno de manos medias y proyectos que no pudieron c-betear. Aprovecha sondando: apuesta ½-¾ del bote con manos que quieren valor o proyectos fuertes. Funciona especialmente en boards que mejoran rangos de call (conectores, bajitas) — donde la BB puede tener sets/dos pares que el UTG no llega. No sondees con basura pura: aún puede tener manos.',
        'en': 'Probe bet = betting the turn out of position when the IP player checked back on the flop. By not betting the flop, they showed weakness: their range is full of medium hands and draws that couldn\'t c-bet. Exploit it by probing: bet ½-¾ pot with hands that want value or strong draws. Works especially on boards that improve calling ranges (connectors, low cards) — where the BB can have sets/two-pair that UTG can\'t reach. Don\'t probe with pure air: they can still have hands.',
      },
    ),
    PuxiTopic(
      id: 'thinvalue',
      title: 'Thin value (valor fino)',
      keywords: ['valor fino', 'thin value', 'value bet fino', 'apostar de valor fino', 'tres calles'],
      answer: {
        'es': 'Thin value = apostar de valor con una mano que gana al rango del rival pero solo con un margen estrecho — una sola pareja fuerte, por ejemplo. El objetivo es extraer fichas de manos peores (pares menores, kickers más débiles) que pagarían una calle o dos. La clave: no infles el bote con thin value si el rango que te puede pagar YA te bate a menudo. En el river, thin value al 30-40% del bote es potente: muchos rivales llaman con pares medios. Demasiado thin value = fuente de reverse implied odds.',
        'en': 'Thin value = betting for value with a hand that beats villain\'s range but only by a narrow margin — a single strong pair, for example. The goal is to extract chips from weaker hands (lower pairs, weaker kickers) that would call one or two streets. The key: don\'t bloat the pot with thin value if the range that can pay you already BEATS you often. On the river, thin value at 30-40% pot is powerful: many opponents call with medium pairs. Too much thin value = a source of reverse implied odds.',
      },
    ),
    PuxiTopic(
      id: 'coldcall',
      title: 'Cold call (pagar en frío)',
      keywords: ['cold call', 'pagar en frio', 'llamar dos apuestas', 'flat 3bet', 'llamar un 3bet'],
      answer: {
        'es': 'Cold call = pagar dos apuestas sin haber metido ninguna antes (ej: pagar un 3-bet cuando no abriste tú). Es diferente a defender la BB o pagar como opener. Estándares más altos: pagas 2 apuestas sin la ventaja del agresor y a menudo OOP. Requiere manos con jugabilidad excepcional (pares altos, conectores suited en posición). El principal error: cold-callear 3-bets con manos que deberían 4-betear (QQ+) o foldear (marginals). El rango de cold call está entre "demasiado bueno para foldear, demasiado débil para reraise".',
        'en': 'Cold call = calling two bets without having any money in before (e.g. calling a 3-bet when you didn\'t open). Different from defending the BB or calling as the opener. Higher standards: you pay 2 bets without the aggressor\'s edge and often OOP. Requires hands with exceptional playability (high pairs, suited connectors in position). The main mistake: cold-calling 3-bets with hands that should 4-bet (QQ+) or fold (marginals). The cold-call range sits between "too good to fold, too weak to re-raise".',
      },
    ),
    PuxiTopic(
      id: 'stackdepth',
      title: 'Stack depth y ajustes',
      keywords: ['stack profundo', 'stack corto', 'deep stack', 'short stack', 'ajuste por stack', 'profundidad de stack'],
      answer: {
        'es': 'La profundidad del stack cambia qué manos valen más. Con stacks PROFUNDOS (>150BB): los conectores suited y parejas pequeñas se revalorizan (implied odds enormes); las manos premium siguen siendo buenas pero el SPR alto requiere cautela postflop. Con stacks CORTOS (<40BB): el juego se simplifica (push/fold más a menudo); las manos de valor (AA,KK,AK) mandan, los proyectos pierden valor (no hay calles para cobrarlos). A 100BB (estándar): el equilibrio entre implied odds y valor directo es óptimo.',
        'en': 'Stack depth changes which hands are worth more. With DEEP stacks (>150BB): suited connectors and small pairs become more valuable (huge implied odds); premium hands are still good but high SPR requires postflop caution. With SHORT stacks (<40BB): play simplifies (push/fold more often); value hands (AA,KK,AK) dominate, draws lose value (no streets to collect them). At 100BB (standard): the balance between implied odds and direct value is optimal.',
      },
    ),
    PuxiTopic(
      id: 'blinddefense',
      title: 'Defensa de ciegas (BB)',
      keywords: ['defender ciega', 'bb defense', 'blind defense', 'cuanto defender bb', 'gran ciega'],
      answer: {
        'es': 'La BB tiene un descuento único: ya está en para 1BB. Contra una apertura estándar (2.5BB), llamas 1.5BB para ganar ~4BB → pot odds de ~26%, lo que obliga a defender muy amplio (MDF ≈ 55%). Estrategia: 3-betea manos premium + algunos bluffs Axs; flat manos con jugabilidad (pares, conectores, broadways medios). NO foldees de más: cada BB que regalas aquí es pérdida directa. El error clásico del BB: foldear top pair de kicker débil en flop barato por "miedo al rango del rival".',
        'en': 'The BB has a unique discount: already in for 1BB. Against a standard open (2.5BB), you call 1.5BB to win ~4BB → pot odds of ~26%, which forces very wide defense (MDF ≈ 55%). Strategy: 3-bet premium hands + some Axs bluffs; flat hands with playability (pairs, connectors, medium broadways). DON\'T over-fold: every BB you give up here is a direct loss. The classic BB mistake: folding top pair weak kicker on a cheap flop out of "fear of villain\'s range".',
      },
    ),
    PuxiTopic(
      id: 'handreading',
      title: 'Hand reading (lectura de mano)',
      keywords: ['lectura de mano', 'hand reading', 'que tiene el rival', 'poner en un rango', 'leer la mano'],
      answer: {
        'es': 'Hand reading no es adivinar UNA mano, es ESTRECHAR el rango en cada calle con las acciones observadas. Proceso: preflop (posición + sizing → rango base) → flop (¿apostó, pasó, subió? → ¿qué manos hacen eso?) → turn → river. Cada acción elimina combos y añade otros. Pistas clave: el sizing (grande = polarizado, pequeño = rango amplio), las líneas (check-check-bet en river = nutted o total aire), y el historial con ese jugador. Nunca te comprometas con una lectura única: mantén 2-3 hipótesis.',
        'en': 'Hand reading isn\'t guessing ONE hand, it\'s NARROWING the range each street using observed actions. Process: preflop (position + sizing → base range) → flop (did they bet, check, raise? → which hands do that?) → turn → river. Each action removes some combos and adds others. Key clues: sizing (large = polarized, small = wide range), lines (check-check-bet on river = nutted or pure air), and history with that player. Never commit to a single read: maintain 2-3 hypotheses.',
      },
    ),
    PuxiTopic(
      id: 'checkback',
      title: 'Check back IP (trampa o control)',
      keywords: ['check back', 'checkear ip', 'no apostar en posicion', 'trampa ip', 'no cbet'],
      answer: {
        'es': 'Checkear de vuelta en posición (IP) tiene dos propósitos opuestos: TRAMPA con manos fuertes (dejar que el rival ligue o bluffee en el turn) y POT CONTROL con manos medias (evitar inflar el bote con manos vulnerables). La clave es que el rival NO puede saber cuál de los dos eres. Si solo chekeas de vuelta trampas, explotan tu flop check. Si solo chekeas control, se roban el turn. El equilibrio GTO: checkeas detrás trampas + manos de realización baja + marginals; apuestas: valor, semi-bluffs y manos que niegan equity.',
        'en': 'Checking back in position (IP) has two opposite purposes: TRAPPING with strong hands (letting villain catch up or bluff the turn) and POT CONTROL with medium hands (avoid bloating the pot with vulnerable holdings). The key is villain can\'t tell which you are. If you only check back traps, they exploit your flop check. If you only check back for control, they steal the turn. GTO balance: check back traps + low-realization hands + marginals; bet: value, semi-bluffs and equity-denial hands.',
      },
    ),
    PuxiTopic(
      id: 'nutadvantage',
      title: 'Ventaja de nueces (nut advantage)',
      keywords: ['nut advantage', 'ventaja de nueces', 'mejor mano posible', 'maximo del rango', 'quien tiene las nuts'],
      answer: {
        'es': 'La ventaja de nueces es cuando solo TÚ — no el rival — puedes tener las manos máximas del board. Ej: el que abrió UTG puede tener AA, KK, sets. El que defendió BB no llega a todos ellos. En esos boards, el agresor puede OVERBET porque su rango incluye monstruos que el rival no puede tener. La ventaja de nueces justifica sizings grandes y mayores frecuencias. Sin nueces propias, evita el overbet: si el rival sube, ¿qué tienes para continuar? La combinación de ventaja de rango + nut advantage = el slot más explotable de la mesa.',
        'en': 'Nut advantage is when only YOU — not villain — can hold the top hands on the board. E.g. the UTG opener can have AA, KK, sets. The BB defender can\'t reach all of them. On those boards, the aggressor can OVERBET because their range includes monsters villain can\'t have. Nut advantage justifies large sizings and higher frequencies. Without your own nuts, avoid the overbet: if villain raises, what do you have to continue? The combination of range advantage + nut advantage = the most exploitable slot at the table.',
      },
    ),
    PuxiTopic(
      id: 'turnaggression',
      title: 'Turn play y la calle crucial',
      keywords: ['turno', 'turn', 'segunda calle', 'turno agresion', 'apostar turno'],
      answer: {
        'es': 'El turn es la calle más importante del póker: el bote ya es grande y queda otra calle que puede ser enorme (river). Decisions clave: ¿seguir barreleando (double barrel) o frenar? Dispara el turn cuando: la carta mejora tu rango o empeora el del rival (scare cards: As en board bajo, carta que completa tu historia de draws). Frena cuando: tu mano mediana está OOP contra un rango que conectó, o cuando chekeaste el flop y el turn no mejora tu historia. El sizing del turn sube: ¾-1x bote con valor, ½ bote con marginals.',
        'en': 'The turn is the most important street in poker: the pot is already large and there\'s one more potentially huge street (river) left. Key decisions: keep barreling (double barrel) or slow down? Fire the turn when: the card improves your range or worsens villain\'s (scare cards: Ace on a low board, card that completes your draw story). Slow down when: your medium hand is OOP against a range that connected, or when you checked the flop and the turn doesn\'t improve your story. Turn sizing goes up: ¾-1x pot for value, ½ pot with marginals.',
      },
    ),
    PuxiTopic(
      id: 'openlimp',
      title: 'Open limp (¿cuándo es correcto?)',
      keywords: ['open limp', 'limp', 'solo igualar', 'entrar limp', 'cuando limp'],
      answer: {
        'es': 'El open limp (entrar pagando solo 1BB en vez de abrir) casi siempre es un error: regala iniciativa, capa tu rango y deja entrar a los blinds gratis o barato. La excepción clásica: el SB puede LIMP-CALL o LIMP-RAISE manos fuertes en un formato específico para confundir rangos. En cash, el estándar es ABRIR o FOLDEAR; en torneos con antes, más razones para mantener ese estándar. Un limp de fish invita al iso-raise: castígalo subiendo a 4-5BB para aislarlo en posición.',
        'en': 'Open limping (entering by just calling 1BB instead of raising) is almost always a mistake: you give away initiative, cap your range and let the blinds in cheaply. The classic exception: the SB can LIMP-CALL or LIMP-RAISE strong hands in a specific format to confuse ranges. In cash, the standard is OPEN or FOLD; in tournaments with antes, even more reason to hold that standard. A fish\'s limp invites the iso-raise: punish it by raising to 4-5BB to isolate them in position.',
      },
    ),
    PuxiTopic(
      id: 'exploitfish',
      title: 'Explotando a los fish',
      keywords: ['fish', 'pescado', 'malo', 'recreacional', 'explotar recreacional', 'jugar vs fish'],
      answer: {
        'es': 'Contra un fish (jugador recreacional), el GTO sale por la ventana: EXPLOTA. CALLING STATION (paga todo): deja de farolear, apuesta value más fino, 3 calles de valor con pares medianos si el board no tiene muchos proyectos. FIT-OR-FOLD (foldea demasiado): farolea más, doble y triple barrel, toma la iniciativa y no frenes. MANIAC (apuesta/sube todo): paga más, foldea menos con manos medias, deja que él construya el bote y lo pagues. No presumas de ser GTO contra fish: adapta el juego y toma el dinero.',
        'en': 'Against a fish (recreational player), GTO goes out the window: EXPLOIT. CALLING STATION (calls everything): stop bluffing, bet thinner for value, 3 streets of value with medium pairs if the board isn\'t too draw-heavy. FIT-OR-FOLD (over-folds): bluff more, double and triple barrel, take initiative and don\'t slow down. MANIAC (bets/raises everything): call more, fold less with medium hands, let them build the pot and pay them off. Don\'t brag about being GTO against fish: adapt your game and take the money.',
      },
    ),
    PuxiTopic(
      id: 'leakfix',
      title: 'Leaks comunes y cómo corregirlos',
      keywords: ['leak', 'fuga', 'error comun', 'corregir errores', 'mejorar juego', 'leak mas comun'],
      answer: {
        'es': 'Los leaks más comunes: 1) FOLD TOO MUCH (folding MDF): foldeas de más ante apuestas, el rival te explota con faroles baratos. Fix: calcula MDF antes de foldear. 2) CALL TOO MUCH (calling station): pagas con manos débiles sin equity. Fix: usa el alpha para evaluar tus bluff-catchers. 3) NO C-BET BALANCE: c-beteas igual en todos los boards sin pensar en textura. Fix: pequeño en secos, grande en húmedos. 4) LIMPING: entra limpeando. Fix: abrir o foldear. 5) NO BLUFFING: solo apuestas valor. Fix: añade semi-bluffs y faroles con blockers.',
        'en': 'Most common leaks: 1) FOLD TOO MUCH (failing MDF): you fold too often, villain exploits you with cheap bluffs. Fix: calculate MDF before folding. 2) CALL TOO MUCH (calling station): you call with weak hands without equity. Fix: use alpha to evaluate your bluff-catchers. 3) NO C-BET BALANCE: you c-bet the same on every board without thinking about texture. Fix: small on dry, big on wet. 4) LIMPING: enter by limping. Fix: open or fold. 5) NO BLUFFING: you only bet for value. Fix: add semi-bluffs and blocker bluffs.',
      },
    ),
    PuxiTopic(
      id: 'rake',
      title: 'Rake y su impacto en la estrategia',
      keywords: ['rake', 'comision', 'rakeback', 'impacto rake', 'efecto rake'],
      answer: {
        'es': 'El rake es la comisión que se lleva la casa (normalmente 2-5% del bote, con cap). Impacto real: en rangos fronterizos, el rake convierte jugadas de +EV marginal en -EV. Por eso en spots rakeados aplicas MÁS la estrategia de foldear manos marginales que en un juego sin rake. El rakeback (% del rake devuelto) cambia la ecuación: con 30% rakeback puedes jugar ligeramente más amplio. iPT no tiene rake real, pero en la vida real siempre pregunta cuánto es el rake antes de elegir mesa.',
        'en': 'Rake is the cut the house takes (typically 2-5% of the pot, with a cap). Real impact: on border-line ranges, rake turns marginally +EV plays into -EV ones. That\'s why in raked games you apply MORE "fold the marginals" strategy than in a rake-free game. Rakeback (% of rake returned) changes the equation: with 30% rakeback you can play slightly wider. iPT has no real rake, but in real life always ask how much the rake is before choosing a table.',
      },
    ),
    PuxiTopic(
      id: 'aggressionfactor',
      title: 'Stats: Aggression Factor y VPIP',
      keywords: ['af', 'aggression factor', 'vpip', 'pfr', 'estadisticas', 'hud', 'stats poker'],
      answer: {
        'es': 'VPIP: % de manos donde entras al bote (pagar o subir). PFR: % de manos donde abres o subes preflop. AF (Aggression Factor): (apuestas+subidas) / llamadas. Un reg sólido: VPIP 20-25%, PFR 17-22%, AF > 2.5. Nit: VPIP < 15%. LAG: VPIP 30+%, AF alto. Calling station: VPIP alto, AF bajo (<1). Maniac: PFR > VPIP-5. Estos números te dicen CÓMO adaptar tu juego: contra un nit, foldea marginals vs sus agresiones; contra un LAG, llama más y c/r los buenos spots.',
        'en': 'VPIP: % of hands you enter the pot (call or raise). PFR: % of hands you open or raise preflop. AF (Aggression Factor): (bets+raises) / calls. A solid reg: VPIP 20-25%, PFR 17-22%, AF > 2.5. Nit: VPIP < 15%. LAG: VPIP 30+%, high AF. Calling station: high VPIP, low AF (<1). Maniac: PFR > VPIP-5. These numbers tell you HOW to adapt: against a nit, fold marginals to their aggression; against a LAG, call more and c/r good spots.',
      },
    ),
    PuxiTopic(
      id: 'sessionmgmt',
      title: 'Gestión de sesión y stop-loss',
      keywords: ['stop loss', 'gestion sesion', 'cuando parar', 'sesion larga', 'cuanto tiempo jugar'],
      answer: {
        'es': 'La gestión de sesión es tan importante como la estrategia. Reglas básicas: 1) STOP-LOSS: si pierdes 3 buy-ins en una sesión, párate — no estás tomando buenas decisiones. 2) WIN-STOP (opcional): con algunos pros, fijar un win-stop de 5 buy-ins evita devolver mucho. 3) TIEMPO: la fatiga degrada las decisiones. Sesiones de 2-4 horas son óptimas; después del límite, la calidad baja más que el volumen sube. 4) ENTORNO: no juegues en tilt, cansancio extremo, o con distracciones. Tu mejor edge es mental.',
        'en': 'Session management is as important as strategy. Basic rules: 1) STOP-LOSS: if you lose 3 buy-ins in a session, stop — you\'re not making good decisions. 2) WIN-STOP (optional): some pros set a 5 buy-in win-stop to avoid giving back big wins. 3) TIME: fatigue degrades decisions. 2-4 hour sessions are optimal; after that, quality drops more than volume rises. 4) ENVIRONMENT: don\'t play on tilt, extreme fatigue, or with distractions. Your biggest edge is mental.',
      },
    ),
    PuxiTopic(
      id: 'studymethods',
      title: 'Cómo estudiar póker',
      keywords: ['estudiar poker', 'como mejorar', 'estudio', 'revisar manos', 'hand history', 'solver'],
      answer: {
        'es': 'Para mejorar de verdad: 1) REVISAR MANOS: después de cada sesión, marca las 3-5 manos donde no estuviste seguro y analízalas. 2) SOLVERS: GTO Wizard o PioSolver te dicen la frecuencia exacta por spot — estudia spots concretos, no navega sin dirección. 3) STUDY GROUPS: discutir manos con jugadores similares o mejores comprime el aprendizaje. 4) RANGE TRAINING: usa apps de rango (GTOW free, PokerCruncher) para memorizar rangos preflop. 5) BASE de conocimiento: Puxi te explica conceptos; el Simulador te deja practicar. La práctica sin estudio es ruido; el estudio sin práctica es teoría.',
        'en': 'To truly improve: 1) REVIEW HANDS: after each session, flag the 3-5 hands where you were unsure and analyze them. 2) SOLVERS: GTO Wizard or PioSolver tell you exact frequencies per spot — study specific spots, don\'t wander aimlessly. 3) STUDY GROUPS: discussing hands with similar or better players compresses learning. 4) RANGE TRAINING: use range apps (GTOW free, PokerCruncher) to memorize preflop ranges. 5) KNOWLEDGE BASE: Puxi explains concepts; the Simulator lets you practice. Practice without study is noise; study without practice is theory.',
      },
    ),
    PuxiTopic(
      id: 'cbetfrequency',
      title: 'Frecuencia de c-bet por posición',
      keywords: ['frecuencia cbet', 'cuanto cbet', 'cuando no cbet', 'cbet ip oop', 'frecuencia apostando'],
      answer: {
        'es': 'La frecuencia óptima de c-bet varía: IP en flop (posición): c-betea ~55-65% de tus manos, más en boards secos (A-high, K-high rainbow). OOP: más selectivo, ~40-50%; refuerza con check-raises y check-calls equilibrados. HEADS-UP: puedes c-betear más; MULTIWAY: baja drásticamente a ~25-35% (alguien siempre pega). Señal de que c-beteas demasiado: tus barriles subsiguientes no funcionan porque los rivales saben que c-beteas con aire. Señal de poco: te roban el bote cuando chekeas.',
        'en': 'Optimal c-bet frequency varies: IP on flop (in position): c-bet ~55-65% of your hands, more on dry boards (A-high, K-high rainbow). OOP: more selective, ~40-50%; support with balanced check-raises and check-calls. HEADS-UP: can c-bet more; MULTIWAY: drops sharply to ~25-35% (someone always connects). Sign you c-bet too much: your subsequent barrels don\'t work because opponents know you c-bet with air. Sign of too little: they steal the pot when you check.',
      },
    ),
    PuxiTopic(
      id: 'oopplay',
      title: 'Jugar OOP (fuera de posición)',
      keywords: ['oop', 'fuera de posicion', 'jugar sin posicion', 'desventaja posicional', 'ciega vs boton'],
      answer: {
        'es': 'OOP (Out Of Position) es el handicap más grande del póker. Actúas ANTES de ver lo que hace el rival → menos información, más errores. Estrategia OOP: usa CHECK-RAISE como arma principal (combina protección y presión); check-call con manos de medio valor que pueden bluff-catch; donk bet solo en boards muy específicos que favorecen tu rango; evita el "lead → call raise" que infla el bote sin información. Lo más importante: el rango que defiendes OOP debe ser más estrecho — solo manos con buena playabilidad y realización de equity.',
        'en': 'OOP (Out Of Position) is the biggest handicap in poker. You act BEFORE seeing what villain does → less information, more mistakes. OOP strategy: use CHECK-RAISE as your main weapon (combines protection and pressure); check-call with medium-value hands that can bluff-catch; donk bet only on very specific boards that favor your range; avoid "lead → call raise" which bloats the pot without information. Most importantly: the range you defend OOP should be narrower — only hands with good playability and equity realization.',
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

// ─── Decision Correction System ──────────────────────────────────────────────

/// Severity levels for a preflop decision error.
enum ErrorLevel {
  /// EV loss < 0.08 BB — virtually indistinguishable from optimal.
  negligible,

  /// EV loss 0.08–0.25 BB — minor leak worth knowing.
  minor,

  /// EV loss 0.25–0.6 BB — clear mistake that compounds over volume.
  moderate,

  /// EV loss > 0.6 BB — major error costing serious EV per occurrence.
  major,
}

/// Result of analyzing one decision against the GTO strategy.
class DecisionError {
  final String hand;
  final String spotId;
  final String chosenAction;
  final String correctAction;

  /// EV of the chosen action (BB). Null if the action isn't in the strategy.
  final double evChosen;

  /// EV of the GTO-optimal action (BB).
  final double evCorrect;

  final ErrorLevel level;

  /// Coach-grade explanation of why the correct action is better.
  final String explanation;

  const DecisionError({
    required this.hand,
    required this.spotId,
    required this.chosenAction,
    required this.correctAction,
    required this.evChosen,
    required this.evCorrect,
    required this.level,
    required this.explanation,
  });

  double get evLost => (evCorrect - evChosen).clamp(0.0, 99.0);

  bool get isNegligible => level == ErrorLevel.negligible;

  /// Short feedback string for the UI ("Tu jugada: fold. GTO: 3bet (+0.45BB)").
  String get feedbackLine {
    final diff = evLost.toStringAsFixed(2);
    return I18n.locale == 'es'
        ? 'Elegiste: $chosenAction. GTO: $correctAction (−${diff}BB EV)'
        : 'You played: $chosenAction. GTO: $correctAction (−${diff}BB EV)';
  }

  String get levelLabel {
    switch (level) {
      case ErrorLevel.negligible:
        return I18n.locale == 'es' ? 'Marginal' : 'Marginal';
      case ErrorLevel.minor:
        return I18n.locale == 'es' ? 'Menor' : 'Minor';
      case ErrorLevel.moderate:
        return I18n.locale == 'es' ? 'Moderado' : 'Moderate';
      case ErrorLevel.major:
        return I18n.locale == 'es' ? 'Error grave' : 'Major error';
    }
  }
}

/// Analyzes preflop decisions against GTO strategies and produces [DecisionError]s.
class PuxiCorrector {
  PuxiCorrector._();

  /// Returns null if [chosenAction] is the GTO primary or EV difference is negligible.
  /// Returns a [DecisionError] otherwise.
  static DecisionError? analyze({
    required String hand,
    required String chosenAction,
    required HandStrategy gtoStrategy,
  }) {
    // primary / bestEv are SpotRecords; the action label and EV live on them.
    final correctRecord = gtoStrategy.bestEv;
    final correct = correctRecord.action;

    // Find EV of chosen action; default to 0 if the action is folding to nothing.
    final evChosen = gtoStrategy.evOf(chosenAction) ?? 0.0;
    final evCorrect = correctRecord.ev;
    final lost = (evCorrect - evChosen).clamp(0.0, 99.0);

    if (lost < 0.05) return null; // negligible — no feedback needed

    final level = lost < 0.08
        ? ErrorLevel.negligible
        : lost < 0.25
            ? ErrorLevel.minor
            : lost < 0.6
                ? ErrorLevel.moderate
                : ErrorLevel.major;

    if (level == ErrorLevel.negligible) return null;

    final explanation = correctRecord.explanation.isNotEmpty
        ? correctRecord.explanation
        : _fallbackExplanation(hand, chosenAction, correct, lost);

    return DecisionError(
      hand: hand,
      spotId: gtoStrategy.spotId,
      chosenAction: chosenAction,
      correctAction: correct,
      evChosen: evChosen,
      evCorrect: evCorrect,
      level: level,
      explanation: explanation,
    );
  }

  static String _fallbackExplanation(
      String hand, String chosen, String correct, double lost) {
    final diff = lost.toStringAsFixed(2);
    if (I18n.locale == 'es') {
      return '$hand: $correct es la jugada GTO. Elegir $chosen cuesta '
          '≈${diff}BB de EV en este spot. Consulta la base de datos para '
          'los detalles de frecuencia y rango.';
    }
    return '$hand: $correct is the GTO play. Choosing $chosen costs '
        '≈${diff}BB EV in this spot. Check the database for frequency and range details.';
  }

  /// Generates a summary of multiple errors (for session review).
  static String sessionSummary(List<DecisionError> errors) {
    if (errors.isEmpty) {
      return I18n.locale == 'es'
          ? 'Sin errores detectados esta sesión. ¡Juego sólido!'
          : 'No errors detected this session. Solid play!';
    }
    final totalLost = errors.fold(0.0, (s, e) => s + e.evLost);
    final majors = errors.where((e) => e.level == ErrorLevel.major).length;
    final mods = errors.where((e) => e.level == ErrorLevel.moderate).length;
    if (I18n.locale == 'es') {
      return 'Sesión: ${errors.length} decisión(es) mejorable(s). '
          'EV perdido total: ≈${totalLost.toStringAsFixed(2)}BB. '
          'Graves: $majors · Moderados: $mods.';
    }
    return 'Session: ${errors.length} improvable decision(s). '
        'Total EV lost: ≈${totalLost.toStringAsFixed(2)}BB. '
        'Major: $majors · Moderate: $mods.';
  }
}
