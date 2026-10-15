import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_app/main.dart';
import 'package:turnos_app/models/ticket.dart';
import 'package:turnos_app/services/socket_service.dart';

// A ticket exactly as the API sends it (Spanish keys from the database).
final apiJson = {
  'id': 1,
  'numero': 7,
  'nombre': 'Ana Mora',
  'tramite': 'CAJA',
  'estado': 'LLAMADO',
  'funcionario': 'Camila',
  'creado_en': '2026-10-14T22:10:00.000Z',
  'llamado_en': '2026-10-14T22:12:00.000Z',
  'atendido_en': null,
  'version': 2,
};

void main() {
  test('fromJson converts the API JSON into a Ticket', () {
    final ticket = Ticket.fromJson(apiJson);

    expect(ticket.code, 'A-007');
    expect(ticket.name, 'Ana Mora');
    expect(ticket.status, TicketStatus.llamado);
    expect(ticket.officer, 'Camila');
    expect(ticket.version, 2);
  });

  testWidgets('The banner warns when the connection is lost', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ConnectionBanner(status: ConnectionStatus.reconnecting)),
    ));

    expect(find.textContaining('Reconectando'), findsOneWidget);
  });

  testWidgets('The panel shows the ticket being attended', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CurrentTicketPanel(ticket: Ticket.fromJson(apiJson))),
    ));

    expect(find.text('A-007'), findsOneWidget);
    expect(find.text('ATENDIENDO AHORA'), findsOneWidget);
  });
}