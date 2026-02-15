import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityManager {
  static final ConnectivityManager _instance =
      ConnectivityManager._internal();
  factory ConnectivityManager() => _instance;
  ConnectivityManager._internal();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> init() async {
    // ✅ checkConnectivity() returns List<ConnectivityResult>
    final results = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(results);

    // ✅ onConnectivityChanged emits List<ConnectivityResult>
    _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _isConnected(results);

      if (_isOnline != wasOnline) {
        _controller.add(_isOnline);
      }
    });
  }

  // ✅ Takes List — online if ANY result is connected
  bool _isConnected(List<ConnectivityResult> results) {
    return results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet,
    );
  }

  Future<bool> checkConnectivity() async {
    // ✅ Returns List now
    final results = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(results);
    return _isOnline;
  }

  void dispose() {
    _controller.close();
  }
}