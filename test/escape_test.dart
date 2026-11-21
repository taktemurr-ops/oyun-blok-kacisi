import 'package:flutter_test/flutter_test.dart';
import 'package:oyun_blok_kacisi/oyun_blok_kacisi.dart';
import 'package:studio_core/core/level_plan.dart';

void main() {
  final rules = EscapeRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('bölümler çözülebilir ve ipucuyla çözülür', () {
    for (final lv in [1, 12, 50, 99, 230, 777, 2500, 9999, 33333, 49999]) {
      final gl = rules.build(planner.spec(lv));
      expect(gl.validation.ok, isTrue, reason: 'bölüm $lv');
      expect(gl.attempts, 0, reason: 'bölüm $lv yeniden üretildi');
      final l = rules.finalize(gl);
      final g = EscapeGame(l);
      while (!g.won) {
        final i = g.hint();
        expect(i, isNotNull);
        expect(g.tap(i!), 2);
      }
      expect(g.bumps, 0);
      if (l.moveLimit > 0) expect(g.moves, lessThanOrEqualTo(l.moveLimit));
    }
  });

  test('kapalı blok çarpar, geri al çalışır', () {
    final l = rules.build(planner.spec(300)).puzzle;
    final g = EscapeGame(l);
    final stuck = [for (var i = 0; i < g.blocks.length; i++) if (!g.pathClear(g.blocks[i])) i];
    expect(stuck, isNotEmpty);
    final before = g.serialize();
    final res = g.tap(stuck.first);
    expect(res, isNot(2));
    expect(g.bumps, 1);
    g.undo();
    expect(g.serialize(), before);
  });

  test('kayıt geri yüklenir', () {
    final l = rules.build(planner.spec(77)).puzzle;
    final g = EscapeGame(l);
    g.tap(g.hint()!);
    final r = EscapeGame.restore(l, g.serialize());
    expect(r.serialize(), g.serialize());
  });
}
