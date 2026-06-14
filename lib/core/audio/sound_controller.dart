import '../../data/models/hand_log_model.dart';
import '../../engine/poker_engine.dart';
import 'sound_service.dart';

/// Turns game-state transitions into sound effects by diffing successive
/// [GameState]s, plus direct helpers for UI/meta events. Keeps the engine
/// itself audio-free.
class SoundController {
  final SoundService service;
  GameState? _prev;

  SoundController(this.service);

  bool get enabled => service.enabled;
  set enabled(bool v) => service.enabled = v;

  /// Seeds the previous state without emitting any sound (used at sit-down so
  /// the very first deal still produces a shuffle).
  void seed(GameState s) => _prev = s;

  void onState(GameState s) {
    final prev = _prev;
    _prev = s;
    if (prev == null) return;

    // New hand dealt → shuffle (skip the rest this tick).
    if (s.handNumber != prev.handNumber && s.phase == GamePhase.preflop) {
      service.play(Snd.shuffle);
      return;
    }

    // A new action was committed by anyone → play its sound.
    if (s.currentHandActions.length > prev.currentHandActions.length) {
      _playAction(s.currentHandActions.last.type);
    }

    // A street was dealt (community cards grew).
    final nc = s.communityCards.length;
    if (nc > prev.communityCards.length) {
      if (nc == 3) {
        service.play(Snd.flop);
      } else if (nc == 4 || nc == 5) {
        service.play(Snd.card);
      }
    }

    // It just became the human's turn.
    if (s.awaitingHumanAction && !prev.awaitingHumanAction) {
      service.play(Snd.yourTurn);
    }

    // Hand finished and the human took (a share of) the pot.
    if (s.phase == GamePhase.handComplete &&
        prev.phase != GamePhase.handComplete) {
      if (s.players.any((p) => p.isHuman && p.isWinner)) {
        service.play(Snd.potWin);
      }
    }
  }

  void _playAction(ActionType type) {
    switch (type) {
      case ActionType.check:
        service.play(Snd.check);
        break;
      case ActionType.call:
        service.play(Snd.call);
        break;
      case ActionType.bet:
      case ActionType.raise:
        service.play(Snd.raise);
        break;
      case ActionType.allIn:
        service.play(Snd.allin);
        break;
      case ActionType.fold:
        service.play(Snd.fold);
        break;
    }
  }

  // ── Direct UI / meta events ──
  void tap() => service.play(Snd.tap);
  void puxi() => service.play(Snd.puxi);
  void sitDown() => service.play(Snd.sitDown);
  void achievement() => service.play(Snd.achievement);
  void streak() => service.play(Snd.streak);
  void trainerResult(DecisionQuality q) => service.play(
      q == DecisionQuality.blunder ? Snd.trainerBad : Snd.trainerGood);

  void dispose() => service.dispose();
}
