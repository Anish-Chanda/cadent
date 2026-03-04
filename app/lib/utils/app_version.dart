/// Version information for the application
/// These values are injected at build time via the Makefile
class AppVersion {
  static const String version = "";
  static const String buildHash = "";
  
  /// Returns formatted version string with build hash
  /// Example: "v1.0.0 (a1b2c3d)"
  static String get fullVersion {
    if (version.isEmpty && buildHash.isEmpty) {
      return "Development Build";
    }
    if (buildHash.isEmpty) {
      return version;
    }
    return "$version ($buildHash)";
  }
}
