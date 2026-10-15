// HTTP SERVICE: the only part of the app that talks to the REST API.
// Used for ACTIONS (create, call, attend, call next).
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/ticket.dart';

/// Error returned by the API with its structure { status, error, message }.
class ApiException implements Exception {
  final int status;
  final String code;
  final String message;

  ApiException(this.status, this.code, this.message);

  bool get isConflict => status == 409;

  @override
  String toString() => message;
}

class ApiService {
  static const _timeout = Duration(seconds: 10);
  static const _headers = {'Content-Type': 'application/json'};

  Uri _uri(String path) => Uri.parse('${Config.apiBase}$path');

  Future<List<Ticket>> listTickets() async {
    final data = await _send(() => http.get(_uri('/turnos')));
    return (data as List).map((j) => Ticket.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Ticket> createTicket({required String name, required String procedure}) async {
    final data = await _send(() => http.post(
          _uri('/turnos'),
          headers: _headers,
          body: jsonEncode({'nombre': name, 'tramite': procedure}),
        ));
    return Ticket.fromJson(data as Map<String, dynamic>);
  }

  Future<Ticket> changeStatus(int id, TicketStatus newStatus, String officer) async {
    final data = await _send(() => http.patch(
          _uri('/turnos/$id'),
          headers: _headers,
          body: jsonEncode({'estado': newStatus.name.toUpperCase(), 'funcionario': officer}),
        ));
    return Ticket.fromJson(data as Map<String, dynamic>);
  }

  Future<Ticket> callNext(String officer) async {
    final data = await _send(() => http.post(
          _uri('/turnos/llamar-siguiente'),
          headers: _headers,
          body: jsonEncode({'funcionario': officer}),
        ));
    return Ticket.fromJson(data as Map<String, dynamic>);
  }

  /// Sends the request, decodes the JSON answer and translates errors.
  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException(0, 'TIMEOUT', 'El servidor tardó demasiado en responder');
    } catch (_) {
      throw ApiException(0, 'SIN_CONEXION', 'No se pudo conectar con el servidor');
    }

    final body = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    final error = body is Map<String, dynamic> ? body : <String, dynamic>{};
    throw ApiException(
      response.statusCode,
      (error['error'] ?? 'ERROR') as String,
      (error['message'] ?? 'Error inesperado (${response.statusCode})') as String,
    );
  }
}
