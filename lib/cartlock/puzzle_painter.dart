import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'game_assets.dart';
import 'models.dart';
import 'puzzle_engine.dart';

Color cartColor(CartColor c) {
  switch (c) {
    case CartColor.amber:
      return const Color(0xFFFF7043);
    case CartColor.azure:
      return const Color(0xFF29B6F6);
    case CartColor.gold:
      return const Color(0xFFFFCA28);
  }
}

/// Geometry helper shared between the painter and the play screen so taps can
/// be mapped back to grid directions if needed.
class BoardLayout {
  BoardLayout({
    required this.cell,
    required this.originX,
    required this.originY,
  });

  final double cell;
  final double originX;
  final double originY;

  Offset center(num row, num col) => Offset(
        originX + (col + 0.5) * cell,
        originY + (row + 0.5) * cell,
      );

  static BoardLayout fit(LevelDef level, Size size, {double padding = 16}) {
    final availW = size.width - padding * 2;
    final availH = size.height - padding * 2;
    final cell = min(availW / level.cols, availH / level.rows);
    final boardW = cell * level.cols;
    final boardH = cell * level.rows;
    return BoardLayout(
      cell: cell,
      originX: (size.width - boardW) / 2,
      originY: (size.height - boardH) / 2,
    );
  }
}

class PuzzlePainter extends CustomPainter {
  PuzzlePainter({
    required this.engine,
    required this.assets,
    required this.skinId,
    required this.stepT,
    required this.time,
  });

  final PuzzleEngine engine;
  final GameAssets assets;
  final String skinId;

  /// Animation progress of the current step, 0..1.
  final double stepT;

  /// Free-running seconds, used for ambient pulsing/flicker.
  final double time;

  LevelDef get level => engine.level;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = BoardLayout.fit(level, size);
    _drawBoardBackdrop(canvas, layout);
    _drawTiles(canvas, layout);
    _drawVaults(canvas, layout);
    _drawTorches(canvas, layout);
    _drawCarts(canvas, layout);
    _drawMiner(canvas, layout);
  }

  void _drawBoardBackdrop(Canvas canvas, BoardLayout l) {
    final rect = Rect.fromLTWH(
      l.originX - 10,
      l.originY - 10,
      l.cell * level.cols + 20,
      l.cell * level.rows + 20,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    canvas.drawRRect(
      rrect.shift(const Offset(0, 8)),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xFF1B130C),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF53402A).withValues(alpha: 0.85),
    );
  }

  void _drawTiles(Canvas canvas, BoardLayout l) {
    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final tile = level.tiles[r][c];
        final rect = Rect.fromLTWH(
          l.originX + c * l.cell,
          l.originY + r * l.cell,
          l.cell,
          l.cell,
        );
        switch (tile) {
          case TileType.wall:
            _drawWall(canvas, rect);
            break;
          case TileType.rail:
            _drawCover(canvas, assets.tileRail, rect, dim: 0.0);
            canvas.drawRect(
              rect,
              Paint()..color = const Color(0xFF000000).withValues(alpha: 0.06),
            );
            break;
          case TileType.floor:
          case TileType.torch:
            _drawCover(canvas, assets.tileFloor, rect, dim: 0.12);
            break;
        }
        // subtle cell grid line
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6
            ..color = Colors.black.withValues(alpha: 0.18),
        );
      }
    }
  }

  void _drawWall(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = const Color(0xFF120C08));
    final inner = rect.deflate(2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(4)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF40301F), Color(0xFF211711)],
        ).createShader(inner),
    );
    canvas.drawLine(
      inner.topLeft + const Offset(2, 2),
      inner.topRight + const Offset(-2, 2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..strokeWidth = 1.5,
    );
  }

  void _drawCover(Canvas canvas, ui.Image image, Rect rect, {double dim = 0}) {
    final src = _coverSrc(image, rect);
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawImageRect(
      image,
      src,
      rect,
      Paint()..filterQuality = FilterQuality.medium,
    );
    if (dim > 0) {
      canvas.drawRect(rect, Paint()..color = Colors.black.withValues(alpha: dim));
    }
    canvas.restore();
  }

  Rect _coverSrc(ui.Image image, Rect dst) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    final scale = max(dst.width / iw, dst.height / ih);
    final w = dst.width / scale;
    final h = dst.height / scale;
    final left = (iw - w) / 2;
    final top = (ih - h) / 2;
    return Rect.fromLTWH(left, top, w, h);
  }

  void _drawVaults(Canvas canvas, BoardLayout l) {
    final pulse = (sin(time * 2.4) + 1) / 2;
    for (final vault in level.vaults) {
      final color = cartColor(vault.color);
      final center = l.center(vault.pos.row, vault.pos.col);
      final radius = l.cell * 0.42;

      canvas.drawCircle(
        center,
        radius * (1.0 + pulse * 0.06),
        Paint()
          ..color = color.withValues(alpha: 0.16 + pulse * 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      final marker = Rect.fromCenter(
        center: center,
        width: l.cell * 0.66,
        height: l.cell * 0.66,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(marker, Radius.circular(l.cell * 0.12)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = color.withValues(alpha: 0.85),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(marker, Radius.circular(l.cell * 0.12)),
        Paint()..color = color.withValues(alpha: 0.10),
      );
    }
  }

  void _drawTorches(Canvas canvas, BoardLayout l) {
    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        if (level.tiles[r][c] != TileType.torch) {
          continue;
        }
        final center = l.center(r, c);
        final flicker = 0.7 + 0.3 * sin(time * 9 + r * 1.7 + c);
        canvas.drawCircle(
          center.translate(0, -l.cell * 0.18),
          l.cell * 0.34 * flicker,
          Paint()
            ..color = const Color(0xFFFFB74D).withValues(alpha: 0.30 * flicker)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
        final size = l.cell * 0.9;
        _drawImageCentered(
          canvas,
          assets.torch,
          center.translate(0, -l.cell * 0.04),
          size,
        );
      }
    }
  }

  void _drawCarts(Canvas canvas, BoardLayout l) {
    for (final cart in engine.carts) {
      final from = l.center(cart.prevPos.row, cart.prevPos.col);
      final to = l.center(cart.pos.row, cart.pos.col);
      final pos = Offset.lerp(from, to, stepT)!;
      final image = assets.cartImage(cart.color);
      final color = cartColor(cart.color);

      // shadow
      canvas.drawOval(
        Rect.fromCenter(
          center: pos.translate(0, l.cell * 0.28),
          width: l.cell * 0.66,
          height: l.cell * 0.2,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.4),
      );

      final settled = cart.onTarget(level);
      if (settled) {
        canvas.drawCircle(
          pos,
          l.cell * 0.5,
          Paint()
            ..color = color.withValues(alpha: 0.30)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      final size = l.cell * 0.82;
      _drawImageCentered(canvas, image, pos, size);
    }
  }

  void _drawMiner(Canvas canvas, BoardLayout l) {
    final from = l.center(engine.minerPrevPos.row, engine.minerPrevPos.col);
    final to = l.center(engine.minerPos.row, engine.minerPos.col);
    final pos = Offset.lerp(from, to, stepT)!;
    final hop = sin(stepT * pi) * l.cell * 0.12;
    final image = assets.minerAlive(skinId);

    // shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: pos.translate(0, l.cell * 0.3),
        width: l.cell * 0.5,
        height: l.cell * 0.16,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.42),
    );

    canvas.save();
    canvas.translate(pos.dx, pos.dy - hop);
    if (engine.facing < 0) {
      canvas.scale(-1, 1);
    }
    final size = l.cell * 0.72;
    _drawImageCentered(canvas, image, Offset.zero, size);
    canvas.restore();
  }

  void _drawImageCentered(
      Canvas canvas, ui.Image image, Offset center, double targetH) {
    final aspect = image.width / image.height;
    final h = targetH;
    final w = h * aspect;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: center, width: w, height: h),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant PuzzlePainter oldDelegate) => true;
}
