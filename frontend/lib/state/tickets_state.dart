// STATE of the app. It is immutable: every change creates a NEW state with
// copyWith, and the Cubit emits it so Flutter redraws the screen.
import '../models/ticket.dart';
import '../services/socket_service.dart';

class TicketsState {
  /// Tickets stored in a Map (id -> ticket): finding or replacing one by id is instant.
  final Map<int, Ticket> tickets;
  final ConnectionStatus connection;
  final bool loading;
  final String? officer;

  /// Ids of tickets with an operation in progress (to disable their buttons).
  final Set<int> busy;
  final bool callingNext;

  /// Message to show in a SnackBar. The id changes with every new message,
  /// so the same text can be shown twice.
  final String? message;
  final bool messageIsError;
  final int messageId;

  const TicketsState({
    this.tickets = const {},
    this.connection = ConnectionStatus.connecting,
    this.loading = true,
    this.officer,
    this.busy = const {},
    this.callingNext = false,
    this.message,
    this.messageIsError = false,
    this.messageId = 0,
  });

  List<Ticket> withStatus(TicketStatus status) =>
      tickets.values.where((t) => t.status == status).toList()
        ..sort((a, b) => a.number.compareTo(b.number));

  TicketsState copyWith({
    Map<int, Ticket>? tickets,
    ConnectionStatus? connection,
    bool? loading,
    String? officer,
    Set<int>? busy,
    bool? callingNext,
  }) {
    return TicketsState(
      tickets: tickets ?? this.tickets,
      connection: connection ?? this.connection,
      loading: loading ?? this.loading,
      officer: officer ?? this.officer,
      busy: busy ?? this.busy,
      callingNext: callingNext ?? this.callingNext,
      message: message,
      messageIsError: messageIsError,
      messageId: messageId,
    );
  }

  TicketsState withMessage(String text, {bool error = false}) => TicketsState(
        tickets: tickets,
        connection: connection,
        loading: loading,
        officer: officer,
        busy: busy,
        callingNext: callingNext,
        message: text,
        messageIsError: error,
        messageId: messageId + 1,
      );
}