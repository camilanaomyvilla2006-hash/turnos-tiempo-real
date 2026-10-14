import 'package:flutter/material.dart';

void main() {
  runApp(const TurnosApp());
}

// La "app" completa: solo configura el tema y dice cuál es la pantalla inicial.
class TurnosApp extends StatelessWidget {
  const TurnosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestión de turnos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const PantallaTurnos(),
    );
  }
}

// StatefulWidget porque la pantalla "recuerda" cosas que cambian
// (por ejemplo, qué trámite eligió la persona en la lista desplegable).
class PantallaTurnos extends StatefulWidget {
  const PantallaTurnos({super.key});

  @override
  State<PantallaTurnos> createState() => _PantallaTurnosState();
}

class _PantallaTurnosState extends State<PantallaTurnos> {
  final _nombreController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _tramite = 'Caja';

  // Datos inventados (la "maqueta"). Después se reemplazan por los reales.
  final List<String> _pendientes = ['A-004 · Luis Rojas', 'A-005 · María Vega', 'A-006 · Pedro Solís'];
  final List<String> _llamados = ['A-003 · Carlos Jiménez', 'A-002 · Laura Pérez'];
  final List<String> _atendidos = ['A-001 · Ana Mora', 'A-000 · José Castro'];

  @override
  void dispose() {
    _nombreController.dispose();
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
            // ---------- Formulario ----------
            Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la persona',
                        border: OutlineInputBorder(),
                      ),
                      validator: (valor) => (valor == null || valor.trim().isEmpty)
                          ? 'Escriba un nombre'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _tramite,
                      decoration: const InputDecoration(
                        labelText: 'Trámite',
                        border: OutlineInputBorder(),
                      ),
                      items: const ['Caja', 'Consulta', 'Trámites']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (nuevo) {
                        if (nuevo != null) setState(() => _tramite = nuevo);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56, // misma altura que los campos
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text('Registrar turno'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---------- Botón grande ----------
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

            // ---------- Tres columnas ----------
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ColumnaTurnos(titulo: 'Pendientes', turnos: _pendientes)),
                  Expanded(child: ColumnaTurnos(titulo: 'Llamados', turnos: _llamados)),
                  Expanded(child: ColumnaTurnos(titulo: 'Atendidos', turnos: _atendidos)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Un widget reutilizable: se escribe UNA vez y se usa tres veces.
class ColumnaTurnos extends StatelessWidget {
  final String titulo;
  final List<String> turnos;

  const ColumnaTurnos({super.key, required this.titulo, required this.turnos});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '$titulo (${turnos.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: turnos
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