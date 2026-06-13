/// STRATEGIC CONCEPTS LIBRARY — postflop & theory knowledge as structured data.
///
/// Pure content (no UI). Each concept has an id, a title, the core idea, when to
/// apply it, common mistakes, and a worked example. Used by Puxi and the
/// analysis layer to attach coach-grade explanations to spots.
class StrategyConcept {
  final String id;
  final String title;
  final String category; // 'betting', 'defense', 'math', 'range', 'mental'
  final String coreIdea;
  final String whenToApply;
  final String commonMistake;
  final String example;

  const StrategyConcept({
    required this.id,
    required this.title,
    required this.category,
    required this.coreIdea,
    required this.whenToApply,
    required this.commonMistake,
    required this.example,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'core_idea': coreIdea,
        'when_to_apply': whenToApply,
        'common_mistake': commonMistake,
        'example': example,
      };
}

class ConceptsLibrary {
  static const List<StrategyConcept> concepts = [
    StrategyConcept(
      id: 'cbet',
      title: 'Continuation Bet (C-Bet)',
      category: 'betting',
      coreIdea: 'Apostar el flop tras subir preflop, manteniendo la iniciativa. '
          'Cobra de manos peores, niega equity a proyectos y mantiene tu rango '
          'creíble en calles futuras.',
      whenToApply: 'Cuando tienes ventaja de rango (boards A-high, K-high secos), '
          'o cuando tu mano quiere proteger/cobrar valor. Sizing pequeño (⅓) en '
          'boards secos, grande (⅔-¾) en boards húmedos con valor.',
      commonMistake: 'C-betear el 100% por inercia. En boards que favorecen al '
          'defensor (low connected 765) tu rango de open no conecta y te '
          'check-raisean o flotan: ahí frena.',
      example: 'Abres CO con AK, BB paga. Flop A♠7♦2♣: c-bet ⅓ del bote — '
          'tienes ventaja de rango y de nueces, apuestas casi todo tu rango barato.',
    ),
    StrategyConcept(
      id: 'delayed_cbet',
      title: 'Delayed C-Bet',
      category: 'betting',
      coreIdea: 'Checkear el flop como agresor preflop y apostar el turn. Protege '
          'tu rango de check, captura valor cuando el turn mejora tu mano o '
          'empeora la del rival.',
      whenToApply: 'Flop que no favorece tu rango o mano marginal que no quiere '
          'inflar el bote; turn que te da equity o una scare card.',
      commonMistake: 'Checkear el flop SIEMPRE con manos medias hace tu check '
          'explotable: el rival apuesta el turn de cara. Equilibra con algunas '
          'trampas fuertes en tu rango de check.',
      example: 'Abres BTN con K♥Q♥, BB paga. Flop 8♠5♦3♣ (no conecta): check. '
          'Turn Q♣ (top pair): ahora apuestas el turn por valor — delayed c-bet.',
    ),
    StrategyConcept(
      id: 'probe_bet',
      title: 'Probe Bet',
      category: 'betting',
      coreIdea: 'Apostar de cara (OOP) en el turn cuando el agresor del flop '
          'checkeó detrás, mostrando debilidad. Sondas su rango capado.',
      whenToApply: 'Eres el defensor OOP, el IP renunció a la c-bet, y el turn '
          'mejora tu rango de call (cartas bajas/conectores que pegan a tu rango).',
      commonMistake: 'Sondar con basura total: el check-back IP aún tiene manos '
          'medias que pagan. Sonda con valor real o proyectos fuertes.',
      example: 'Defiendes BB vs CO. Flop 9♠6♦4♣, ambos check. Turn 7♥ '
          '(tienes 85): probe bet ½ bote — el CO no tiene muchos 7x o sets.',
    ),
    StrategyConcept(
      id: 'check_raise',
      title: 'Check-Raise',
      category: 'betting',
      coreIdea: 'Checkear con intención de subir si el rival apuesta. Línea OOP '
          'más potente: maximiza valor con monstruos y mete presión brutal como '
          'farol con fold equity.',
      whenToApply: 'OOP con manos fuertes que quieren construir bote, o semi-bluffs '
          'con blockers y fold equity. Especialmente fuerte en boards que pegan a '
          'tu rango de defensa.',
      commonMistake: 'Check-raisear solo valor te hace transparente: el rival '
          'foldea sus faroles y solo paga con mejor. Necesitas faroles balanceados.',
      example: 'Defiendes BB con 7♠6♠. Flop 9♠8♠2♦ (flush+straight draw): '
          'check-raise como semi-bluff — fold equity + 15 outs si te pagan.',
    ),
    StrategyConcept(
      id: 'donk_bet',
      title: 'Donk Bet',
      category: 'betting',
      coreIdea: 'Apostar de cara OOP en una calle nueva contra el agresor previo, '
          'quitándole la iniciativa. Generalmente sub-óptimo, justificado solo en '
          'boards muy específicos.',
      whenToApply: 'Boards que favorecen MÁS tu rango de defensa que el del '
          'agresor: low connected (754) donde la BB tiene más two-pair/straights '
          'que el opener de UTG.',
      commonMistake: 'Donkear por costumbre rompe tu rango de check-call/check-raise '
          'y te hace fácil de jugar. Es una excepción, no una norma.',
      example: 'Defiendes BB vs UTG. Flop 7♦6♦5♣: donk bet — tu rango de calls '
          '(87, 98, 65, 44) pega mucho más que el rango premium de UTG.',
    ),
    StrategyConcept(
      id: 'overbet',
      title: 'Overbet',
      category: 'betting',
      coreIdea: 'Apostar más que el bote (125-200%+). Solo correcto con ventaja de '
          'nueces: tu rango tiene las manos máximas que el rival no puede tener.',
      whenToApply: 'Boards polarizados donde tienes nut advantage; río con rango '
          'polarizado (monstruos + faroles con blockers) para máxima presión por '
          'el stack.',
      commonMistake: 'Overbetear sin nut advantage: el rival simplemente no paga '
          'sin las nuts, y cuando paga te bate. Necesitas el tope del rango.',
      example: 'Abres BTN, BB paga. Board A♠K♦5♣2♥7♠. Tienes AK (top two): '
          'overbet río 1.5x — tu rango incluye sets/AA que el suyo no, le pones '
          'todo el stack en juego.',
    ),
    StrategyConcept(
      id: 'blocker_bet',
      title: 'Blocking Bet',
      category: 'betting',
      coreIdea: 'Apuesta pequeña OOP en el río (10-25%) con mano media para fijar '
          'tu propio precio: ves la mano barato y evitas pagar una apuesta grande.',
      whenToApply: 'OOP en el río con showdown value medio, contra rivales que '
          'rara vez suben tu apuesta pequeña como farol.',
      commonMistake: 'Contra agresivos que te suben (raise) la blocker bet, quedas '
          'en un aprieto sin plan. Úsala contra pasivos, no contra LAGs.',
      example: 'Defiendes BB con A♦J♣ en A♠9♦4♣8♥2♠. Río: blocker bet 20% — '
          'pagas barato y evitas que el rival apueste ⅔ y te ponga en duda.',
    ),
    StrategyConcept(
      id: 'bluff_catch',
      title: 'Bluff Catching',
      category: 'defense',
      coreIdea: 'Pagar con una mano que solo gana si el rival farolea. La decisión '
          'es matemática: compara pot odds con la frecuencia de farol del rival.',
      whenToApply: 'Río con showdown value medio frente a una apuesta polarizada. '
          'Usa blockers: si bloqueas sus combos de valor, hay relativamente más '
          'faroles → paga.',
      commonMistake: 'Pagar "por curiosidad" sin contar combos. O foldear de más '
          '(fallando la MDF) y volverte explotable por faroles baratos.',
      example: 'Te dan 2:1 (necesitas 33%). Si crees que farolea >⅓ de las veces '
          'y tu carta bloquea su straight, el call es +EV.',
    ),
    StrategyConcept(
      id: 'thin_value',
      title: 'Thin Value',
      category: 'betting',
      coreIdea: 'Apostar de valor con un margen estrecho, cobrando de manos peores '
          'que pagarían (pares menores, kickers débiles).',
      whenToApply: 'Río contra rangos capados o calling stations; sizing pequeño '
          '(30-40%) para que paguen las manos marginales.',
      commonMistake: 'Apostar thin value cuando el rango que te paga YA te bate a '
          'menudo: te conviertes en víctima de reverse implied odds.',
      example: 'Río con A♦T♣ en T♠7♦4♣3♥2♠ vs calling station: apuesta 35% — '
          'paga con Tx peor, 99, 88, 7x. Valor fino que un check dejaría sobre la mesa.',
    ),
    StrategyConcept(
      id: 'polarization',
      title: 'Polarización',
      category: 'range',
      coreIdea: 'Rango de apuesta dividido en valor fuerte + faroles, sin manos '
          'medias. Permite sizings grandes y overbets.',
      whenToApply: 'Río y turn con sizings grandes; cuando quieres maximizar '
          'presión y tu rango contiene tanto nuts como aire con blockers.',
      commonMistake: 'Apostar grande con un rango lineal (manos medias incluidas): '
          'sobrevaloras manos que no quieren un raise encima.',
      example: 'Overbet río con {sets, straights} por valor + {Axs sin par con '
          'blocker} como farol. Mismo sizing → imposible de leer.',
    ),
    StrategyConcept(
      id: 'merged_range',
      title: 'Rango Lineal / Merged',
      category: 'range',
      coreIdea: 'Las mejores X manos seguidas, incluyendo valor medio. Para '
          'apuestas pequeñas que cobran de un rango amplio.',
      whenToApply: 'Flop/turn con c-bets pequeñas en boards secos donde tienes '
          'ventaja de rango y quieres apostar muchas manos baratas.',
      commonMistake: 'Usar un rango merged para sizings grandes: las manos medias '
          'no aguantan la presión que tú mismo creas.',
      example: 'C-bet ⅓ en A72r con {Ax, Kx, Qx, proyectos backdoor}: rango merged '
          'que apuesta casi todo barato por ventaja de rango.',
    ),
    StrategyConcept(
      id: 'implied_odds',
      title: 'Implied Odds',
      category: 'math',
      coreIdea: 'Lo que ganas en calles futuras si ligas, más allá del bote actual. '
          'Justifica calls con pot odds directas "malas".',
      whenToApply: 'Proyectos disfrazados (sets, colores ocultos) con stacks '
          'profundos y un rival que pagará cuando ligues.',
      commonMistake: 'Sobrevalorar implied odds contra rivales tight (no te pagan) '
          'o con stacks cortos (no hay calles que cobrar).',
      example: 'Pagas 22 preflop buscando set con stacks de 100BB: ligas ~12% '
          'pero cobras stacks completos cuando aciertas → implied odds suficientes.',
    ),
    StrategyConcept(
      id: 'reverse_implied',
      title: 'Reverse Implied Odds',
      category: 'math',
      coreIdea: 'Lo que PIERDES en calles futuras al ligar una mano que parece '
          'buena pero queda dominada. El coste oculto de manos marginales.',
      whenToApply: 'Evita manos con malas RIO: kickers débiles, segundo color, '
          'extremo bajo de straights en boards que pueden mejorar al rival.',
      commonMistake: 'Pagar con TPWK (top pair weak kicker) tres calles: cuando '
          'ligas top pair, el rival que apuesta fuerte tiene TPK o mejor.',
      example: 'KJ en J♠9♦4♣: ligas top pair pero pagas tres barriles y el rival '
          'muestra AJ/JT/sets. La mano "buena" sangra fichas.',
    ),
    StrategyConcept(
      id: 'equity_realization',
      title: 'Realización de Equity (R)',
      category: 'math',
      coreIdea: 'Tu equity cruda NO es lo que ganas: la realizas según llegues al '
          'showdown. IP realizas >100% (R>1); OOP realizas <90% (R<0.9).',
      whenToApply: 'Decisiones preflop fronterizas: 65s en BTN vale más que su '
          'equity cruda; la misma mano UTG vale menos.',
      commonMistake: 'Defender OOP manos offsuit que se foldean cuando fallan: mala '
          'realización destruye su EV teórico.',
      example: '65s en BTN: realiza R≈1.1 (controla el bote, roba). 65s en UTG: '
          'R≈0.85 — la diferencia decide si abres o foldeas.',
    ),
    StrategyConcept(
      id: 'mdf',
      title: 'Minimum Defense Frequency',
      category: 'math',
      coreIdea: 'MDF = pot / (pot + bet). El % mínimo de tu rango que debes '
          'defender para que el rival no pueda farolear con cualquier carta.',
      whenToApply: 'Frente a apuestas, para decidir cuánto puedes foldear sin '
          'volverte explotable. Apuesta ½ bote → defiendes 67%.',
      commonMistake: 'Foldear de más (el leak nº1): cada fold por encima del MDF '
          'le imprime EV al rival con faroles automáticos.',
      example: 'Te apuestan ½ bote → MDF 67% → solo puedes foldear el 33%. Si '
          'foldeas el 50%, su farol con cualquier carta es rentable.',
    ),
    StrategyConcept(
      id: 'alpha',
      title: 'Alpha (break-even del farol)',
      category: 'math',
      coreIdea: 'Alpha = bet / (pot + bet). El % que el rival debe foldear para '
          'que tu farol con 0% de equity sea rentable al instante.',
      whenToApply: 'Antes de farolear: estima la fold equity y compárala con alpha. '
          'Faroles pequeños necesitan menos folds.',
      commonMistake: 'Farolear grande contra calling stations: necesitas 50%+ de '
          'folds que un fish nunca te da.',
      example: 'Apuestas el bote → alpha 50%: necesitas que foldee la mitad. '
          'Apuestas ⅓ → alpha 25%: solo necesitas un cuarto de folds.',
    ),
    StrategyConcept(
      id: 'spr',
      title: 'Stack-to-Pot Ratio',
      category: 'math',
      coreIdea: 'SPR = stack efectivo / bote. Mide el compromiso. SPR bajo: top '
          'pair ya juega por stacks. SPR alto: maniobra con cautela.',
      whenToApply: 'Planifica el SPR preflop con el sizing: un 3-bet baja el SPR '
          'y compromete top pair; un flat lo mantiene alto para maniobrar.',
      commonMistake: 'Comprometerse con top pair en SPR alto, o foldear overpairs '
          'en SPR bajo donde ya estás pot-committed.',
      example: 'SPR 1.5 con AK en A-high: stack-off sin dudar. SPR 8 con la misma '
          'mano: una calle de valor y precaución, no metas los 100BB.',
    ),
    StrategyConcept(
      id: 'range_advantage',
      title: 'Ventaja de Rango',
      category: 'range',
      coreIdea: 'Cuando tu rango entero conecta mejor con el board que el del '
          'rival, puedes apostar con MÁS frecuencia y sizing.',
      whenToApply: 'Boards A-high/K-high como agresor preflop: c-betea casi todo '
          'tu rango, el defensor no puede tener tantos Ax/Kx.',
      commonMistake: 'Apostar mucho en boards que NO favorecen tu rango (low '
          'connected como opener tight): cedes la ventaja al defensor.',
      example: 'Abres UTG, BB paga. Flop A♠K♦7♣: tienes enorme ventaja de rango — '
          'c-bet pequeña con todo, el BB casi nunca tiene AK/AA/KK.',
    ),
    StrategyConcept(
      id: 'nut_advantage',
      title: 'Ventaja de Nueces',
      category: 'range',
      coreIdea: 'Solo TÚ puedes tener las manos máximas del board. Desbloquea '
          'overbets: castigas por todo el stack sabiendo que el rival no tiene nuts.',
      whenToApply: 'Boards donde tu rango incluye sets/straights/AA que el rival '
          'no llega. Permite sizings de 1.5-2x pot.',
      commonMistake: 'Overbetear sin nut advantage: si el rival también tiene las '
          'nuts en su rango, tu presión no funciona.',
      example: 'Abres UTG con AA en A♠K♥5♦: tienes nut advantage (sets de A/K). '
          'Overbet turn/river — el BB no puede tener AA/KK casi nunca.',
    ),
    StrategyConcept(
      id: 'protection',
      title: 'Protección / Negación de Equity',
      category: 'betting',
      coreIdea: 'Apostar para que el rival no realice su equity de proyecto. Cada '
          'fold de una mano con outs es EV ganado.',
      whenToApply: 'Manos vulnerables (top pair, overpairs) en boards húmedos con '
          'muchos proyectos: apuesta grande para cobrar y proteger.',
      commonMistake: 'Checkear top pair "para inducir" en un board mojado: regalas '
          'cartas gratis a 12 outs que te superan.',
      example: 'Tienes A♦A♣ en 9♠8♠5♦: apuesta ¾ — no des un color o straight '
          'gratis. Las nuts esperan; las manos vulnerables cobran YA.',
    ),
    StrategyConcept(
      id: 'floating',
      title: 'Float',
      category: 'defense',
      coreIdea: 'Pagar una c-bet (en posición) con mano débil para robar el bote '
          'en una calle posterior cuando el rival muestre debilidad.',
      whenToApply: 'IP contra rivales que c-betean mucho el flop pero se rinden en '
          'el turn. Juegas su debilidad, no tus cartas.',
      commonMistake: 'Flotar OOP o contra rivales que doblan barril: sin posición '
          'no ves su check, y un segundo barril te echa.',
      example: 'BTN con Q♥J♥ en A♠7♦2♣: flotas la c-bet del CO. Turn check del CO → '
          'apuestas y te llevas el bote: su rango de doble barril es estrecho.',
    ),
    StrategyConcept(
      id: 'semibluff',
      title: 'Semi-Bluff',
      category: 'betting',
      coreIdea: 'Apostar/subir con un proyecto que aún no es la mejor mano. Ganas '
          'de dos formas: fold inmediato, o ligar el proyecto.',
      whenToApply: 'Proyectos fuertes (flush draw, OESD) con fold equity. Suma '
          'fold equity a equity real → mejor que pagar pasivo.',
      commonMistake: 'Semi-bluffear sin fold equity (contra calling stations): '
          'pierdes el valor del fold y solo ligas tu equity.',
      example: 'Check-raise con 8♠7♠ en 9♠6♦2♠: 15 outs + fold equity. Ganas si '
          'foldea ya, y si te paga tienes ~54% para ligar.',
    ),
    StrategyConcept(
      id: 'barrel',
      title: 'Double / Triple Barrel',
      category: 'betting',
      coreIdea: 'Seguir apostando en calles posteriores tras la c-bet. Dispara '
          'cuando la carta mejora tu rango o empeora el del rival.',
      whenToApply: 'Turn/river con scare cards (overcards, cartas que completan tu '
          'historia). Triple barrel solo con valor o blockers.',
      commonMistake: 'Triple barrel sin blockers ni valor: quemas dinero contra '
          'rangos que ya llegaron capados pero pagan el río.',
      example: 'C-bet flop A72, turn K (mejora tu rango de Ax/Kx): double barrel. '
          'River Q con blocker a straights: triple barrel creíble.',
    ),
    StrategyConcept(
      id: 'pot_control',
      title: 'Pot Control',
      category: 'defense',
      coreIdea: 'Mantener el bote pequeño con manos de fuerza media para no inflar '
          'un bote que no quieres jugar grande.',
      whenToApply: 'Top pair kicker flojo, pares medios: checkea una calle o '
          'apuesta pequeño en vez de tres calles de valor dudoso.',
      commonMistake: 'Pagar tres calles grandes con un par medio: el clásico leak '
          'de reverse implied odds que sangra stacks.',
      example: 'KJ en J♠9♦4♣3♥2♠: checkea el turn para controlar el bote en vez de '
          'apostar tres calles y pagar un check-raise por tu kicker.',
    ),
    StrategyConcept(
      id: 'leverage',
      title: 'Stack Leverage / Presión',
      category: 'mental',
      coreIdea: 'Dimensionar apuestas para amenazar el stack entero, maximizando '
          'la presión sobre rangos que quieren sobrevivir.',
      whenToApply: 'Cuando el rival juega para no perder (survival ranges): sizes '
          'que ponen su torneo/stack en juego fuerzan folds.',
      commonMistake: 'Aplicar leverage sin fold equity real: contra stacks cortos '
          'comprometidos, la presión no funciona.',
      example: 'River overbet que pone al rival all-in por su stack: con AKs '
          'bloqueas sus premiums y su instinto de supervivencia hace el resto.',
    ),
  ];

  /// Find a concept by id.
  static StrategyConcept? byId(String id) {
    for (final c in concepts) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// All concepts in a category.
  static List<StrategyConcept> byCategory(String category) =>
      concepts.where((c) => c.category == category).toList();

  static List<Map<String, dynamic>> exportJson() =>
      concepts.map((c) => c.toJson()).toList();
}
