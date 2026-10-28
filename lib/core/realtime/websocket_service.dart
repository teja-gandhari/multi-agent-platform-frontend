import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../network/api_config.dart';

enum WsConnectionStatus { disconnected, connecting, connected, error }

/// Real-time WebSocket client for project agent events.
class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _status = StreamController<WsConnectionStatus>.broadcast();

  WsConnectionStatus _currentStatus = WsConnectionStatus.disconnected;

  WsConnectionStatus get currentStatus => _currentStatus;
  Stream<Map<String, dynamic>> get events => _events.stream;
  Stream<WsConnectionStatus> get statusStream => _status.stream;

  void _setStatus(WsConnectionStatus status) {
    _currentStatus = status;
    if (!_status.isClosed) {
      _status.add(status);
    }
  }

  Future<void> connect(String projectId, String token) async {
    await disconnect();

    _setStatus(WsConnectionStatus.connecting);
    final wsUri = ApiConfig.buildWsUri(projectId, token);

    try {
      final channel = WebSocketChannel.connect(wsUri);
      _channel = channel;
      await channel.ready;
      _setStatus(WsConnectionStatus.connected);

      _subscription = channel.stream.listen(
        (dynamic raw) {
          try {
            final decoded = raw is String ? jsonDecode(raw) : raw;
            if (decoded is Map<String, dynamic>) {
              _events.add(decoded);
            } else if (decoded is Map) {
              _events.add(Map<String, dynamic>.from(decoded));
            }
          } catch (_) {
            // Handle plain-text frames safely
            _events.add({
              'agent': 'system',
              'status': 'info',
              'message': raw.toString(),
            });
          }
        },
        onError: (dynamic error) {
          _setStatus(WsConnectionStatus.error);
        },
        onDone: () {
          _setStatus(WsConnectionStatus.disconnected);
        },
      );
    } catch (e) {
      _setStatus(WsConnectionStatus.error);
    }
  }

  Future<void> disconnect() async {
    try {
      await _subscription?.cancel();
      _subscription = null;
      await _channel?.sink.close();
      _channel = null;
    } catch (_) {}
    _setStatus(WsConnectionStatus.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
    await _status.close();
  }
}
