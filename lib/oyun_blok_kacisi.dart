/// Blok Kaçışı: okun yönünde kaydır, tahtayı boşalt.
/// Blok Oyunları merkez uygulamasının oyunu.
library;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';

import 'src/escape_rules.dart';
import 'src/escape_view.dart';

export 'src/escape_engine.dart';
export 'src/escape_rules.dart';

final blokKacisiConfig = GameConfig(
  gameId: blokKacisiId,
  title: const ['Blok Kaçışı', 'Block Escape', 'Block-Flucht', 'Escape de Bloques', 'Évasion de Blocs'],
  tagline: const [
    'Sırayı bul, hepsini çıkar!',
    'Find the order, clear them all!',
    'Finde die Reihenfolge!',
    '¡Encuentra el orden!',
    'Trouvez le bon ordre !',
  ],
  seedColor: const Color(0xFF26A69A),
  icon: Icons.open_in_new_rounded,
  rules: EscapeRules(),
  buildPlay: (ctx) => EscapeView(ctx: ctx),
  tutorial: const [
    TutorialStep(Icons.touch_app, [
      'Bir bloğa dokun: okunun yönünde kayar. Önü boşsa tahtadan çıkar.',
      'Tap a block: it slides along its arrow and leaves if the way is clear.',
      'Tippe einen Block an: er gleitet in Pfeilrichtung hinaus.',
      'Toca un bloque: se desliza según su flecha y sale.',
      'Touchez un bloc : il glisse selon sa flèche et sort.',
    ]),
    TutorialStep(Icons.warning_amber, [
      'Önü kapalı bloğa dokunursan çarpar ve hamle harcanır. Sırayı iyi düşün!',
      'A blocked block bumps and wastes a move. Plan the order!',
      'Blockierte Blöcke stoßen an und kosten einen Zug.',
      'Un bloque bloqueado choca y gasta un movimiento.',
      'Un bloc bloqué cogne et gaspille un coup.',
    ]),
  ],
);
