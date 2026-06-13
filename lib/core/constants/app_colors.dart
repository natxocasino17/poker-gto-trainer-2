import 'package:flutter/material.dart';

/// iPT palette — warm, cozy, premium "Mood Diary"-inspired identity:
/// teal + sand/gold + terracotta + cream over a warm dark base (kept dark
/// for poker-table readability). Field names are unchanged so the reskin is
/// purely visual and nothing structural breaks.
class AppColors {
  // Warm dark teal-charcoal base (cozy, not cold black)
  static const background = Color(0xFF14201E);
  static const surface = Color(0xFF1C2B27);
  static const surfaceElevated = Color(0xFF24372F);
  static const card = Color(0xFF223330);

  // Warm wood / terracotta rail tones
  static const wood = Color(0xFF6E4A2E);
  static const woodLight = Color(0xFF95673B);
  static const woodDark = Color(0xFF2A1A10);

  // Felt — warm emerald (poker necessity), tuned to the cozy palette
  static const felt = Color(0xFF1E6B4A);
  static const feltLight = Color(0xFF2E8B5A);
  static const feltDark = Color(0xFF134E37);
  static const tableRail = Color(0xFF7A4A2C);
  static const tableRailLight = Color(0xFFA8703E);

  // Primary accent — the reference teal
  static const accent = Color(0xFF2DB9A2);
  static const accentDark = Color(0xFF1E8C7A);
  static const accentGlow = Color(0x332DB9A2);

  // Warm sand / honey gold
  static const gold = Color(0xFFE8B85C);
  static const goldDark = Color(0xFFC99536);

  // Cream text on warm dark
  static const textPrimary = Color(0xFFFFF6E6);
  static const textSecondary = Color(0xFFD8C9B4);
  static const textMuted = Color(0xFF9A8A74);

  // Four-color deck (faces are vector-drawn; these stay vivid)
  static const cardFace = Color(0xFFFFFDF6);
  static const cardBack = Color(0xFF1E8C7A);
  static const cardBackPattern = Color(0xFF2DB9A2);
  static const suitHearts = Color(0xFFD7263D);
  static const suitDiamonds = Color(0xFF2979FF);
  static const suitClubs = Color(0xFF1F9D55);
  static const suitSpades = Color(0xFF2B2D42);

  static const redSuit = Color(0xFFD7263D);
  static const blackSuit = Color(0xFF2B2D42);

  // Chips — warm casino set
  static const chipBlue = Color(0xFF2B8FB3);
  static const chipRed = Color(0xFFC0573F);
  static const chipGreen = Color(0xFF2E8B5A);
  static const chipBlack = Color(0xFF2B2D42);
  static const chipWhite = Color(0xFFF3ECDD);

  // Action buttons — warm, cohesive (functional meaning preserved)
  static const actionFold = Color(0xFFC0573F); // terracotta
  static const actionCall = Color(0xFF3E86AE); // soft blue-teal
  static const actionRaise = Color(0xFF3E9E73); // warm green
  static const actionCheck = Color(0xFF6E7E74); // muted sage

  static const winning = Color(0xFF49C088);
  static const losing = Color(0xFFE0644A);
  static const neutral = Color(0xFF9AA39A);

  static const gtoOptimal = Color(0xFF2DB9A2);
  static const gtoCorrect = Color(0xFF7BC47F);
  static const gtoMarginal = Color(0xFFE8B85C);
  static const gtoBlunder = Color(0xFFE0644A);

  static const divider = Color(0xFF2E423C);
  static const border = Color(0xFF34504A);
}
