import 'dart:convert';

import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

/// Blok Kaçışı: her bloğun bir oku var. Dokununca blok o yöne kayar; yol
/// açıksa tahtadan çıkar, değilse önündeki bloğa kadar gider. Tahtayı boşalt.
///
/// Bölümler çözülebilir kurulur: her yeni blok, eklendiği anda çıkış yolu
/// açık olacak biçimde yerleştirilir; ters sırayla çıkarmak her zaman çalışır.

const List<List<int>> kDirs = [[0, -1], [1, 0], [0, 1], [-1, 0]]; // yukarı, sağ, aşağı, sol

class EBlock {
  int x, y;
  final int len;
  final bool horizontal;
  final int dir;
  final int color;
  EBlock(this.x, this.y, this.len, this.horizontal, this.dir, this.color);
  EBlock copy() => EBlock(x, y, len, horizontal, dir, color);
  List<int> cells(int w) => [for (var k = 0; k < len; k++) (y + (horizontal ? 0 : k)) * w + x + (horizontal ? k : 0)];
  List<int> toJson() => [x, y, len, horizontal ? 1 : 0, dir, color];
  static EBlock fromJson(List<dynamic> j) => EBlock((j[0] as num).toInt(), (j[1] as num).toInt(), (j[2] as num).toInt(),
      j[3] == 1, (j[4] as num).toInt(), (j[5] as num).toInt());
}

class EscapeLevel {
  final int w, h;
  final List<EBlock> blocks;
  final int seed;
  final int difficulty;
  final int moveLimit; // 0 = sınırsız
  const EscapeLevel({required this.w, required this.h, required this.blocks, required this.seed, required this.difficulty, this.moveLimit = 0});
}

EscapeLevel generateEscapeLevel(LevelSpec spec) {
  final r = SeededRandom(mixSeed([spec.seed, 5150]));
  final d = spec.difficulty.clamp(1, 10);
  final w = (4 + d ~/ 2).clamp(4, 9), h = (5 + (d + 1) ~/ 2).clamp(5, 10);
  final want = (w * h * (0.42 + d * 0.025)).round();
  final g = EscapeGame._raw(w, h, []);
  var cells = 0;
  for (var tries = 0; tries < 4000 && cells < want; tries++) {
    final len = 1 + r.nextInt(d >= 5 ? 3 : 2);
    final horiz = r.chance(0.5);
    final x = r.nextInt(horiz ? w - len + 1 : w), y = r.nextInt(horiz ? h : h - len + 1);
    // Ok blok ekseni boyunca (uzun bloklar) ya da serbest (tek kare).
    final dir = len == 1 ? r.nextInt(4) : (horiz ? (r.chance(0.5) ? 1 : 3) : (r.chance(0.5) ? 0 : 2));
    final b = EBlock(x, y, len, horiz, dir, r.nextInt(8));
    if (!g.free(b)) continue;
    if (!g.pathClear(b)) continue;
    g.blocks.add(b);
    cells += len;
  }
  return EscapeLevel(w: w, h: h, blocks: g.blocks, seed: spec.seed, difficulty: d);
}

class EscapeGame {
  final int w, h;
  List<EBlock> blocks;
  int moves = 0, bumps = 0, escaped = 0;
  final List<String> _history = [];

  EscapeGame(EscapeLevel l)
      : w = l.w,
        h = l.h,
        blocks = [for (final b in l.blocks) b.copy()];

  EscapeGame._raw(this.w, this.h, this.blocks);

  bool get won => blocks.isEmpty;

  Set<int> _occupied({EBlock? except}) => {
        for (final b in blocks)
          if (!identical(b, except)) ...b.cells(w)
      };

  bool free(EBlock b) {
    final occ = _occupied();
    return b.cells(w).every((c) => !occ.contains(c));
  }

  /// Blok okunun yönünde tahtadan çıkabilir mi?
  bool pathClear(EBlock b) => _travel(b).$2;

  /// (gidilebilecek adım, çıkıyor mu)
  (int, bool) _travel(EBlock b) {
    final occ = _occupied(except: b);
    final dx = kDirs[b.dir][0], dy = kDirs[b.dir][1];
    var steps = 0;
    while (true) {
      final nx = b.x + dx * (steps + 1), ny = b.y + dy * (steps + 1);
      final moved = EBlock(nx, ny, b.len, b.horizontal, b.dir, b.color);
      var off = false;
      for (var k = 0; k < b.len; k++) {
        final cx = moved.x + (b.horizontal ? k : 0), cy = moved.y + (b.horizontal ? 0 : k);
        if (cx < 0 || cy < 0 || cx >= w || cy >= h) {
          off = true;
          continue;
        }
        if (occ.contains(cy * w + cx)) return (steps, false);
      }
      if (off) return (steps, true);
      steps++;
    }
  }

  int blockAt(int x, int y) {
    final c = y * w + x;
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].cells(w).contains(c)) return i;
    }
    return -1;
  }

  /// Dokunma. Sonuç: 2 çıktı, 1 kaydı ve çarptı, 0 hiç kıpırdamadı.
  int tap(int i) {
    if (i < 0 || i >= blocks.length) return -1;
    final b = blocks[i];
    _history.add(serialize());
    final (steps, out) = _travel(b);
    moves++;
    if (out) {
      blocks.removeAt(i);
      escaped++;
      return 2;
    }
    bumps++;
    b.x += kDirs[b.dir][0] * steps;
    b.y += kDirs[b.dir][1] * steps;
    return steps > 0 ? 1 : 0;
  }

  bool get canUndo => _history.isNotEmpty;

  void undo() {
    if (_history.isEmpty) return;
    final j = jsonDecode(_history.removeLast()) as Map<String, dynamic>;
    _load(j);
  }

  /// İpucu: çıkabilen ilk blok.
  int? hint() {
    for (var i = 0; i < blocks.length; i++) {
      if (pathClear(blocks[i])) return i;
    }
    return null;
  }

  /// Açgözlü çözüm: hep çıkabilen bir bloğu çıkar. Bu oyunda bu kesindir:
  /// çıkarmak yalnızca yol açar.
  int solveCount() {
    final g = EscapeGame._raw(w, h, [for (final b in blocks) b.copy()]);
    var n = 0;
    while (g.blocks.isNotEmpty) {
      final i = g.hint();
      if (i == null) return -1;
      g.blocks.removeAt(i);
      n++;
    }
    return n;
  }

  String serialize() => jsonEncode({
        'b': [for (final b in blocks) b.toJson()],
        's': [moves, bumps, escaped],
      });

  void _load(Map<String, dynamic> j) {
    blocks = [for (final e in j['b'] as List) EBlock.fromJson(e as List)];
    final s = [for (final v in j['s'] as List) (v as num).toInt()];
    moves = s[0];
    bumps = s[1];
    escaped = s[2];
  }

  static EscapeGame restore(EscapeLevel l, String snap) {
    final g = EscapeGame(l);
    g._load(jsonDecode(snap) as Map<String, dynamic>);
    return g;
  }
}
