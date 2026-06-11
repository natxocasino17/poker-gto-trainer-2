import 'card_model.dart';

enum TablePosition { utg, mp, co, btn, sb, bb }

class PlayerModel {
  final String id;
  final String name;
  final bool isHuman;
  final double stack;
  final List<CardModel> holeCards;
  final bool isFolded;
  final bool isAllIn;
  final double streetBet;
  final double totalHandBet;
  final TablePosition position;
  final bool isDealer;
  final String? legendName;
  final bool cardsVisible;
  final bool isWinner;
  final double? foldRate;

  const PlayerModel({
    required this.id,
    required this.name,
    required this.isHuman,
    required this.stack,
    this.holeCards = const [],
    this.isFolded = false,
    this.isAllIn = false,
    this.streetBet = 0,
    this.totalHandBet = 0,
    this.position = TablePosition.utg,
    this.isDealer = false,
    this.legendName,
    this.cardsVisible = false,
    this.isWinner = false,
    this.foldRate = 0.5,
  });

  bool get isActive => !isFolded && !isAllIn;
  bool get canAct => isActive && stack > 0;

  String get positionLabel {
    switch (position) {
      case TablePosition.utg: return 'UTG';
      case TablePosition.mp: return 'MP';
      case TablePosition.co: return 'CO';
      case TablePosition.btn: return 'BTN';
      case TablePosition.sb: return 'SB';
      case TablePosition.bb: return 'BB';
    }
  }

  PlayerModel copyWith({
    String? id,
    String? name,
    bool? isHuman,
    double? stack,
    List<CardModel>? holeCards,
    bool? isFolded,
    bool? isAllIn,
    double? streetBet,
    double? totalHandBet,
    TablePosition? position,
    bool? isDealer,
    String? legendName,
    bool? cardsVisible,
    bool? isWinner,
    double? foldRate,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isHuman: isHuman ?? this.isHuman,
      stack: stack ?? this.stack,
      holeCards: holeCards ?? this.holeCards,
      isFolded: isFolded ?? this.isFolded,
      isAllIn: isAllIn ?? this.isAllIn,
      streetBet: streetBet ?? this.streetBet,
      totalHandBet: totalHandBet ?? this.totalHandBet,
      position: position ?? this.position,
      isDealer: isDealer ?? this.isDealer,
      legendName: legendName ?? this.legendName,
      cardsVisible: cardsVisible ?? this.cardsVisible,
      isWinner: isWinner ?? this.isWinner,
      foldRate: foldRate ?? this.foldRate,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isHuman': isHuman,
    'stack': stack,
    'legendName': legendName,
    'foldRate': foldRate,
  };
}
