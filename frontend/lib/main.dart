import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'models/ticket.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'state/tickets_cubit.dart';
import 'state/tickets_state.dart';

// ---------- Visual helpers: labels and icons shown to the user ----------
// The API uses codes (CAJA, CONSULTA, TRAMITES); the user sees friendly names.
const procedureLabels = {
  'CAJA': 'Caja',
  'CONSULTA': 'Consulta',
  'TRAMITES': 'Trámites',
};

String procedureLabel(String code) => procedureLabels[code] ?? code;

IconData procedureIcon(String code) => switch (code) {
  'CAJA' => Icons.payments_outlined,
  'CONSULTA' => Icons.support_agent_outlined,
  _ => Icons.description_outlined,
};

// Each status has its own color and icon, so it is recognized at a glance.
Color statusColor(TicketStatus status) => switch (status) {
  TicketStatus.pendiente => const Color(0xFFC77700), // amber
  TicketStatus.llamado => const Color(0xFF1E6FD9), // blue
  TicketStatus.atendido => const Color(0xFF2E9D5B), // green
};

IconData statusIcon(TicketStatus status) => switch (status) {
  TicketStatus.pendiente => Icons.hourglass_top,
  TicketStatus.llamado => Icons.campaign_outlined,
  TicketStatus.atendido => Icons.check_circle_outline,
};

void main() {
  runApp(const TicketsApp());
}

class TicketsApp extends StatelessWidget {
  const TicketsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestión de turnos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      // The Cubit is created once and is available to the whole screen.
      home: BlocProvider(
        create: (_) => TicketsCubit(ApiService(), SocketService())..start(),
        child: const TicketsScreen(),
      ),
    );
  }
}

// The screen only SHOWS the state and tells the Cubit what the user did.
// It has no business rules and no HTTP calls.
class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  bool _askingOfficer = false;

  Future<void> _askOfficer({String? current}) async {
    if (_askingOfficer) return;
    _askingOfficer = true;
    final cubit = context.read<TicketsCubit>();
    final name = await showOfficerDialog(context, current: current);
    if (name != null) cubit.setOfficer(name);
    _askingOfficer = false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TicketsCubit, TicketsState>(
      // Show a SnackBar only when a NEW message arrives.
      listenWhen: (before, now) => before.messageId != now.messageId,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.message ?? ''),
              backgroundColor: state.messageIsError
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          );
      },
      child: BlocBuilder<TicketsCubit, TicketsState>(
        builder: (context, state) {
          // Ask for the officer's name the first time.
          if (!state.loading && state.officer == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _askOfficer());
          }
          final cubit = context.read<TicketsCubit>();

          return Scaffold(
            appBar: AppBar(
              title: const Text('Gestión de turnos'),
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.badge_outlined),
                  label: Text(state.officer ?? 'Sin funcionario'),
                  onPressed: () => _askOfficer(current: state.officer),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Column(
              children: [
                ConnectionBanner(status: state.connection),
                Expanded(
                  child: state.loading
                      ? const Center(child: CircularProgressIndicator())
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const TicketForm(),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 64,
                                child: FilledButton.icon(
                                  onPressed:
                                      state.officer != null &&
                                          !state.callingNext &&
                                          state
                                              .withStatus(
                                                TicketStatus.pendiente,
                                              )
                                              .isNotEmpty
                                      ? cubit.callNext
                                      : null,
                                  icon: const Icon(Icons.campaign, size: 28),
                                  label: const Text(
                                    'Llamar siguiente',
                                    style: TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final (status, title) in [
                                      (TicketStatus.pendiente, 'Pendientes'),
                                      (TicketStatus.llamado, 'Llamados'),
                                      (TicketStatus.atendido, 'Atendidos'),
                                    ])
                                      Expanded(
                                        child: TicketColumn(
                                          title: title,
                                          status: status,
                                          tickets: state.withStatus(status),
                                          busy: state.busy,
                                          onCall: cubit.call,
                                          onAttend: cubit.attend,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------- Form to register a ticket (validations for the user's comfort) ----------
class TicketForm extends StatefulWidget {
  const TicketForm({super.key});

  @override
  State<TicketForm> createState() => _TicketFormState();
}

class _TicketFormState extends State<TicketForm> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _procedure = 'CAJA';
  bool _sending = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    final ok = await context.read<TicketsCubit>().createTicket(
      _nameController.text.trim(),
      _procedure,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _nameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
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
              onFieldSubmitted: (_) => _register(),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Escriba un nombre';
                if (text.length < 3) return 'Mínimo 3 caracteres';
                if (text.length > 80) return 'Máximo 80 caracteres';
                return null;
              },
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
              items: procedureLabels.entries
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.key,
                      child: Row(
                        children: [
                          Icon(procedureIcon(p.key), size: 18),
                          const SizedBox(width: 8),
                          Text(p.value),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _procedure = value);
              },
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _sending ? null : _register,
              child: Text(_sending ? 'Registrando…' : 'Registrar turno'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- One column (Pendientes, Llamados or Atendidos) ----------
class TicketColumn extends StatelessWidget {
  final String title;
  final TicketStatus status;
  final List<Ticket> tickets;
  final Set<int> busy;
  final void Function(Ticket) onCall;
  final void Function(Ticket) onAttend;

  const TicketColumn({
    super.key,
    required this.title,
    required this.status,
    required this.tickets,
    required this.busy,
    required this.onCall,
    required this.onAttend,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Card(
      margin: const EdgeInsets.all(6),
      clipBehavior:
          Clip.antiAlias, // the colored header follows the rounded corners
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border(bottom: BorderSide(color: color, width: 3)),
            ),
            child: Row(
              children: [
                Icon(statusIcon(status), color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                // Counter badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tickets.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: tickets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon(status),
                          size: 40,
                          color: color.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 8),

                                                Text(
                          _emptyText(),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: tickets.map((t) {
                      final isBusy = busy.contains(t.id);
                      final Widget? action = switch (t.status) {
                        TicketStatus.pendiente => OutlinedButton(
                          onPressed: isBusy ? null : () => onCall(t),
                          child: const Text('Llamar'),
                        ),
                        TicketStatus.llamado => FilledButton(
                          onPressed: isBusy ? null : () => onAttend(t),
                          child: const Text('Atendido'),
                        ),
                        TicketStatus.atendido => null,
                      };
                      return ListTile(
                        // The ticket code looks like a printed ticket, in the column's color
                        leading: Container(
                          width: 76,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            border: Border.all(color: color, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            t.code,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                        title: Text(
                          t.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(procedureIcon(t.procedure), size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _detail(t),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        trailing: isBusy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : action,
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // Message shown when the column has no tickets.
  String _emptyText() => switch (status) {
    TicketStatus.pendiente => 'No hay turnos pendientes',
    TicketStatus.llamado => 'No hay turnos llamados',
    TicketStatus.atendido => 'Aún no hay turnos atendidos',
  };

  // Text under each ticket: procedure, time and officer (the history with date and time).
  String _detail(Ticket t) {
    String time(DateTime? d) => d == null
        ? '--:--'
        : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return switch (t.status) {
      TicketStatus.pendiente =>
        '${procedureLabel(t.procedure)} · registrado ${time(t.createdAt)}',
      TicketStatus.llamado =>
        '${procedureLabel(t.procedure)} · llamado ${time(t.calledAt)} por ${t.officer}',
      TicketStatus.atendido =>
        '${procedureLabel(t.procedure)} · atendido ${time(t.attendedAt)} por ${t.officer}',
    };
  }
}

// ---------- Bar that shows the real-time connection status ----------
class ConnectionBanner extends StatelessWidget {
  final ConnectionStatus status;
  const ConnectionBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (text, icon, background) = switch (status) {
      ConnectionStatus.connected => (
        'En tiempo real',
        Icons.wifi,
        colors.primaryContainer,
      ),
      ConnectionStatus.connecting => (
        'Conectando…',
        Icons.sync,
        colors.surfaceContainerHighest,
      ),
      ConnectionStatus.reconnecting => (
        'Sin conexión en tiempo real. Reconectando… (los datos pueden estar desactualizados)',
        Icons.wifi_off,
        colors.errorContainer,
      ),
    };
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

// ---------- Dialog to type the officer's name ----------
Future<String?> showOfficerDialog(BuildContext context, {String? current}) {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController(text: current);

  void accept(BuildContext ctx) {
    if (formKey.currentState!.validate())
      Navigator.of(ctx).pop(controller.text.trim());
  }

  return showDialog<String>(
    context: context,
    barrierDismissible: current != null, // the first time it is mandatory
    builder: (ctx) => AlertDialog(
      title: const Text('¿Quién atiende?'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre del funcionario',
          ),
          onFieldSubmitted: (_) => accept(ctx),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.length < 3) return 'Mínimo 3 caracteres';
            if (text.length > 60) return 'Máximo 60 caracteres';
            return null;
          },
        ),
      ),
      actions: [
        if (current != null)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        FilledButton(
          onPressed: () => accept(ctx),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
