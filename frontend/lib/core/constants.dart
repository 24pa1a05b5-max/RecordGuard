class AppConstants {
  static const String appName = "RecordGuard AI";
  static const String appSubtitle = "Healthcare Record Contradiction Detector";
  static const String version = "1.0.0";

  static const String defaultApiUrl = "http://127.0.0.1:8000/api";

  // Storage Keys
  static const String keyApiUrl = "rg_api_base_url";
  static const String keyUserSession = "rg_user_session";

  // Review Decision Constants
  static const String statusPending = "PENDING_REVIEW";
  static const String statusConfirmed = "CONFIRMED";
  static const String statusResolved = "RESOLVED";
  static const String statusUnresolved = "UNRESOLVED";
  static const String statusRequestedDocs = "REQUESTED_DOCS";
}
