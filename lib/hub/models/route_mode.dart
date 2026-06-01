/// Persisted routing decision for each launch.
///
/// - [web]   → show WebView (returning user with a saved URL).
/// - [game]  → show the puzzle game (organic/unattributed user).
/// - [fresh] → no decision yet; full attribution pipeline will run.
enum RouteMode {
  web,
  game,
  fresh;

  String toKey() {
    switch (this) {
      case RouteMode.web:   return 'web';
      case RouteMode.game:  return 'game';
      case RouteMode.fresh: return 'fresh';
    }
  }

  static RouteMode fromKey(String? raw) {
    switch (raw) {
      case 'web':
      case 'browser':
        return RouteMode.web;
      case 'game':
      case 'dungeon':
        return RouteMode.game;
      default:
        return RouteMode.fresh;
    }
  }
}
