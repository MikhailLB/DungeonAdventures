import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'game_assets.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  GamePainter({
    required this.engine,
    required this.assets,
  });

  final GameEngine engine;
  final GameAssets assets;

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawLanes(canvas, size);
    _drawCoins(canvas, size);
    _drawCarts(canvas, size);
    _drawChickenShadow(canvas);
    _drawChicken(canvas);

    if (engine.state == GameState.gameOver) {
      _drawDeathFX(canvas, size);
    }
  }

  void _drawSky(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF20263D), Color(0xFF0A0D15)],
        ).createShader(Offset.zero & size),
    );
  }

  void _drawLanes(Canvas canvas, Size size) {
    final minLane = (engine.cameraLane - 5).floor();
    final maxLane = (engine.cameraLane + size.height / GameEngine.laneHeight + 5).ceil();

    for (int laneIndex = minLane; laneIndex <= maxLane; laneIndex++) {
      final lane = engine.lanes[laneIndex];
      if (lane == null) {
        continue;
      }

      final laneY = engine.laneScreenY(laneIndex.toDouble());
      final laneRect = Rect.fromLTWH(
        0,
        laneY - GameEngine.laneHeight / 2,
        size.width,
        GameEngine.laneHeight,
      );

      if (laneIndex <= 0) {
        _drawTiledImage(canvas, assets.bgStart, laneRect);
      } else if (lane.isSafe) {
        canvas.drawRect(
          laneRect,
          Paint()..color = const Color(0xFF1A1D26).withValues(alpha: 0.88),
        );
        final safeRect = Rect.fromLTWH(
          laneRect.left,
          laneRect.top + GameEngine.laneHeight * 0.22,
          laneRect.width,
          GameEngine.laneHeight * 0.56,
        );
        final safeImage = lane.index.isEven ? assets.bgSafe : assets.bgSafeAlt;
        _drawTiledImage(canvas, safeImage, safeRect);
        _drawSafeIslandDetails(canvas, safeRect, lane);
        _drawDecorations(canvas, safeRect, lane);
      } else {
        final ui.Image image;
        if (lane.segmentLength >= 6) {
          image = assets.bgRailMix;
        } else if (lane.index % 3 == 0) {
          image = assets.bgRailIsland;
        } else if (lane.index % 2 == 0) {
          image = assets.bgRail;
        } else {
          image = assets.bgRailAlt;
        }
        _drawTiledImage(canvas, image, laneRect);
        canvas.drawRect(
          laneRect,
          Paint()..color = Colors.black.withValues(alpha: 0.08),
        );
        _drawRailDetails(canvas, laneRect, lane);
      }
      _drawLaneSeparator(canvas, laneRect, lane.isSafe);
    }
  }

  void _drawSafeIslandDetails(Canvas canvas, Rect safeRect, LaneData lane) {
    final borderColor =
        lane.index.isEven ? const Color(0xFF7AA760) : const Color(0xFF87B368);
    canvas.drawRRect(
      RRect.fromRectAndRadius(safeRect, const Radius.circular(6)),
      Paint()
        ..color = borderColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(safeRect.left, safeRect.top),
      Offset(safeRect.right, safeRect.top),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1.2,
    );
    canvas.drawLine(
      Offset(safeRect.left, safeRect.bottom),
      Offset(safeRect.right, safeRect.bottom),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..strokeWidth = 1.4,
    );

    final rockPaint = Paint()
      ..color = const Color(0xFF272E3A).withValues(alpha: 0.7);
    for (int i = 0; i < 4; i++) {
      final seed = ((lane.index * 37) + (i * 19)) % 100;
      final x = safeRect.left + safeRect.width * (0.14 + seed / 140);
      final y = safeRect.bottom - (5 + (i % 2) * 4).toDouble();
      final w = 8 + (seed % 4).toDouble();
      final h = 3 + (seed % 2).toDouble();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: w, height: h),
          const Radius.circular(3),
        ),
        rockPaint,
      );
    }
  }

  void _drawLaneSeparator(Canvas canvas, Rect laneRect, bool isSafe) {
    canvas.drawLine(
      Offset(laneRect.left, laneRect.top),
      Offset(laneRect.right, laneRect.top),
      Paint()
        ..color = isSafe
            ? const Color(0xFF9CCC65).withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.1)
        ..strokeWidth = 1,
    );
  }

  void _drawRailDetails(Canvas canvas, Rect rect, LaneData lane) {
    if (lane.isSegmentStart) {
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, 4),
        Paint()..color = const Color(0xFFFFCC80).withValues(alpha: 0.45),
      );
    }
    if (lane.isSegmentEnd) {
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.bottom - 4, rect.width, 4),
        Paint()..color = const Color(0xFFFFCC80).withValues(alpha: 0.45),
      );
    }

    final railPaint = Paint()
      ..color = const Color(0xFFCDD4DF).withValues(alpha: 0.62)
      ..strokeWidth = 1.5;
    final sleeperPaint =
        Paint()..color = const Color(0xFF2E323C).withValues(alpha: 0.75);
    final int tracks = lane.railTracks.clamp(2, 4);
    final trackSpread = tracks == 1 ? 0.0 : (tracks - 1) * 8.0;
    final startY = rect.center.dy - trackSpread / 2;

    for (int t = 0; t < tracks; t++) {
      final centerY = startY + t * 8.0;
      canvas.drawLine(
        Offset(rect.left, centerY - 3.8),
        Offset(rect.right, centerY - 3.8),
        railPaint,
      );
      canvas.drawLine(
        Offset(rect.left, centerY + 3.8),
        Offset(rect.right, centerY + 3.8),
        railPaint,
      );

      for (double x = 0; x < rect.width; x += 24) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(x, centerY),
            width: 12,
            height: 7.5,
          ),
          sleeperPaint,
        );
      }
    }

    final haze = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.04),
          Colors.black.withValues(alpha: 0.16),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, haze);
  }

  void _drawDecorations(Canvas canvas, Rect laneRect, LaneData lane) {
    for (final deco in lane.decorations) {
      final double size = deco.type == DecoType.tree
          ? 54 * deco.scale
          : 40 * deco.scale;

      final shadow = Rect.fromCenter(
        center: Offset(deco.x + 4, laneRect.center.dy + size * 0.35),
        width: size * 0.65,
        height: size * 0.22,
      );
      canvas.drawOval(shadow, Paint()..color = Colors.black.withValues(alpha: 0.28));

      final ui.Image image;
      if (deco.type == DecoType.tree) {
        image = assets.treeImage((lane.index + deco.x.toInt()) % 3);
      } else {
        image = assets.torchImage(deco.alternate);
      }

      _drawImage(
        canvas,
        image,
        deco.x - size / 2,
        laneRect.center.dy - size * 0.7,
        size,
        size,
      );
    }
  }

  void _drawCoins(Canvas canvas, Size size) {
    final minLane = (engine.cameraLane - 4).floor();
    final maxLane = (engine.cameraLane + size.height / GameEngine.laneHeight + 4).ceil();
    final time = engine.menuTime;

    for (int laneIndex = minLane; laneIndex <= maxLane; laneIndex++) {
      final lane = engine.lanes[laneIndex];
      if (lane == null) {
        continue;
      }
      final laneY = engine.laneScreenY(laneIndex.toDouble());

      for (final coin in lane.coins) {
        if (coin.collected) {
          continue;
        }

        final coinX = coin.column * engine.columnWidth + engine.columnWidth / 2;
        final bob = sin(time * 5 + laneIndex * 0.25 + coin.column) * 3.2;
        final center = Offset(coinX, laneY - 8 + bob);

        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(coinX, laneY + 13),
            width: 20,
            height: 7,
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.3),
        );

        canvas.drawCircle(center, 10, Paint()..color = const Color(0xFFF7C542));
        canvas.drawCircle(center, 8, Paint()..color = const Color(0xFFE5AA23));
        canvas.drawCircle(
          Offset(center.dx - 2.8, center.dy - 2.8),
          2.3,
          Paint()..color = Colors.white.withValues(alpha: 0.75),
        );
      }
    }
  }

  void _drawCarts(Canvas canvas, Size size) {
    final minLane = (engine.cameraLane - 4).floor();
    final maxLane = (engine.cameraLane + size.height / GameEngine.laneHeight + 4).ceil();

    for (int laneIndex = minLane; laneIndex <= maxLane; laneIndex++) {
      final lane = engine.lanes[laneIndex];
      if (lane == null || lane.isSafe) {
        continue;
      }
      final laneY = engine.laneScreenY(laneIndex.toDouble());

      for (final cart in lane.carts) {
        final image = assets.cartImage(cart.type);
        final cartHeight = GameEngine.laneHeight * 0.66 * cart.sizeFactor;
        final cartWidth = cartHeight * image.width / image.height;

        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cart.x + 5, laneY + cartHeight * 0.24),
            width: cartWidth * 0.8,
            height: cartHeight * 0.24,
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.38),
        );

        canvas.save();
        canvas.translate(cart.x, laneY);
        if (!cart.movingRight) {
          canvas.scale(-1, 1);
        }
        _drawImage(
          canvas,
          image,
          -cartWidth / 2,
          -cartHeight / 2,
          cartWidth,
          cartHeight,
        );
        canvas.restore();
      }
    }
  }

  void _drawChickenShadow(Canvas canvas) {
    if (engine.state == GameState.menu) {
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          engine.chickenScreenX + 3,
          engine.laneScreenY(engine.chickenLane.toDouble()) + engine.columnWidth * 0.1,
        ),
        width: engine.columnWidth * 0.6,
        height: engine.columnWidth * 0.22,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.42),
    );
  }

  void _drawChicken(Canvas canvas) {
    if (engine.state == GameState.menu) {
      return;
    }

    final bool isDead = engine.state == GameState.gameOver;
    final ui.Image image = isDead ? assets.turkeyDead : assets.turkeyAlive;
    final double size = engine.columnWidth * 0.82;

    canvas.save();
    canvas.translate(engine.chickenScreenX, engine.chickenScreenY);
    if (engine.facingDir < 0) {
      canvas.scale(-1, 1);
    }
    if (isDead) {
      final t = engine.deathTimer.clamp(0.0, 1.0);
      canvas.rotate(t * 0.24);
      canvas.scale(1.0 + t * 0.06, 1.0 - t * 0.2);
    } else if (engine.hopProgress < 1.0) {
      final pulse = sin(engine.hopProgress * pi) * 0.11;
      canvas.scale(1.0 - pulse, 1.0 + pulse);
    } else if (engine.idleTime > 0.4) {
      final breathe = 1 + sin((engine.idleTime - 0.4) * 3.5) * 0.03;
      canvas.scale(breathe, breathe);
    }
    _drawImage(canvas, image, -size / 2, -size / 2, size, size);
    canvas.restore();
  }

  void _drawDeathFX(Canvas canvas, Size size) {
    final flashAlpha = (1.0 - engine.deathTimer * 2.2).clamp(0.0, 0.35);
    if (flashAlpha <= 0) {
      return;
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFF3D00).withValues(alpha: flashAlpha),
    );
  }

  void _drawTiledImage(Canvas canvas, ui.Image image, Rect dstRect) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final tileWidth = dstRect.height * src.width / src.height;

    for (double x = dstRect.left; x < dstRect.right; x += tileWidth) {
      final drawWidth = min(tileWidth, dstRect.right - x);
      final sourceWidth = src.width * (drawWidth / tileWidth);

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, sourceWidth, src.height),
        Rect.fromLTWH(x, dstRect.top, drawWidth, dstRect.height),
        Paint()..filterQuality = FilterQuality.high,
      );
    }
  }

  void _drawImage(Canvas canvas, ui.Image image, double x, double y, double w, double h) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(x, y, w, h),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
