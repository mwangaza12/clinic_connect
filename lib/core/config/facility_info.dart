class FacilityInfo {
  static final FacilityInfo _instance = FacilityInfo._internal();
  factory FacilityInfo() => _instance;
  FacilityInfo._internal();

  String _facilityId = '';
  String _facilityName = '';
  String _facilityCounty = '';

  String get facilityId => _facilityId;
  String get facilityName => _facilityName;
  String get facilityCounty => _facilityCounty;

  bool get isSet => _facilityId.isNotEmpty;

  // ✅ facilityCounty is now optional
  void set({
    required String facilityId,
    required String facilityName,
    String facilityCounty = '',
  }) {
    _facilityId = facilityId;
    _facilityName = facilityName;
    _facilityCounty = facilityCounty;
  }

  void clear() {
    _facilityId = '';
    _facilityName = '';
    _facilityCounty = '';
  }

  @override
  String toString() =>
      'FacilityInfo(id: $_facilityId, name: $_facilityName, county: $_facilityCounty)';
}