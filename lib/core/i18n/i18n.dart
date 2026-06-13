/// Lightweight i18n for iPT. Six languages; ALL poker jargon stays in
/// English in every locale (Fold, Call, Raise, flop, pot odds, equity,
/// MDF, SPR, c-bet, bluff, nuts, draws...) — as it should be.
library i18n;

import 'i18n_coach.dart';

class I18n {
  static String locale = 'es';

  static const Map<String, String> supported = {
    'es': '🇪🇸 Español',
    'en': '🇬🇧 English',
    'pt': '🇧🇷 Português',
    'fr': '🇫🇷 Français',
    'de': '🇩🇪 Deutsch',
    'it': '🇮🇹 Italiano',
  };

  static String t(String key, [Map<String, String>? args]) {
    final m = _s[key] ?? coachStrings[key];
    var out = m == null ? key : (m[locale] ?? m['en'] ?? key);
    if (args != null) {
      args.forEach((k, v) => out = out.replaceAll('{$k}', v));
    }
    return out;
  }

  // ───────────────────────── UI STRINGS ─────────────────────────
  static const Map<String, Map<String, String>> _s = {
    // Navigation
    'nav_play': {'es': 'JUGAR', 'en': 'PLAY', 'pt': 'JOGAR', 'fr': 'JOUER', 'de': 'SPIELEN', 'it': 'GIOCA'},
    'nav_analyze': {'es': 'ANALIZAR', 'en': 'ANALYZE', 'pt': 'ANALISAR', 'fr': 'ANALYSER', 'de': 'ANALYSE', 'it': 'ANALIZZA'},
    'nav_stats': {'es': 'VALORACIÓN', 'en': 'REPORT', 'pt': 'RELATÓRIO', 'fr': 'BILAN', 'de': 'BERICHT', 'it': 'REPORT'},
    'nav_year': {'es': 'PROGRESO', 'en': 'PROGRESS', 'pt': 'PROGRESSO', 'fr': 'PROGRÈS', 'de': 'FORTSCHRITT', 'it': 'PROGRESSI'},

    // Play screen
    'shuffling': {'es': 'Barajando...', 'en': 'Shuffling...', 'pt': 'Embaralhando...', 'fr': 'Mélange...', 'de': 'Mischen...', 'it': 'Mescolando...'},
    'hand_no': {'es': 'Mano #{n}', 'en': 'Hand #{n}', 'pt': 'Mão #{n}', 'fr': 'Main n°{n}', 'de': 'Hand Nr. {n}', 'it': 'Mano n.{n}'},
    'played_count': {'es': '{n} jugadas', 'en': '{n} played', 'pt': '{n} jogadas', 'fr': '{n} jouées', 'de': '{n} gespielt', 'it': '{n} giocate'},
    'session_lbl': {'es': 'SESIÓN', 'en': 'SESSION', 'pt': 'SESSÃO', 'fr': 'SESSION', 'de': 'SESSION', 'it': 'SESSIONE'},
    'winner_banner': {'es': '🏆 GANA {who}', 'en': '🏆 {who} WINS', 'pt': '🏆 {who} GANHA', 'fr': '🏆 {who} GAGNE', 'de': '🏆 {who} GEWINNT', 'it': '🏆 VINCE {who}'},
    'pot_lbl': {'es': 'Bote: {v}', 'en': 'Pot: {v}', 'pt': 'Pote: {v}', 'fr': 'Pot : {v}', 'de': 'Pot: {v}', 'it': 'Piatto: {v}'},
    'thinking': {'es': 'Pensando...', 'en': 'Thinking...', 'pt': 'Pensando...', 'fr': 'Réflexion...', 'de': 'Denkt nach...', 'it': 'Sta pensando...'},
    'you': {'es': 'TÚ', 'en': 'YOU', 'pt': 'VOCÊ', 'fr': 'VOUS', 'de': 'DU', 'it': 'TU'},
    'amount': {'es': 'Cantidad', 'en': 'Amount', 'pt': 'Quantia', 'fr': 'Montant', 'de': 'Betrag', 'it': 'Importo'},
    'third_pot': {'es': '⅓ Bote', 'en': '⅓ Pot', 'pt': '⅓ Pote', 'fr': '⅓ Pot', 'de': '⅓ Pot', 'it': '⅓ Piatto'},
    'half_pot': {'es': '½ Bote', 'en': '½ Pot', 'pt': '½ Pote', 'fr': '½ Pot', 'de': '½ Pot', 'it': '½ Piatto'},
    'three_q_pot': {'es': '¾ Bote', 'en': '¾ Pot', 'pt': '¾ Pote', 'fr': '¾ Pot', 'de': '¾ Pot', 'it': '¾ Piatto'},
    'pot_btn': {'es': 'Bote', 'en': 'Pot', 'pt': 'Pote', 'fr': 'Pot', 'de': 'Pot', 'it': 'Piatto'},
    'wins_msg': {'es': '🏆 {who} gana \${amt}', 'en': '🏆 {who} wins \${amt}', 'pt': '🏆 {who} ganha \${amt}', 'fr': '🏆 {who} gagne {amt} \$', 'de': '🏆 {who} gewinnt \${amt}', 'it': '🏆 {who} vince \${amt}'},
    'bot_busts': {'es': '💀 {out} se va sin fichas — entra {inn}', 'en': '💀 {out} busts out — {inn} sits in', 'pt': '💀 {out} quebrou — entra {inn}', 'fr': '💀 {out} est éliminé — {inn} s\'assoit', 'de': '💀 {out} ist pleite — {inn} setzt sich', 'it': '💀 {out} è fuori — entra {inn}'},

    // Leave / reload dialogs
    'leave_title': {'es': 'Cerrar sesión', 'en': 'End session', 'pt': 'Encerrar sessão', 'fr': 'Terminer la session', 'de': 'Session beenden', 'it': 'Chiudi sessione'},
    'leave_body': {'es': '¿Levantarte de la mesa? Te llevas {v} de vuelta al bankroll. Podrás revisar toda la sesión en ANALIZAR y VALORACIÓN.', 'en': 'Leave the table? You take {v} back to your bankroll. The whole session stays available in ANALYZE and REPORT.', 'pt': 'Levantar da mesa? Você leva {v} de volta ao bankroll. A sessão fica disponível em ANALISAR e RELATÓRIO.', 'fr': 'Quitter la table ? Vous récupérez {v} dans votre bankroll. La session reste disponible dans ANALYSER et BILAN.', 'de': 'Den Tisch verlassen? Du nimmst {v} zurück in deine Bankroll. Die Session bleibt in ANALYSE und BERICHT verfügbar.', 'it': 'Lasci il tavolo? Riporti {v} nel bankroll. La sessione resta disponibile in ANALIZZA e REPORT.'},
    'keep_playing': {'es': 'Seguir jugando', 'en': 'Keep playing', 'pt': 'Continuar jogando', 'fr': 'Continuer', 'de': 'Weiterspielen', 'it': 'Continua a giocare'},
    'leave_btn': {'es': 'Levantarme', 'en': 'Leave table', 'pt': 'Levantar', 'fr': 'Quitter', 'de': 'Aufstehen', 'it': 'Alzati'},
    'reload_title': {'es': 'Recargar bankroll', 'en': 'Reload bankroll', 'pt': 'Recarregar bankroll', 'fr': 'Recharger la bankroll', 'de': 'Bankroll aufladen', 'it': 'Ricarica bankroll'},
    'reload_body': {'es': '¿Añadir \$1.000 a tu bankroll? Es gratis, todo el dinero del juego es ficticio.', 'en': 'Add \$1,000 to your bankroll? It\'s free — all in-game money is fictional.', 'pt': 'Adicionar \$1.000 ao bankroll? É grátis — todo o dinheiro do jogo é fictício.', 'fr': 'Ajouter 1 000 \$ à votre bankroll ? C\'est gratuit — tout l\'argent du jeu est fictif.', 'de': '\$1.000 zur Bankroll hinzufügen? Kostenlos — alles Spielgeld ist fiktiv.', 'it': 'Aggiungere \$1.000 al bankroll? È gratis — tutto il denaro di gioco è fittizio.'},
    'cancel': {'es': 'Cancelar', 'en': 'Cancel', 'pt': 'Cancelar', 'fr': 'Annuler', 'de': 'Abbrechen', 'it': 'Annulla'},
    'reload_btn': {'es': 'Recargar', 'en': 'Reload', 'pt': 'Recarregar', 'fr': 'Recharger', 'de': 'Aufladen', 'it': 'Ricarica'},

    // Lobby
    'tagline': {'es': '6-Max Cash · Blinds \$1/\$2 · tú eliges la mesa', 'en': '6-Max Cash · Blinds \$1/\$2 · you build the table', 'pt': '6-Max Cash · Blinds \$1/\$2 · você monta a mesa', 'fr': '6-Max Cash · Blinds 1\$/2\$ · vous composez la table', 'de': '6-Max Cash · Blinds \$1/\$2 · du stellst den Tisch zusammen', 'it': '6-Max Cash · Blinds \$1/\$2 · scegli tu il tavolo'},
    'coins_chip': {'es': '🪙 {n} monedas', 'en': '🪙 {n} coins', 'pt': '🪙 {n} moedas', 'fr': '🪙 {n} jetons', 'de': '🪙 {n} Münzen', 'it': '🪙 {n} monete'},
    'your_bankroll': {'es': 'TU BANKROLL', 'en': 'YOUR BANKROLL', 'pt': 'SEU BANKROLL', 'fr': 'VOTRE BANKROLL', 'de': 'DEINE BANKROLL', 'it': 'IL TUO BANKROLL'},
    'sit_btn': {'es': 'SENTARSE EN LA MESA', 'en': 'TAKE A SEAT', 'pt': 'SENTAR À MESA', 'fr': 'S\'ASSEOIR À LA TABLE', 'de': 'AM TISCH PLATZ NEHMEN', 'it': 'SIEDITI AL TAVOLO'},
    'sit_sub': {'es': 'Buy-in: \$200 exactos — igual que todos', 'en': 'Buy-in: exactly \$200 — same as everyone', 'pt': 'Buy-in: \$200 exatos — igual para todos', 'fr': 'Buy-in : 200 \$ exactement — comme tout le monde', 'de': 'Buy-in: genau \$200 — wie alle anderen', 'it': 'Buy-in: \$200 esatti — come tutti'},
    'no_funds': {'es': 'Sin fondos para el buy-in de \$200', 'en': 'Not enough funds for the \$200 buy-in', 'pt': 'Sem fundos para o buy-in de \$200', 'fr': 'Fonds insuffisants pour le buy-in de 200 \$', 'de': 'Nicht genug für das \$200 Buy-in', 'it': 'Fondi insufficienti per il buy-in da \$200'},
    'reload_plus': {'es': 'Recargar +\$1.000', 'en': 'Reload +\$1,000', 'pt': 'Recarregar +\$1.000', 'fr': 'Recharger +1 000 \$', 'de': '+\$1.000 aufladen', 'it': 'Ricarica +\$1.000'},
    'last_session_note': {'es': 'Tu última sesión ({n} manos) sigue disponible en ANALIZAR y VALORACIÓN', 'en': 'Your last session ({n} hands) is still available in ANALYZE and REPORT', 'pt': 'Sua última sessão ({n} mãos) continua em ANALISAR e RELATÓRIO', 'fr': 'Votre dernière session ({n} mains) reste disponible dans ANALYSER et BILAN', 'de': 'Deine letzte Session ({n} Hände) ist weiter in ANALYSE und BERICHT verfügbar', 'it': 'La tua ultima sessione ({n} mani) è ancora in ANALIZZA e REPORT'},
    'edit_table': {'es': 'Editar mesa', 'en': 'Edit table', 'pt': 'Editar mesa', 'fr': 'Modifier la table', 'de': 'Tisch bearbeiten', 'it': 'Modifica tavolo'},
    'simulator': {'es': 'Simulador', 'en': 'Simulator', 'pt': 'Simulador', 'fr': 'Simulateur', 'de': 'Simulator', 'it': 'Simulatore'},
    'settings': {'es': 'Ajustes', 'en': 'Settings', 'pt': 'Ajustes', 'fr': 'Réglages', 'de': 'Einstellungen', 'it': 'Impostazioni'},
    'language': {'es': 'Idioma', 'en': 'Language', 'pt': 'Idioma', 'fr': 'Langue', 'de': 'Sprache', 'it': 'Lingua'},
    'deck_label': {'es': 'Baraja', 'en': 'Deck', 'pt': 'Baralho', 'fr': 'Jeu de cartes', 'de': 'Kartendeck', 'it': 'Mazzo'},
    'deck_4c': {'es': '4 colores (♥♦♣♠ inconfundibles)', 'en': '4 colors (♥♦♣♠ unmistakable)', 'pt': '4 cores (♥♦♣♠ inconfundíveis)', 'fr': '4 couleurs (♥♦♣♠ impossibles à confondre)', 'de': '4 Farben (♥♦♣♠ unverwechselbar)', 'it': '4 colori (♥♦♣♠ inconfondibili)'},
    'deck_classic': {'es': 'Clásica (rojo/negro)', 'en': 'Classic (red/black)', 'pt': 'Clássico (vermelho/preto)', 'fr': 'Classique (rouge/noir)', 'de': 'Klassisch (rot/schwarz)', 'it': 'Classico (rosso/nero)'},

    // Table editor
    'config_title': {'es': 'CONFIGURA TU MESA', 'en': 'BUILD YOUR TABLE', 'pt': 'MONTE SUA MESA', 'fr': 'COMPOSEZ VOTRE TABLE', 'de': 'STELL DEINEN TISCH ZUSAMMEN', 'it': 'COMPONI IL TUO TAVOLO'},
    'config_sub': {'es': 'Elige a tus 5 rivales: leyendas reales o perfiles de estilo. "Aleatorio" sortea uno distinto cada sesión.', 'en': 'Pick your 5 opponents: real legends or style profiles. "Random" draws a different one each session.', 'pt': 'Escolha seus 5 rivais: lendas reais ou perfis de estilo. "Aleatório" sorteia um diferente a cada sessão.', 'fr': 'Choisissez vos 5 adversaires : légendes réelles ou profils de style. « Aléatoire » en tire un différent à chaque session.', 'de': 'Wähle deine 5 Gegner: echte Legenden oder Stilprofile. „Zufällig" lost jede Session neu aus.', 'it': 'Scegli i tuoi 5 avversari: leggende vere o profili di stile. "Casuale" ne estrae uno diverso ogni sessione.'},
    'seat_n': {'es': 'Asiento {n}', 'en': 'Seat {n}', 'pt': 'Assento {n}', 'fr': 'Siège {n}', 'de': 'Platz {n}', 'it': 'Posto {n}'},
    'random': {'es': '🎲 Aleatorio', 'en': '🎲 Random', 'pt': '🎲 Aleatório', 'fr': '🎲 Aléatoire', 'de': '🎲 Zufällig', 'it': '🎲 Casuale'},
    'random_sub': {'es': 'Una leyenda o perfil distinto cada sesión', 'en': 'A different legend or profile each session', 'pt': 'Uma lenda ou perfil diferente a cada sessão', 'fr': 'Une légende ou un profil différent à chaque session', 'de': 'Jede Session eine andere Legende oder ein anderes Profil', 'it': 'Una leggenda o profilo diverso ogni sessione'},
    'legends_hdr': {'es': 'LEYENDAS', 'en': 'LEGENDS', 'pt': 'LENDAS', 'fr': 'LÉGENDES', 'de': 'LEGENDEN', 'it': 'LEGGENDE'},
    'styles_hdr': {'es': 'PERFILES DE ESTILO', 'en': 'STYLE PROFILES', 'pt': 'PERFIS DE ESTILO', 'fr': 'PROFILS DE STYLE', 'de': 'STILPROFILE', 'it': 'PROFILI DI STILE'},
    'reset_random': {'es': 'Restablecer todo a aleatorio', 'en': 'Reset all to random', 'pt': 'Redefinir tudo para aleatório', 'fr': 'Tout remettre en aléatoire', 'de': 'Alles auf zufällig zurücksetzen', 'it': 'Reimposta tutto su casuale'},

    // Analyze
    'analyze_title': {'es': 'ANALIZAR JUGADAS', 'en': 'ANALYZE HANDS', 'pt': 'ANALISAR MÃOS', 'fr': 'ANALYSER LES MAINS', 'de': 'HÄNDE ANALYSIEREN', 'it': 'ANALIZZA LE MANI'},
    'hands_n': {'es': '{n} manos', 'en': '{n} hands', 'pt': '{n} mãos', 'fr': '{n} mains', 'de': '{n} Hände', 'it': '{n} mani'},
    'no_hands1': {'es': 'Aún no hay manos jugadas', 'en': 'No hands played yet', 'pt': 'Nenhuma mão jogada ainda', 'fr': 'Aucune main jouée pour l\'instant', 'de': 'Noch keine Hände gespielt', 'it': 'Nessuna mano giocata ancora'},
    'no_hands2': {'es': 'Juega manos y el Puxi te las destripará aquí', 'en': 'Play some hands and el Puxi will tear them apart here', 'pt': 'Jogue mãos e o el Puxi vai destrinchá-las aqui', 'fr': 'Jouez des mains et el Puxi les décortiquera ici', 'de': 'Spiel ein paar Hände und el Puxi nimmt sie hier auseinander', 'it': 'Gioca qualche mano e el Puxi le farà a pezzi qui'},
    'clean_fold': {'es': 'Fold limpio', 'en': 'Clean fold', 'pt': 'Fold limpo', 'fr': 'Fold propre', 'de': 'Sauberer Fold', 'it': 'Fold pulito'},
    'review_link': {'es': 'Revisar', 'en': 'Review', 'pt': 'Revisar', 'fr': 'Revoir', 'de': 'Ansehen', 'it': 'Rivedi'},
    'hand_title': {'es': 'Mano #{n}', 'en': 'Hand #{n}', 'pt': 'Mão #{n}', 'fr': 'Main n°{n}', 'de': 'Hand Nr. {n}', 'it': 'Mano n.{n}'},
    'won_hand': {'es': 'Ganaste esta mano', 'en': 'You won this hand', 'pt': 'Você ganhou esta mão', 'fr': 'Vous avez gagné cette main', 'de': 'Du hast diese Hand gewonnen', 'it': 'Hai vinto questa mano'},
    'lost_hand': {'es': 'Perdiste esta mano', 'en': 'You lost this hand', 'pt': 'Você perdeu esta mão', 'fr': 'Vous avez perdu cette main', 'de': 'Du hast diese Hand verloren', 'it': 'Hai perso questa mano'},
    'clean_fold_banner': {'es': 'Fold limpio — dinero ahorrado', 'en': 'Clean fold — money saved', 'pt': 'Fold limpo — dinheiro economizado', 'fr': 'Fold propre — argent économisé', 'de': 'Sauberer Fold — Geld gespart', 'it': 'Fold pulito — soldi risparmiati'},
    'winner_lbl': {'es': 'Ganador: {w}', 'en': 'Winner: {w}', 'pt': 'Vencedor: {w}', 'fr': 'Gagnant : {w}', 'de': 'Gewinner: {w}', 'it': 'Vincitore: {w}'},
    'pot_short': {'es': 'Bote: \${v}', 'en': 'Pot: \${v}', 'pt': 'Pote: \${v}', 'fr': 'Pot : {v} \$', 'de': 'Pot: \${v}', 'it': 'Piatto: \${v}'},
    'your_hand': {'es': 'TU MANO', 'en': 'YOUR HAND', 'pt': 'SUA MÃO', 'fr': 'VOTRE MAIN', 'de': 'DEINE HAND', 'it': 'LA TUA MANO'},
    'all_hands_sd': {'es': 'TODAS LAS MANOS (SHOWDOWN)', 'en': 'ALL HANDS (SHOWDOWN)', 'pt': 'TODAS AS MÃOS (SHOWDOWN)', 'fr': 'TOUTES LES MAINS (SHOWDOWN)', 'de': 'ALLE HÄNDE (SHOWDOWN)', 'it': 'TUTTE LE MANI (SHOWDOWN)'},
    'timeline': {'es': 'CRONOLOGÍA DE LA MANO', 'en': 'HAND TIMELINE', 'pt': 'CRONOLOGIA DA MÃO', 'fr': 'CHRONOLOGIE DE LA MAIN', 'de': 'HAND-VERLAUF', 'it': 'CRONOLOGIA DELLA MANO'},
    'action_lbl': {'es': 'Acción', 'en': 'Action', 'pt': 'Ação', 'fr': 'Action', 'de': 'Aktion', 'it': 'Azione'},
    'zeros_sub': {'es': 'Tu equity calle a calle. Aviso: no tengo filtro.', 'en': 'Your equity street by street. Warning: I have no filter.', 'pt': 'Sua equity rua a rua. Aviso: não tenho filtro.', 'fr': 'Votre equity rue par rue. Attention : je n\'ai aucun filtre.', 'de': 'Deine Equity Street für Street. Warnung: Ich habe keinen Filter.', 'it': 'La tua equity street per street. Avviso: non ho filtri.'},

    // Quality labels
    'q_optimal': {'es': 'Óptima', 'en': 'Optimal', 'pt': 'Ótima', 'fr': 'Optimale', 'de': 'Optimal', 'it': 'Ottimale'},
    'q_correct': {'es': 'Correcta', 'en': 'Correct', 'pt': 'Correta', 'fr': 'Correcte', 'de': 'Korrekt', 'it': 'Corretta'},
    'q_marginal': {'es': 'Marginal', 'en': 'Marginal', 'pt': 'Marginal', 'fr': 'Marginale', 'de': 'Marginal', 'it': 'Marginale'},
    'q_blunder': {'es': 'Error Grave', 'en': 'Blunder', 'pt': 'Erro Grave', 'fr': 'Grosse Erreur', 'de': 'Grober Fehler', 'it': 'Errore Grave'},

    // Stats screen
    'stats_title': {'es': 'VALORACIÓN GLOBAL', 'en': 'GLOBAL REPORT', 'pt': 'RELATÓRIO GLOBAL', 'fr': 'BILAN GLOBAL', 'de': 'GESAMTBERICHT', 'it': 'REPORT GLOBALE'},
    'no_data1': {'es': 'Sin datos de sesión todavía', 'en': 'No session data yet', 'pt': 'Sem dados de sessão ainda', 'fr': 'Pas encore de données de session', 'de': 'Noch keine Session-Daten', 'it': 'Ancora nessun dato di sessione'},
    'no_data2': {'es': 'Juega manos para generar tu informe de rendimiento', 'en': 'Play hands to generate your performance report', 'pt': 'Jogue mãos para gerar seu relatório de desempenho', 'fr': 'Jouez des mains pour générer votre rapport de performance', 'de': 'Spiele Hände, um deinen Leistungsbericht zu erzeugen', 'it': 'Gioca delle mani per generare il tuo report'},
    'hands_played': {'es': 'Manos jugadas', 'en': 'Hands played', 'pt': 'Mãos jogadas', 'fr': 'Mains jouées', 'de': 'Gespielte Hände', 'it': 'Mani giocate'},
    'net_result': {'es': 'Resultado neto', 'en': 'Net result', 'pt': 'Resultado líquido', 'fr': 'Résultat net', 'de': 'Nettoergebnis', 'it': 'Risultato netto'},
    'decision_note': {'es': 'Nota de decisiones: {s}/100 — {r}', 'en': 'Decision score: {s}/100 — {r}', 'pt': 'Nota de decisões: {s}/100 — {r}', 'fr': 'Note de décisions : {s}/100 — {r}', 'de': 'Entscheidungsnote: {s}/100 — {r}', 'it': 'Voto decisioni: {s}/100 — {r}'},
    'rating_elite': {'es': 'Élite', 'en': 'Elite', 'pt': 'Elite', 'fr': 'Élite', 'de': 'Elite', 'it': 'Élite'},
    'rating_solid': {'es': 'Sólido', 'en': 'Solid', 'pt': 'Sólido', 'fr': 'Solide', 'de': 'Solide', 'it': 'Solido'},
    'rating_avg': {'es': 'Del montón', 'en': 'Average', 'pt': 'Mediano', 'fr': 'Moyen', 'de': 'Durchschnitt', 'it': 'Nella media'},
    'rating_leaky': {'es': 'Con fugas', 'en': 'Leaky', 'pt': 'Com vazamentos', 'fr': 'Avec des leaks', 'de': 'Mit Leaks', 'it': 'Pieno di leak'},
    'rating_bad': {'es': 'Desastre', 'en': 'Disaster', 'pt': 'Desastre', 'fr': 'Désastre', 'de': 'Desaster', 'it': 'Disastro'},
    'kpi_title': {'es': 'KPIs DE RENDIMIENTO', 'en': 'PERFORMANCE KPIs', 'pt': 'KPIs DE DESEMPENHO', 'fr': 'KPIs DE PERFORMANCE', 'de': 'LEISTUNGS-KPIs', 'it': 'KPI DI RENDIMENTO'},
    'kpi_hint': {'es': 'Toca cada métrica y te explico qué significa y cómo mejorarla', 'en': 'Tap any metric and I\'ll explain what it means and how to improve it', 'pt': 'Toque em cada métrica e eu explico o que significa e como melhorar', 'fr': 'Touchez chaque métrique : je vous explique sa signification et comment l\'améliorer', 'de': 'Tippe auf eine Kennzahl und ich erkläre dir Bedeutung und Verbesserung', 'it': 'Tocca ogni metrica e ti spiego cosa significa e come migliorarla'},
    'target_lbl': {'es': 'Meta: {t}', 'en': 'Target: {t}', 'pt': 'Meta: {t}', 'fr': 'Objectif : {t}', 'de': 'Ziel: {t}', 'it': 'Obiettivo: {t}'},
    'what_means': {'es': 'QUÉ SIGNIFICA', 'en': 'WHAT IT MEANS', 'pt': 'O QUE SIGNIFICA', 'fr': 'CE QUE ÇA SIGNIFIE', 'de': 'WAS ES BEDEUTET', 'it': 'COSA SIGNIFICA'},
    'objective_lbl': {'es': 'OBJETIVO: ', 'en': 'TARGET: ', 'pt': 'OBJETIVO: ', 'fr': 'OBJECTIF : ', 'de': 'ZIEL: ', 'it': 'OBIETTIVO: '},
    'how_improve': {'es': 'CÓMO MEJORARLO', 'en': 'HOW TO IMPROVE IT', 'pt': 'COMO MELHORAR', 'fr': 'COMMENT L\'AMÉLIORER', 'de': 'WIE DU ES VERBESSERST', 'it': 'COME MIGLIORARLO'},
    'out_of_range': {'es': '(y tú fuera de rango, cómo no)', 'en': '(and you\'re out of range, of course)', 'pt': '(e você fora da faixa, claro)', 'fr': '(et vous êtes hors cible, évidemment)', 'de': '(und du liegst daneben, natürlich)', 'it': '(e tu sei fuori range, ovviamente)'},
    'decisions_hdr': {'es': 'DESGLOSE DE DECISIONES', 'en': 'DECISION BREAKDOWN', 'pt': 'DETALHAMENTO DE DECISÕES', 'fr': 'DÉTAIL DES DÉCISIONS', 'de': 'ENTSCHEIDUNGSÜBERSICHT', 'it': 'DETTAGLIO DECISIONI'},
    'optimal_pl': {'es': 'Óptimas', 'en': 'Optimal', 'pt': 'Ótimas', 'fr': 'Optimales', 'de': 'Optimal', 'it': 'Ottimali'},
    'blunders_pl': {'es': 'Errores graves', 'en': 'Blunders', 'pt': 'Erros graves', 'fr': 'Grosses erreurs', 'de': 'Grobe Fehler', 'it': 'Errori gravi'},
    'coach_hdr': {'es': 'INFORME DE EL PUXI', 'en': 'EL PUXI REPORT', 'pt': 'RELATÓRIO DO EL PUXI', 'fr': 'RAPPORT DE EL PUXI', 'de': 'EL PUXI-BERICHT', 'it': 'REPORT DI EL PUXI'},
    'coach_sub': {'es': 'Análisis táctico sin anestesia', 'en': 'Tactical analysis without anesthesia', 'pt': 'Análise tática sem anestesia', 'fr': 'Analyse tactique sans anesthésie', 'de': 'Taktische Analyse ohne Betäubung', 'it': 'Analisi tattica senza anestesia'},

    // Year screen
    'year_title': {'es': 'PROGRESO ANUAL', 'en': 'YEARLY PROGRESS', 'pt': 'PROGRESSO ANUAL', 'fr': 'PROGRÈS ANNUEL', 'de': 'JAHRESFORTSCHRITT', 'it': 'PROGRESSI ANNUALI'},
    'coins_amount': {'es': '{n} monedas', 'en': '{n} coins', 'pt': '{n} moedas', 'fr': '{n} jetons', 'de': '{n} Münzen', 'it': '{n} monete'},
    'coins_free': {'es': 'Totalmente gratis: ganas 1 moneda por mano jugada y 5 extra por mano ganada. Acumúlalas jugando, sin pagar nada.', 'en': 'Completely free: you earn 1 coin per hand played and 5 extra per hand won. Stack them by playing — never pay a thing.', 'pt': 'Totalmente grátis: 1 moeda por mão jogada e 5 extras por mão ganha. Acumule jogando, sem pagar nada.', 'fr': 'Entièrement gratuit : 1 jeton par main jouée et 5 de plus par main gagnée. Accumulez-les en jouant, sans jamais payer.', 'de': 'Völlig kostenlos: 1 Münze pro gespielter Hand, 5 extra pro gewonnener Hand. Sammle sie durchs Spielen — ohne zu zahlen.', 'it': 'Completamente gratis: 1 moneta per mano giocata e 5 extra per mano vinta. Accumulale giocando, senza pagare nulla.'},
    'no_archive1': {'es': 'Sin sesiones archivadas todavía', 'en': 'No archived sessions yet', 'pt': 'Nenhuma sessão arquivada ainda', 'fr': 'Aucune session archivée pour l\'instant', 'de': 'Noch keine archivierten Sessions', 'it': 'Nessuna sessione archiviata ancora'},
    'no_archive2': {'es': 'Cada vez que te levantes de la mesa, la sesión queda guardada aquí para medir tu evolución durante el año.', 'en': 'Every time you leave the table, the session is saved here to track your evolution through the year.', 'pt': 'Sempre que você se levantar da mesa, a sessão fica salva aqui para medir sua evolução no ano.', 'fr': 'Chaque fois que vous quittez la table, la session est enregistrée ici pour suivre votre évolution sur l\'année.', 'de': 'Jedes Mal, wenn du den Tisch verlässt, wird die Session hier gespeichert, um deine Entwicklung übers Jahr zu messen.', 'it': 'Ogni volta che lasci il tavolo, la sessione viene salvata qui per misurare la tua evoluzione nell\'anno.'},
    'sessions_lbl': {'es': 'Sesiones', 'en': 'Sessions', 'pt': 'Sessões', 'fr': 'Sessions', 'de': 'Sessions', 'it': 'Sessioni'},
    'hands_lbl': {'es': 'Manos', 'en': 'Hands', 'pt': 'Mãos', 'fr': 'Mains', 'de': 'Hände', 'it': 'Mani'},
    'net_lbl': {'es': 'Neto', 'en': 'Net', 'pt': 'Líquido', 'fr': 'Net', 'de': 'Netto', 'it': 'Netto'},
    'note_lbl': {'es': 'Nota', 'en': 'Score', 'pt': 'Nota', 'fr': 'Note', 'de': 'Note', 'it': 'Voto'},
    'date_lbl': {'es': 'Fecha', 'en': 'Date', 'pt': 'Data', 'fr': 'Date', 'de': 'Datum', 'it': 'Data'},
    'history_hdr': {'es': 'HISTORIAL DE SESIONES', 'en': 'SESSION HISTORY', 'pt': 'HISTÓRICO DE SESSÕES', 'fr': 'HISTORIQUE DES SESSIONS', 'de': 'SESSION-VERLAUF', 'it': 'STORICO SESSIONI'},
    'evolution_hdr': {'es': 'EVOLUCIÓN — EL PUXI', 'en': 'EVOLUTION — EL PUXI', 'pt': 'EVOLUÇÃO — EL PUXI', 'fr': 'ÉVOLUTION — EL PUXI', 'de': 'ENTWICKLUNG — EL PUXI', 'it': 'EVOLUZIONE — EL PUXI'},
    'evolution_sub': {'es': 'Qué estás mejorando entre sesiones (y qué no)', 'en': 'What you\'re improving between sessions (and what you\'re not)', 'pt': 'O que você está melhorando entre sessões (e o que não)', 'fr': 'Ce que vous améliorez entre les sessions (et ce que non)', 'de': 'Was du zwischen Sessions verbesserst (und was nicht)', 'it': 'Cosa stai migliorando tra le sessioni (e cosa no)'},

    // Simulator
    'sim_title': {'es': 'SIMULADOR DE EQUITY', 'en': 'EQUITY SIMULATOR', 'pt': 'SIMULADOR DE EQUITY', 'fr': 'SIMULATEUR D\'EQUITY', 'de': 'EQUITY-SIMULATOR', 'it': 'SIMULATORE DI EQUITY'},
    'sim_opponents': {'es': 'Rivales', 'en': 'Opponents', 'pt': 'Rivais', 'fr': 'Adversaires', 'de': 'Gegner', 'it': 'Avversari'},
    'sim_pick': {'es': 'Elige una carta', 'en': 'Pick a card', 'pt': 'Escolha uma carta', 'fr': 'Choisissez une carte', 'de': 'Wähle eine Karte', 'it': 'Scegli una carta'},
    'sim_prompt': {'es': 'Elige tus dos cartas para calcular la equity', 'en': 'Pick your two cards to calculate equity', 'pt': 'Escolha suas duas cartas para calcular a equity', 'fr': 'Choisissez vos deux cartes pour calculer l\'equity', 'de': 'Wähle deine zwei Karten, um die Equity zu berechnen', 'it': 'Scegli le tue due carte per calcolare l\'equity'},
    'puxi_chat': {'es': 'Pregúntale a el Puxi', 'en': 'Ask el Puxi', 'pt': 'Pergunte ao el Puxi', 'fr': 'Demande à el Puxi', 'de': 'Frag el Puxi', 'it': 'Chiedi a el Puxi'},
    'puxi_greeting': {'es': '¡Eh! Soy el Puxi, tu coach. Pregúntame lo que quieras de poker: equity, pot odds, MDF, SPR, blockers, rangos, faroles... o toca un tema de abajo. Sin filtro, como siempre.', 'en': 'Hey! I\'m el Puxi, your coach. Ask me anything about poker: equity, pot odds, MDF, SPR, blockers, ranges, bluffs... or tap a topic below. No filter, as usual.', 'pt': 'Ei! Sou o el Puxi, seu coach. Pergunte qualquer coisa de poker: equity, pot odds, MDF, SPR, blockers, ranges, blefes... ou toque num tema abaixo.', 'fr': 'Hé ! Je suis el Puxi, ton coach. Demande-moi tout sur le poker : equity, pot odds, MDF, SPR, blockers, ranges, bluffs... ou touche un thème ci-dessous.', 'de': 'Hey! Ich bin el Puxi, dein Coach. Frag mich alles über Poker: equity, pot odds, MDF, SPR, blockers, ranges, bluffs... oder tippe unten ein Thema an.', 'it': 'Ehi! Sono el Puxi, il tuo coach. Chiedimi qualsiasi cosa di poker: equity, pot odds, MDF, SPR, blockers, range, bluff... o tocca un tema qui sotto.'},
    'puxi_no_match': {'es': 'No pillo bien la pregunta, campeón. Prueba con una palabra clave: equity, pot odds, MDF, SPR, blockers, posición, c-bet, 3-bet, rango, semi-bluff, tilt, bankroll, river... o toca un tema.', 'en': 'I don\'t quite get the question, champ. Try a keyword: equity, pot odds, MDF, SPR, blockers, position, c-bet, 3-bet, range, semi-bluff, tilt, bankroll, river... or tap a topic.', 'pt': 'Não peguei a pergunta, campeão. Tenta uma palavra-chave: equity, pot odds, MDF, SPR, blockers, posição, c-bet, 3-bet, range, semi-bluff, tilt, bankroll, river...', 'fr': 'Je ne saisis pas bien, champion. Essaie un mot-clé : equity, pot odds, MDF, SPR, blockers, position, c-bet, 3-bet, range, semi-bluff, tilt, bankroll, river...', 'de': 'Ich verstehe die Frage nicht ganz, Champion. Versuch ein Stichwort: equity, pot odds, MDF, SPR, blockers, position, c-bet, 3-bet, range, semi-bluff, tilt, bankroll, river...', 'it': 'Non afferro bene la domanda, campione. Prova una parola chiave: equity, pot odds, MDF, SPR, blockers, posizione, c-bet, 3-bet, range, semi-bluff, tilt, bankroll, river...'},
    'ask_placeholder': {'es': 'Escribe tu duda de poker...', 'en': 'Type your poker question...', 'pt': 'Escreva sua dúvida de poker...', 'fr': 'Écris ta question poker...', 'de': 'Schreib deine Poker-Frage...', 'it': 'Scrivi la tua domanda di poker...'},
    'sim_equity_in': {'es': 'EQUITY EN {s} vs {n} rival(es)', 'en': 'EQUITY ON {s} vs {n} opponent(s)', 'pt': 'EQUITY NO {s} vs {n} rival(is)', 'fr': 'EQUITY AU {s} vs {n} adversaire(s)', 'de': 'EQUITY AM {s} vs {n} Gegner', 'it': 'EQUITY AL {s} vs {n} avversario/i'},
  };
}
