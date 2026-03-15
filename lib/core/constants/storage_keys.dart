class StorageKeys {
  StorageKeys._();

  static const String accessToken       = 'access_token';
  static const String refreshToken      = 'refresh_token';
  static const String userId            = 'user_id';
  static const String facilityId        = 'facility_id';
  static const String facilityName      = 'facility_name';
  static const String facilityCounty    = 'facility_county';
  static const String isFirstLaunch     = 'is_first_launch';

  // ── HIE Gateway credentials ───────────────────────────────────────────────
  static const String facilityApiKey    = 'facility_api_key';
  static const String hieGatewayUrl     = 'hie_gateway_url';

  // ── Facility backend URL (saved during setup from firebase-config response)
  // The Flutter app calls this backend, which proxies to the HIE gateway.
  // This is the correct call chain: Flutter → facilityBackend → HIE gateway.
  static const String facilityBackendUrl = 'facility_backend_url';

  // ── Firebase credentials (fetched from HIE Gateway at setup, persisted
  //    for cold-start restore — Firebase re-inits without a network call) ────
  static const String firebaseApiKey            = 'fb_api_key';
  static const String firebaseAppId             = 'fb_app_id';
  static const String firebaseProjectId         = 'fb_project_id';
  static const String firebaseMessagingSenderId  = 'fb_sender_id';
  static const String firebaseStorageBucket      = 'fb_bucket';
  static const String firebaseAuthDomain         = 'fb_auth_domain';

  // ── Onboarding ────────────────────────────────────────────────────────────
  static const String hasSeenOnboarding = 'has_seen_onboarding';
}