import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_app/main.dart';

void main() {
  testWidgets('The tickets screen is displayed', (WidgetTester tester) async {
    await tester.pumpWidget(const TicketsApp());

    expect(find.text('Gestión de turnos'), findsOneWidget);
    expect(find.text('Llamar siguiente'), findsOneWidget);
    expect(find.text('Pendientes (3)'), findsOneWidget);
  });
}