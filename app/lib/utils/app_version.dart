/// Version information for the application
/// These values are injected at build time via the Makefile
class AppVersion {
<<<<<<< HEAD
  static const String version = "";
  static const String buildHash = "";
=======
  static const String version = "v0.9.0";
  static const String buildHash = "202d07e";
>>>>>>> b829d675172ae5c8053fde93a9d2ff2953cd9862
  
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
