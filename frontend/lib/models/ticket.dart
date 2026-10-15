// MODEL: what a ticket looks like and how it converts from/to JSON.

enum TicketStatus { pendiente, llamado, atendido }

class Ticket {
  final int id;
  final int number;
  final String name;
  final String procedure;
  final TicketStatus status;
  final String? officer; // null until someone calls the ticket
  final DateTime createdAt;
  final DateTime? calledAt;
  final DateTime? attendedAt;

  const Ticket({
    required this.id,
    required this.number,
    required this.name,
    required this.procedure,
    required this.status,
    required this.createdAt,
    this.officer,
    this.calledAt,
    this.attendedAt,
  });

  /// Deserialize: JSON from the API -> Ticket object.
  factory Ticket.fromJson(Map<String, dynamic> json) {
    DateTime? date(dynamic value) =>
        value == null ? null : DateTime.parse(value as String).toLocal();

    return Ticket(
      id: json['id'] as int,
      number: json['numero'] as int,
      name: json['nombre'] as String,
      procedure: json['tramite'] as String,
      // 'PENDIENTE' -> TicketStatus.pendiente
      status: TicketStatus.values.byName((json['estado'] as String).toLowerCase()),
      officer: json['funcionario'] as String?,
      createdAt: date(json['creado_en'])!,
      calledAt: date(json['llamado_en']),
      attendedAt: date(json['atendido_en']),
    );
  }

  /// Serialize: Ticket object -> JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'numero': number,
        'nombre': name,
        'tramite': procedure,
        'estado': status.name.toUpperCase(),
        'funcionario': officer,
        'creado_en': createdAt.toUtc().toIso8601String(),
        'llamado_en': calledAt?.toUtc().toIso8601String(),
        'atendido_en': attendedAt?.toUtc().toIso8601String(),
      };

  /// Display code: 7 -> "A-007"
  String get code => 'A-${number.toString().padLeft(3, '0')}';
}
