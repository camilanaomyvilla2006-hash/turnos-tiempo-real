import 'package:flutter/material.dart';

import 'models/ticket.dart';

void main() {
  runApp(const TicketsApp());
}

// The whole app: only sets the theme and the initial screen.
class TicketsApp extends StatelessWidget {
  const TicketsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestión de turnos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const TicketsScreen(),
    );
  }
}

// StatefulWidget because the screen "remembers" things that change
// (for example, which procedure was selected in the dropdown).
class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _procedure = 'CAJA';

  // Value sent to the API -> text shown to the user.
  static const _procedures = {
    'CAJA': 'Caja',
    'CONSULTA': 'Consulta',
    'TRAMITES': 'Trámites',
  };

  // Fake data shaped EXACTLY like the API JSON. Later it comes from the API.
  final List<Ticket> _tickets = [
    {'id': 1, 'numero': 1, 'nombre': 'Ana Mora', 'tramite': 'CAJA', 'estado': 'ATENDIDO',
     'funcionario': 'Camila', 'creado_en': '2026-10-14T15:00:00Z',
     'llamado_en': '2026-10-14T15:05:00Z', 'atendido_en': '2026-10-14T15:10:00Z'},
    {'id': 2, 'numero': 2, 'nombre': 'Carlos Jiménez', 'tramite': 'CONSULTA', 'estado': 'LLAMADO',
     'funcionario': 'Darlin', 'creado_en': '2026-10-14T15:02:00Z',
     'llamado_en': '2026-10-14T15:12:00Z', 'atendido_en': null},
    {'id': 3, 'numero': 3, 'nombre': 'Luis Rojas', 'tramite': 'CAJA', 'estado': 'PENDIENTE',
     'funcionario': null, 'creado_en': '2026-10-14T15:04:00Z',
     'llamado_en': null, 'atendido_en': null},
    {'id': 4, 'numero': 4, 'nombre': 'María Vega', 'tramite': 'TRAMITES', 'estado': 'PENDIENTE',
     'funcionario': null, 'creado_en': '2026-10-14T15:06:00Z',
     'llamado_en': null, 'atendido_en': null},
    {'id': 5, 'numero': 5, 'nombre': 'Pedro Solís', 'tramite': 'CONSULTA', 'estado': 'PENDIENTE',
     'funcionario': null, 'creado_en': '2026-10-14T15:08:00Z',
     'llamado_en': null, 'atendido_en': null},
  ].map(Ticket.fromJson).toList();

  // Tickets with a given status, ordered by number.
  List<Ticket> _withStatus(TicketStatus status) =>
      _tickets.where((t) => t.status == status).toList()
        ..sort((a, b) => a.number.compareTo(b.number));

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de turnos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---------- Form ----------
            Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la persona',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Escriba un nombre'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _procedure,
                      decoration: const InputDecoration(
                        labelText: 'Trámite',
                        border: OutlineInputBorder(),
                      ),
                      items: _procedures.entries
                          .map((p) => DropdownMenuItem(value: p.key, child: Text(p.value)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _procedure = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56, // same height as the fields
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text('Registrar turno'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---------- Big button ----------
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.campaign, size: 28),
                label: const Text('Llamar siguiente', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 16),

            // ---------- Three columns ----------
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: TicketColumn(title: 'Pendientes', tickets: _withStatus(TicketStatus.pendiente))),
                  Expanded(child: TicketColumn(title: 'Llamados', tickets: _withStatus(TicketStatus.llamado))),
                  Expanded(child: TicketColumn(title: 'Atendidos', tickets: _withStatus(TicketStatus.atendido))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A reusable widget: written ONCE and used three times.
class TicketColumn extends StatelessWidget {
  final String title;
  final List<Ticket> tickets;

  const TicketColumn({super.key, required this.title, required this.tickets});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '$title (${tickets.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: tickets
                  .map((t) => ListTile(
                        leading: const Icon(Icons.confirmation_number_outlined),
                        title: Text('${t.code} · ${t.name}'),
                        subtitle: Text(t.officer == null ? t.procedure : '${t.procedure} · ${t.officer}'),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}