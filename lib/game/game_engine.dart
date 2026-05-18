import 'dart:math';
import 'game_assets.dart';

enum GameState { menu, playing, paused, gameOver }

class Minecart {
  Minecart({
    required this.type,
    required this.x,
    required this.speed,
    required this.movingRight,
    required this.sizeFactor,
  });

  final CartType type;
  double x;
  final double speed;
  final bool movingRight;
  final double sizeFactor;

  void update(double dt) {
    x += (movingRight ? speed : -speed) * dt;
  }
}

class Coin {
  Coin(this.column);

  final int column;
  bool collected = false;
}

class LaneDeco {
  LaneDeco({
    required this.type,
    required this.x,
    required this.scale,
    this.alternate = false,
  });

  final DecoType type;
  final double x;
  final double scale;
  final bool alternate;
}

class LaneData {
  LaneData({
    required this.index,
    required this.isSafe,
    this.isSegmentStart = false,
    this.isSegmentEnd = false,
    this.movingRight = true,
    this.speed = 100,
    this.spawnInterval = 1.2,
    this.spawnTimer = 0,
    this.segmentLength = 1,
    this.railTracks = 2,
  });

  final int index;
  final bool isSafe;
  final bool isSegmentStart;
  final bool isSegmentEnd;
  final bool movingRight;
  final double speed;
  final double spawnInterval;
  double spawnTimer;
  final int segmentLength;
  final int railTracks;
  final List<Minecart> carts = <Minecart>[];
  final List<Coin> coins = <Coin>[];
  final List<LaneDeco> decorations = <LaneDeco>[];
}

class GameEngine {
  static const double laneHeight = 82;
  static const int numColumns = 5;
  static const int _lanesBelow = 4;
  static const double metersPerLane = 2.5;
  static const double _hopSpeed = 7.2;

  final Random _rng = Random();
  final Map<int, LaneData> lanes = <int, LaneData>{};

  double screenWidth = 0;
  double screenHeight = 0;
  double get columnWidth => screenWidth / numColumns;

  GameState state = GameState.menu;

  int score = 0;
  int highScore = 0;
  int collectedCoins = 0;
  int bestDistance = 0;
  double multiplier = 1.0;
  int stepsTaken = 0;

  int chickenLane = 0;
  int chickenCol = 2;
  int _prevLane = 0;
  int _prevCol = 2;
  int facingDir = 0; // -1 left, 0 forward, 1 right
  double hopProgress = 1.0;
  double idleTime = 0;

  double cameraLane = 0;
  double deathTimer = 0;
  double shakeIntensity = 0;
  double shakeX = 0;
  double shakeY = 0;
  double menuTime = 0;

  int _maxGeneratedLane = -999;
  int _dangerLanesRemaining = 0;
  int _safeLanesRemaining = 0;
  int _currentDangerLength = 0;

  int get distance => (chickenLane * metersPerLane).round();
  int get coinReward => (collectedCoins * multiplier).round();

  void setSize(double width, double height) {
    if (width == screenWidth && height == screenHeight) {
      return;
    }
    screenWidth = width;
    screenHeight = height;
  }

  void startGame() {
    state = GameState.playing;
    score = 0;
    collectedCoins = 0;
    multiplier = 1.0;
    stepsTaken = 0;
    chickenLane = 0;
    chickenCol = 2;
    _prevLane = 0;
    _prevCol = 2;
    facingDir = 0;
    hopProgress = 1.0;
    idleTime = 0;
    cameraLane = 0;
    deathTimer = 0;
    shakeIntensity = 0;
    shakeX = 0;
    shakeY = 0;
    lanes.clear();
    _maxGeneratedLane = -999;
    _dangerLanesRemaining = 0;
    _safeLanesRemaining = 0;
    _currentDangerLength = 0;

    _generateLanesBelowStart();
    _generateUpTo(38);
  }

  void returnToMenu() {
    state = GameState.menu;
    lanes.clear();
    _maxGeneratedLane = -999;
    _dangerLanesRemaining = 0;
    _safeLanesRemaining = 0;
    _currentDangerLength = 0;
    chickenLane = 0;
    chickenCol = 2;
    _prevLane = 0;
    _prevCol = 2;
    hopProgress = 1.0;
    idleTime = 0;
    cameraLane = 0;
    deathTimer = 0;
    shakeIntensity = 0;
    shakeX = 0;
    shakeY = 0;
  }

  void togglePause() {
    if (state == GameState.playing) {
      state = GameState.paused;
    } else if (state == GameState.paused) {
      state = GameState.playing;
    }
  }

  void update(double dt) {
    menuTime += dt;

    if (state == GameState.gameOver) {
      deathTimer += dt;
      shakeIntensity *= 0.9;
      shakeX = (_rng.nextDouble() * 2 - 1) * shakeIntensity;
      shakeY = (_rng.nextDouble() * 2 - 1) * shakeIntensity;
      _updateCarts(dt * 0.2);
      return;
    }
    if (state != GameState.playing) {
      return;
    }

    if (chickenLane + 20 > _maxGeneratedLane) {
      _generateUpTo(_maxGeneratedLane + 28);
    }

    if (hopProgress >= 1.0) {
      idleTime += dt;
    }

    if (hopProgress < 1.0) {
      hopProgress = (hopProgress + _hopSpeed * dt).clamp(0.0, 1.0);
      if (hopProgress >= 1.0) {
        _prevLane = chickenLane;
        _prevCol = chickenCol;
        idleTime = 0;
        _collectCoinsOnCurrentTile();
        if (_checkCollision()) {
          _die();
          return;
        }
      }
    }

    _updateCarts(dt);
    _spawnCarts(dt);

    cameraLane += (chickenLane - cameraLane) * 5.5 * dt;
    if (_checkCollision()) {
      _die();
    }
  }

  void moveForward() {
    if (state != GameState.playing || hopProgress < 1.0) {
      return;
    }
    _prevLane = chickenLane;
    _prevCol = chickenCol;
    chickenLane += 1;
    facingDir = 0;
    hopProgress = 0;
    stepsTaken += 1;
    multiplier = (1.0 + chickenLane * 0.035).clamp(1.0, 7.5);
    score += (10 * multiplier).round();
    idleTime = 0;
  }

  void moveBackward() {
    if (state != GameState.playing || hopProgress < 1.0 || chickenLane <= 0) {
      return;
    }
    _prevLane = chickenLane;
    _prevCol = chickenCol;
    chickenLane -= 1;
    facingDir = 0;
    hopProgress = 0;
    idleTime = 0;
  }

  void moveLeft() {
    if (state != GameState.playing || hopProgress < 1.0 || chickenCol <= 0) {
      return;
    }
    _prevLane = chickenLane;
    _prevCol = chickenCol;
    chickenCol -= 1;
    facingDir = -1;
    hopProgress = 0;
    idleTime = 0;
  }

  void moveRight() {
    if (state != GameState.playing ||
        hopProgress < 1.0 ||
        chickenCol >= numColumns - 1) {
      return;
    }
    _prevLane = chickenLane;
    _prevCol = chickenCol;
    chickenCol += 1;
    facingDir = 1;
    hopProgress = 0;
    idleTime = 0;
  }

  double laneScreenY(double lane) {
    final anchor = screenHeight * 0.86;
    return anchor - (lane - cameraLane) * laneHeight + shakeY;
  }

  double get chickenScreenX {
    final targetX = chickenCol * columnWidth + columnWidth / 2;
    final prevX = _prevCol * columnWidth + columnWidth / 2;
    return prevX + (targetX - prevX) * hopProgress + shakeX;
  }

  double get chickenScreenY {
    final targetLane = chickenLane.toDouble();
    final prevLane = _prevLane.toDouble();
    final activeLane = prevLane + (targetLane - prevLane) * hopProgress;
    final baseY = laneScreenY(activeLane);
    final jumpArc = sin(hopProgress * pi) * laneHeight * 0.32;
    return baseY - jumpArc;
  }

  void _generateLanesBelowStart() {
    for (int i = -_lanesBelow; i < 0; i++) {
      lanes[i] = _safeLane(i);
    }
  }

  void _generateUpTo(int targetLane) {
    final int start = _maxGeneratedLane == -999 ? 0 : _maxGeneratedLane + 1;
    for (int laneIndex = start; laneIndex <= targetLane; laneIndex++) {
      lanes[laneIndex] = _createLane(laneIndex);
    }
    _maxGeneratedLane = targetLane;
  }

  LaneData _createLane(int index) {
    if (index <= 1) {
      return _safeLane(index);
    }

    if (_dangerLanesRemaining <= 0 && _safeLanesRemaining <= 0) {
      _currentDangerLength = _dangerStretchLength(index);
      _dangerLanesRemaining = _currentDangerLength;
    }

    if (_dangerLanesRemaining > 0) {
      final difficulty = (index / 100).clamp(0.0, 1.0);
      final isStart = _dangerLanesRemaining == _currentDangerLength;
      final isEnd = _dangerLanesRemaining == 1;
      final movingRight = _rng.nextBool();
      final laneSpeed =
          95 + difficulty * 205 + (_rng.nextDouble() * 28 - 14);
      final spawnInterval = (1.95 - difficulty * 1.05 + _rng.nextDouble() * 0.45)
          .clamp(0.62, 2.1);

      final lane = LaneData(
        index: index,
        isSafe: false,
        isSegmentStart: isStart,
        isSegmentEnd: isEnd,
        movingRight: movingRight,
        speed: laneSpeed,
        spawnInterval: spawnInterval,
        spawnTimer: _rng.nextDouble() * spawnInterval * 0.65,
        segmentLength: _currentDangerLength,
        railTracks: _railTracksForLane(index, _currentDangerLength),
      );

      _dangerLanesRemaining--;
      if (isEnd) {
        _safeLanesRemaining = _safeGapFor(index);
      }

      _seedLaneCarts(lane);
      if (_rng.nextDouble() < 0.46) {
        _addLaneCoins(lane, minCoins: 1, maxCoins: 2);
      }
      return lane;
    }

    _safeLanesRemaining = max(0, _safeLanesRemaining - 1);
    return _safeLane(index);
  }

  LaneData _safeLane(int index) {
    final lane = LaneData(index: index, isSafe: true);
    if (screenWidth <= 0) {
      return lane;
    }

    final slots = 1 + _rng.nextInt(index > 20 ? 2 : 3);
    final usedColumns = <int>{};
    for (int i = 0; i < slots; i++) {
      final col = _rng.nextInt(numColumns);
      if (!usedColumns.add(col)) {
        continue;
      }
      final x = col * columnWidth + columnWidth / 2;
      lane.decorations.add(
        LaneDeco(
          type: _rng.nextBool() ? DecoType.tree : DecoType.torch,
          x: x,
          scale: 0.78 + _rng.nextDouble() * 0.34,
          alternate: _rng.nextBool(),
        ),
      );
    }

    if (_rng.nextDouble() < 0.2) {
      _addLaneCoins(lane, minCoins: 1, maxCoins: 2);
    }
    return lane;
  }

  int _dangerStretchLength(int laneIndex) {
    if (laneIndex < 8) {
      return 2 + _rng.nextInt(2); // 2..3
    }
    if (laneIndex < 22) {
      return 3 + _rng.nextInt(2); // 3..4
    }
    if (laneIndex < 50) {
      return 4 + _rng.nextInt(3); // 4..6
    }
    return 5 + _rng.nextInt(4); // 5..8
  }

  int _safeGapFor(int laneIndex) {
    if (laneIndex < 12) {
      return 2;
    }
    if (laneIndex < 36) {
      return _rng.nextDouble() < 0.35 ? 2 : 1;
    }
    return 1;
  }

  int _maxCartsForLane(int laneIndex) {
    if (laneIndex < 12) {
      return 2;
    }
    if (laneIndex < 35) {
      return 3;
    }
    return 4;
  }

  int _railTracksForLane(int laneIndex, int segmentLength) {
    if (laneIndex < 14) {
      return 2;
    }
    if (laneIndex < 32) {
      return 2 + _rng.nextInt(2); // 2..3
    }
    final bias = segmentLength >= 6 ? 1 : 0;
    return (2 + bias + _rng.nextInt(2)).clamp(2, 4); // 2..4
  }

  void _seedLaneCarts(LaneData lane) {
    if (screenWidth <= 0) {
      return;
    }

    final maxCarts = _maxCartsForLane(lane.index);
    final cartsCount = max(1, maxCarts - 1 + _rng.nextInt(2));
    final leftBound = 44.0;
    final rightBound = max(leftBound + 1, screenWidth - 44);
    final span = max(80.0, rightBound - leftBound);
    final minGap = max(108.0, span / (maxCarts + 0.6));
    final baseOffset = 18 + _rng.nextDouble() * 34;

    double? lastX;
    for (int i = 0; i < cartsCount; i++) {
      double x = lane.movingRight
          ? leftBound + baseOffset + i * minGap
          : rightBound - baseOffset - i * minGap;
      x += (_rng.nextDouble() - 0.5) * min(minGap * 0.2, 16);
      x = x.clamp(leftBound, rightBound);

      if (lastX != null) {
        if (lane.movingRight) {
          final minAllowed = lastX + minGap * 0.82;
          if (x < minAllowed) {
            x = minAllowed;
          }
        } else {
          final maxAllowed = lastX - minGap * 0.82;
          if (x > maxAllowed) {
            x = maxAllowed;
          }
        }
        x = x.clamp(leftBound, rightBound);
      }
      lastX = x;

      lane.carts.add(
        Minecart(
          type: CartType.values[_rng.nextInt(CartType.values.length)],
          x: x,
          speed: lane.speed * (0.95 + _rng.nextDouble() * 0.08),
          movingRight: lane.movingRight,
          sizeFactor: 0.74 + _rng.nextDouble() * 0.14,
        ),
      );
    }
  }

  void _addLaneCoins(LaneData lane, {required int minCoins, required int maxCoins}) {
    final amount = minCoins + _rng.nextInt(max(1, maxCoins - minCoins + 1));
    final used = <int>{};
    for (int i = 0; i < amount; i++) {
      final col = _rng.nextInt(numColumns);
      if (used.add(col)) {
        lane.coins.add(Coin(col));
      }
    }
  }

  void _updateCarts(double dt) {
    final minLane = (cameraLane - 5).floor();
    final maxLane = (cameraLane + screenHeight / laneHeight + 5).ceil();

    for (int laneIndex = minLane; laneIndex <= maxLane; laneIndex++) {
      final lane = lanes[laneIndex];
      if (lane == null || lane.isSafe) {
        continue;
      }

      lane.carts.removeWhere((cart) {
        cart.update(dt);
        if (cart.movingRight) {
          return cart.x > screenWidth + 175;
        }
        return cart.x < -175;
      });
    }
  }

  void _spawnCarts(double dt) {
    final minLane = (cameraLane - 3).floor();
    final maxLane = (cameraLane + screenHeight / laneHeight + 3).ceil();

    for (int laneIndex = minLane; laneIndex <= maxLane; laneIndex++) {
      final lane = lanes[laneIndex];
      if (lane == null || lane.isSafe) {
        continue;
      }

      lane.spawnTimer += dt;
      if (lane.spawnTimer < lane.spawnInterval) {
        continue;
      }
      lane.spawnTimer = 0;

      if (lane.carts.length >= _maxCartsForLane(lane.index)) {
        continue;
      }

      final startX = lane.movingRight ? -88.0 : screenWidth + 88.0;
      final minSpawnGap = max(145.0, columnWidth * 2.05);
      final blocked = lane.carts.any((cart) {
        return cart.movingRight == lane.movingRight &&
            (cart.x - startX).abs() < minSpawnGap;
      });
      if (blocked) {
        continue;
      }

      lane.carts.add(
        Minecart(
          type: CartType.values[_rng.nextInt(CartType.values.length)],
          x: startX,
          speed: lane.speed * (0.94 + _rng.nextDouble() * 0.07),
          movingRight: lane.movingRight,
          sizeFactor: 0.74 + _rng.nextDouble() * 0.14,
        ),
      );
    }
  }

  void _collectCoinsOnCurrentTile() {
    final lane = lanes[chickenLane];
    if (lane == null) {
      return;
    }
    for (final coin in lane.coins) {
      if (coin.collected || coin.column != chickenCol) {
        continue;
      }
      coin.collected = true;
      collectedCoins += 1;
      score += (18 * multiplier).round();
    }
  }

  bool _hasCollisionAtLane(
      int laneIndex, double chickenCenterX, double chickenHalf) {
    final lane = lanes[laneIndex];
    if (lane == null || lane.isSafe) {
      return false;
    }

    for (final cart in lane.carts) {
      final cartHalf = columnWidth * 0.36 * cart.sizeFactor;
      if ((chickenCenterX - cart.x).abs() < chickenHalf + cartHalf) {
        return true;
      }
    }
    return false;
  }

  bool _checkCollision() {
    final chickenCenterX = chickenScreenX;
    final chickenHalf = columnWidth * 0.31;
    if (hopProgress >= 1.0) {
      return _hasCollisionAtLane(chickenLane, chickenCenterX, chickenHalf);
    }

    final activeLane =
        _prevLane + (chickenLane - _prevLane) * hopProgress;
    final candidateLanes = <int>{
      _prevLane,
      chickenLane,
      activeLane.floor(),
      activeLane.ceil(),
    };

    for (final laneIndex in candidateLanes) {
      if ((activeLane - laneIndex).abs() > 0.68 &&
          laneIndex != _prevLane &&
          laneIndex != chickenLane) {
        continue;
      }
      if (_hasCollisionAtLane(laneIndex, chickenCenterX, chickenHalf)) {
        return true;
      }
    }
    return false;
  }

  void _die() {
    state = GameState.gameOver;
    deathTimer = 0;
    shakeIntensity = 14;
    if (score > highScore) {
      highScore = score;
    }
    if (distance > bestDistance) {
      bestDistance = distance;
    }
  }
}
