import 'package:flutter/material.dart';

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

  // Fake data (the "mock-up"). Later replaced by real data from the API.
  final List<String> _pending = ['A-004 · Luis Rojas', 'A-005 · María Vega', 'A-006 · Pedro Solís'];
  final List<String> _called = ['A-003 · Carlos Jiménez', 'A-002 · Laura Pérez'];
  final List<String> _attended = ['A-001 · Ana Mora', 'A-000 · José Castro'];

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
                  Expanded(child: TicketColumn(title: 'Pendientes', tickets: _pending)),
                  Expanded(child: TicketColumn(title: 'Llamados', tickets: _called)),
                  Expanded(child: TicketColumn(title: 'Atendidos', tickets: _attended)),
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
  final List<String> tickets;

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
                        title: Text(t),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}