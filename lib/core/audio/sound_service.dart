import 'package:audioplayers/audioplayers.dart';

/// Sound effect ids → asset paths (under assets/audio/). Replace the silent
/// placeholder .wav files with real sounds keeping the same names.
class Snd {
  static const check = 'check';
  static const call = 'call';
  static const raise = 'raise'; // bet + raise
  static const allin = 'allin';
  static const fold = 'fold';
  static const deal = 'deal';
  static const flop = 'flop';
  static const card = 'card'; // turn / river
  static const shuffle = 'shuffle'; // new hand
  static const potWin = 'potwin';
  static const yourTurn = 'yourturn';
  static const tap = 'tap';
  static const puxi = 'puxi';
  static const trainerGood = 'trainer_good';
  static const trainerBad = 'trainer_bad';
  static const achievement = 'achievement';
  static const streak = 'streak';
  static const sitDown = 'sitdown';
}

/// Thin, fail-safe wrapper over audioplayers. One reusable player per sound id
/// so overlapping effects (e.g. chips + ding) don't cut each other off. Any
/// playback error (missing/invalid asset) is swallowed so audio never crashes
/// the game.
class SoundService {
  bool enabled;
  double volume;
  final Map<String, AudioPlayer> _players = {};

  SoundService({this.enabled = true, this.volume = 0.85});

  Future<void> play(String id) async {
    if (!enabled) return;
    try {
      var player = _players[id];
      if (player == null) {
        player = AudioPlayer();
        _players[id] = player;
        await player.setReleaseMode(ReleaseMode.stop);
      }
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource('audio/$id.wav'));
    } catch (_) {
      // ignore — a missing or unsupported file must never break gameplay
    }
  }

  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    _players.clear();
  }
}
