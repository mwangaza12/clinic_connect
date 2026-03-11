class StorageKeys {
  static const String accessToken  = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId       = 'user_id';
  static const String facilityId   = 'facility_id';
  static const String isFirstLaunch = 'is_first_launch';

  // ── HIE Gateway credentials ──────────────────────────────────
  // Stored securely after setup wizard / login.
  // Required by HieApiService for every call to the gateway.
  static const String facilityApiKey = 'facility_api_key';
  static const String hieGatewayUrl  = 'hie_gateway_url';

  // ── Onboarding ───────────────────────────────────────────────
  // Set to 'true' after the user finishes the onboarding slides.
  // Never shown again after that.
  static const String hasSeenOnboarding = 'has_seen_onboarding';
}