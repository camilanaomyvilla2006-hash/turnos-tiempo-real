// WEBSOCKET SERVICE: keeps a channel open with the backend to RECEIVE
// real-time events, and reconnects by itself if the connection drops.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../models/ticket.dart';

enum ConnectionStatus { connecting, connected, reconnecting }

/// Messages that arrive from the server.
sealed class SocketEvent {}

/// Full picture of the real state (on connect or reconnect).
class SnapshotEvent extends SocketEvent {
  final List<Ticket> tickets;
  SnapshotEvent(this.tickets);
}

/// A ticket was created or changed.
class TicketChangedEvent extends SocketEvent {
  final Ticket ticket;
  TicketChangedEvent(this.ticket);
}

class SocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _retryTimer;
  int _attempts = 0;
  bool _closed = false;

  final _events = StreamController<SocketEvent>.broadcast();
  final _status = StreamController<ConnectionStatus>.broadcast();

  Stream<SocketEvent> get events => _events.stream;
  Stream<ConnectionStatus> get status => _status.stream;

  Future<void> connect() async {
    if (_closed) return;
    _status.add(_attempts == 0 ? ConnectionStatus.connecting : ConnectionStatus.reconnecting);

    try {
      final channel = WebSocketChannel.connect(Uri.parse(Config.wsUrl));
      await channel.ready; // throws if the server is not available
      _channel = channel;
      _attempts = 0;
      _status.add(ConnectionStatus.connected);

      _subscription = channel.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect, // the server closed the connection
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  /// Ask the server for a full snapshot again (for example, after a 409).
  void requestSync() {
    _channel?.sink.add(jsonEncode({'tipo': 'SYNC'}));
  }

  void _onMessage(dynamic data) {
    final message = jsonDecode(data as String) as Map<String, dynamic>;
    switch (message['tipo']) {
      case 'SNAPSHOT':
        final tickets = (message['turnos'] as List)
            .map((j) => Ticket.fromJson(j as Map<String, dynamic>))
            .toList();
        _events.add(SnapshotEvent(tickets));
      case 'TURNO_CREADO':
      case 'TURNO_ACTUALIZADO':
        _events.add(TicketChangedEvent(Ticket.fromJson(message['turno'] as Map<String, dynamic>)));
    }
  }

  /// RECONNECTION with growing waits (1 s, 2 s, 4 s, 8 s... max 15 s)
  /// so we do not flood the server while it is down.
  void _scheduleReconnect() {
    if (_closed) return;
    if (_retryTimer?.isActive ?? false) return; // a retry is already scheduled
    _subscription?.cancel();
    _channel = null;
    _status.add(ConnectionStatus.reconnecting);

    final seconds = min(15, pow(2, _attempts).toInt());
    _attempts++;
    _retryTimer = Timer(Duration(seconds: seconds), connect);
  }

  Future<void> close() async {
    _closed = true;
    _retryTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _events.close();
    await _status.close();
  }
}
