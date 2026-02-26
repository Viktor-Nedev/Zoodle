class AppConfig {
  static String mapboxAccessToken =
      const String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  static bool get hasMapboxToken => mapboxAccessToken.isNotEmpty;
}
