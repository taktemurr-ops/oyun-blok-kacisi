import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';

import 'escape_engine.dart';

const blokKacisiId = 'oyun-blok-kacisi';

class EscapeRules extends GameRules<EscapeLevel> {
  @override
  String get gameId => blokKacisiId;

  @override
  List<String> get optionalMechanics => const [];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.daily, GameModeId.weekly, GameModeId.challenge];

  @override
  List<GameStat> get gameStats => const [
        GameStat('blocks_escaped', 'Kaçan blok', 'Blocks escaped', scale: 80),
        GameStat('boards_cleared', 'Boşaltılan tahta', 'Boards cleared', scale: 5),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('escaped', 'blocks_escaped', [30, 80, 200]),
        MissionTemplate('boards', 'boards_cleared', [3, 6, 12]),
      ];

  @override
  EscapeLevel generate(LevelSpec spec) => generateEscapeLevel(spec);

  @override
  Validation validate(EscapeLevel level, LevelSpec spec) {
    final g = EscapeGame(level);
    if (g.blocks.length < 3) return const Validation.fail('too few blocks');
    final seen = <int>{};
    for (final b in g.blocks) {
      for (final c in b.cells(level.w)) {
        if (!seen.add(c)) return const Validation.fail('overlap');
      }
    }
    final n = g.solveCount();
    if (n < 0) return const Validation.fail('not solvable');
    return Validation.ok(n);
  }

  /// Hamle sınırı: zor bölümlerde blok sayısı + biraz pay; yanlış dokunuş pahalı.
  EscapeLevel finalize(GeneratedLevel<EscapeLevel> g) {
    final l = g.puzzle;
    final n = g.validation.metric;
    final limit = l.difficulty >= 4 ? n + (12 - l.difficulty).clamp(2, 8) : 0;
    return EscapeLevel(w: l.w, h: l.h, blocks: l.blocks, seed: l.seed, difficulty: l.difficulty, moveLimit: limit);
  }

  static int stars(EscapeGame g) => !g.won ? 0 : (g.bumps == 0 ? 3 : (g.bumps <= 2 ? 2 : 1));
}
