// CUBIT: manages the state of the tickets.
// Flow: user -> Cubit method -> REST API -> new state -> screen.
//       Another browser changes something -> WebSocket event -> new state -> screen.
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'tickets_state.dart';

class TicketsCubit extends Cubit<TicketsState> {
  final ApiService _api;
  final SocketService _socket;
  final List<StreamSubscription> _subscriptions = [];

  TicketsCubit(this._api, this._socket) : super(const TicketsState());

  Future<void> start() async {
    _subscriptions.add(_socket.status.listen(
      (status) => emit(state.copyWith(connection: status)),
    ));
    _subscriptions.add(_socket.events.listen(_onEvent));
    await _socket.connect();
  }

  void _onEvent(SocketEvent event) {
    switch (event) {
      // SNAPSHOT: the database is the source of truth. Take the full picture
      // (this recovers what happened while disconnected), but keep any local
      // ticket that is NEWER than the one in the snapshot.
      case SnapshotEvent(:final tickets):
        final fresh = {for (final t in tickets) t.id: t};
        for (final local in state.tickets.values) {
          final remote = fresh[local.id];
          if (remote != null && local.version > remote.version) fresh[local.id] = local;
        }
        emit(state.copyWith(tickets: fresh, loading: false));
      case TicketChangedEvent(:final ticket):
        _apply(ticket);
    }
  }

  /// Apply a ticket ONLY if it is newer than the one we have.
  /// A late or out-of-order message has a lower or equal version and is ignored,
  /// so the screen never goes back to old data.
  void _apply(Ticket ticket) {
    final current = state.tickets[ticket.id];
    if (current != null && current.version >= ticket.version) return;
    emit(state.copyWith(tickets: {...state.tickets, ticket.id: ticket}));
  }

  void setOfficer(String name) {
    emit(state.copyWith(officer: name).withMessage('Trabajando como $name'));
  }

  Future<bool> createTicket(String name, String procedure) async {
    try {
      final ticket = await _api.createTicket(name: name, procedure: procedure);
      _apply(ticket);
      emit(state.withMessage('Turno ${ticket.code} registrado para ${ticket.name}'));
      return true;
    } on ApiException catch (e) {
      _showError(e);
      return false;
    }
  }

  Future<void> callNext() async {
    final officer = state.officer;
    if (officer == null || state.callingNext) return;

    emit(state.copyWith(callingNext: true));
    try {
      final ticket = await _api.callNext(officer);
      _apply(ticket);
      emit(state.copyWith(callingNext: false)
          .withMessage('Usted llamó el turno ${ticket.code} (${ticket.name})'));
    } on ApiException catch (e) {
      emit(state.copyWith(callingNext: false));
      _showError(e);
    }
  }

  Future<void> call(Ticket ticket) => _changeStatus(ticket, TicketStatus.llamado);

  Future<void> attend(Ticket ticket) => _changeStatus(ticket, TicketStatus.atendido);

  Future<void> _changeStatus(Ticket ticket, TicketStatus newStatus) async {
    final officer = state.officer;
    if (officer == null || state.busy.contains(ticket.id)) return;

    emit(state.copyWith(busy: {...state.busy, ticket.id}));
    try {
      final updated = await _api.changeStatus(ticket.id, newStatus, officer);
      _apply(updated);
      emit(state.copyWith(busy: {...state.busy}..remove(ticket.id))
          .withMessage('Turno ${ticket.code} pasó a ${newStatus.name.toUpperCase()}'));
    } on ApiException catch (e) {
      emit(state.copyWith(busy: {...state.busy}..remove(ticket.id)));
      _showError(e);
    }
  }

  void _showError(ApiException e) {
    emit(state.withMessage(e.message, error: true));
    // A 409 means our data was outdated: ask the server for the real state.
    if (e.isConflict) _socket.requestSync();
  }

  @override
  Future<void> close() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _socket.close();
    return super.close();
  }
}