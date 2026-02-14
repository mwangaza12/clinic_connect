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
    // Check initial state
    final result = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(result as ConnectivityResult);

    // Listen for changes
    _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = _isConnected(result as ConnectivityResult);

      if (_isOnline != wasOnline) {
        _controller.add(_isOnline);
      }
    });
  }

  bool _isConnected(ConnectivityResult result) {
    return result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet;
  }

  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(result as ConnectivityResult);
    return _isOnline;
  }

  void dispose() {
    _controller.close();
  }
}