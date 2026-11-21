import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/core/strings.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';

import 'escape_engine.dart';
import 'escape_rules.dart';

class EscapeView extends StatefulWidget {
  final PlayContext ctx;
  const EscapeView({super.key, required this.ctx});

  @override
  State<EscapeView> createState() => _EscapeViewState();
}

class _EscapeViewState extends State<EscapeView> {
  late EscapeLevel level;
  late EscapeGame game;
  int? _hint;
  int? _shake;
  int _seconds = 0, _hints = 0, _undos = 0;
  Timer? _timer;
  bool _ended = false;
  double _cell = 40;

  PlayContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    level = EscapeRules().finalize(ctx.generated as GeneratedLevel<EscapeLevel>);
    final snap = ctx.resume['snap'];
    game = snap is String ? EscapeGame.restore(level, snap) : EscapeGame(level);
    _seconds = (ctx.resume['secs'] as num?)?.toInt() ?? 0;
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_ended && mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _persist() => ctx.saveResume({'snap': game.serialize(), 'secs': _seconds, 'hints': _hints});

  void _tap(TapUpDetails d) {
    if (_ended) return;
    final x = (d.localPosition.dx / _cell).floor(), y = (d.localPosition.dy / _cell).floor();
    final i = game.blockAt(x, y);
    if (i < 0) return;
    final res = game.tap(i);
    if (res == 2) {
      ctx.sfx(game.won ? Sfx.win : Sfx.clear);
    } else {
      ctx.sfx(Sfx.error);
      _shake = res == 1 ? null : i;
      Timer(const Duration(milliseconds: 260), () {
        if (mounted) setState(() => _shake = null);
      });
    }
    setState(() => _hint = null);
    _persist();
    if (game.won || (level.moveLimit > 0 && game.moves >= level.moveLimit)) _end();
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();
    if (!game.won) ctx.sfx(Sfx.lose);
    ctx.finish(RoundResult(
      won: game.won,
      score: (game.escaped * 20 - game.bumps * 5).clamp(0, 1 << 20),
      stars: EscapeRules.stars(game),
      seconds: _seconds,
      moves: game.moves,
      hintsUsed: _hints,
      undosUsed: _undos,
      gameStats: {'blocks_escaped': game.escaped, 'boards_cleared': game.won ? 1 : 0},
    ));
  }

  Future<void> _useHint() async {
    if (!await ctx.requestHint()) return;
    _hints++;
    setState(() => _hint = game.hint());
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      _cell = math.max(18.0, math.min((cons.maxWidth - 24) / level.w, cons.maxHeight * 0.7 / level.h));
      final left = level.moveLimit > 0 ? level.moveLimit - game.moves : null;
      return Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Expanded(
              child: Text(Strings.tx(ctx.lang, 'Kalan blok: {0}', 'Blocks left: {0}', [game.blocks.length]),
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            if (left != null) ...[const Icon(Icons.touch_app_outlined, size: 18), Text(' $left  ')],
            const Icon(Icons.timer_outlined, size: 18),
            Text(' ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}'),
          ]),
        ),
        Expanded(
          child: Center(
            child: GestureDetector(
              onTapUp: _tap,
              child: Semantics(
                label: 'board',
                child: SizedBox(
                  width: _cell * level.w,
                  height: _cell * level.h,
                  child: CustomPaint(painter: _Painter(this)),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            IconButton.filledTonal(onPressed: _ended ? null : _useHint, icon: const Icon(Icons.lightbulb), tooltip: ctx.t('hint')),
            IconButton.filledTonal(
                onPressed: game.canUndo && !_ended
                    ? () {
                        setState(() {
                          game.undo();
                          _undos++;
                        });
                        _persist();
                      }
                    : null,
                icon: const Icon(Icons.undo),
                tooltip: ctx.t('undo')),
          ]),
        ),
      ]);
    });
  }
}

class _Painter extends CustomPainter {
  final _EscapeViewState v;
  _Painter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final c = v._cell;
    final g = v.game;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
        Paint()..color = Colors.black.withValues(alpha: 0.10));
    for (var y = 0; y < g.h; y++) {
      for (var x = 0; x < g.w; x++) {
        canvas.drawCircle(Offset((x + 0.5) * c, (y + 0.5) * c), c * 0.05, Paint()..color = Colors.white.withValues(alpha: 0.15));
      }
    }
    for (var i = 0; i < g.blocks.length; i++) {
      final b = g.blocks[i];
      final bw = b.horizontal ? b.len : 1, bh = b.horizontal ? 1 : b.len;
      var r = Rect.fromLTWH(b.x * c, b.y * c, bw * c, bh * c).deflate(c * 0.07);
      if (v._shake == i) r = r.shift(Offset(kDirs[b.dir][0] * c * 0.12, kDirs[b.dir][1] * c * 0.12));
      final col = v.ctx.pieceColors[b.color % v.ctx.pieceColors.length];
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(c * 0.24)), Paint()..color = col);
      if (v._hint == i) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(r.inflate(2), Radius.circular(c * 0.26)),
            Paint()
              ..color = Colors.amber
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4);
      }
      // Ok
      final ctr = r.center;
      final a = [-math.pi / 2, 0.0, math.pi / 2, math.pi][b.dir];
      final s = c * 0.22;
      final path = Path()
        ..moveTo(ctr.dx + math.cos(a) * s, ctr.dy + math.sin(a) * s)
        ..lineTo(ctr.dx + math.cos(a + 2.5) * s, ctr.dy + math.sin(a + 2.5) * s)
        ..lineTo(ctr.dx + math.cos(a - 2.5) * s, ctr.dy + math.sin(a - 2.5) * s)
        ..close();
      canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.9));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
