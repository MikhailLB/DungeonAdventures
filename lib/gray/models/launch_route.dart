enum LaunchRoute {
  web,
  arcade,
  pristine;

  static LaunchRoute fromString(String? value) {
    switch (value) {
      case 'web':
        return LaunchRoute.web;
      case 'arcade':
        return LaunchRoute.arcade;
      default:
        return LaunchRoute.pristine;
    }
  }

  String toStorageString() {
    switch (this) {
      case LaunchRoute.web:
        return 'web';
      case LaunchRoute.arcade:
        return 'arcade';
      case LaunchRoute.pristine:
        return 'pristine';
    }
  }
}
