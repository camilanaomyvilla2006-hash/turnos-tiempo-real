// SERVICE: business rules and validations.
// It knows nothing about HTTP or SQL: it only asks the repository for data.
const AppError = require('../utils/AppError');
const repository = require('../repositories/tickets.repository');

// Sets of allowed values: validating is asking "is it in the set or not?".
const PROCEDURES = new Set(['CAJA', 'CONSULTA', 'TRAMITES']);
const STATUSES = new Set(['PENDIENTE', 'LLAMADO', 'ATENDIDO']);

// Valid transitions: PENDIENTE -> LLAMADO -> ATENDIDO. An attended ticket cannot go back.
const TRANSITIONS = {
  PENDIENTE: ['LLAMADO'],
  LLAMADO: ['ATENDIDO'],
  ATENDIDO: [],
};

function validateText(value, field, min, max) {
  if (typeof value !== 'string' || value.trim().length < min || value.trim().length > max) {
    throw new AppError(400, 'VALIDATION_ERROR',
      `El campo ${field} es obligatorio y debe tener entre ${min} y ${max} caracteres`);
  }
  return value.trim();
}

function validateId(id) {
  const number = Number(id);
  if (!Number.isInteger(number) || number <= 0) {
    throw new AppError(400, 'VALIDATION_ERROR', 'El id del turno no es válido');
  }
  return number;
}

async function list(status) {
  if (status !== undefined && !STATUSES.has(status)) {
    throw new AppError(400, 'VALIDATION_ERROR', 'El estado indicado no es válido');
  }
  return repository.findAll(status);
}

async function getById(id) {
  const ticket = await repository.findById(validateId(id));
  if (!ticket) throw new AppError(404, 'NOT_FOUND', 'El turno no existe');
  return ticket;
}

// Rule: the NUMBER is assigned by the system. Even if the client sends one, it is ignored.
async function create(data = {}) {
  const name = validateText(data.nombre, 'nombre', 3, 80);
  if (!PROCEDURES.has(data.tramite)) {
    throw new AppError(400, 'VALIDATION_ERROR', 'El trámite debe ser CAJA, CONSULTA o TRAMITES');
  }
  return repository.create({ name, procedure: data.tramite });
}

async function changeStatus(id, data = {}) {
  const ticketId = validateId(id);
  if (!STATUSES.has(data.estado)) {
    throw new AppError(400, 'VALIDATION_ERROR', 'El estado indicado no es válido');
  }
  const officer = validateText(data.funcionario, 'funcionario', 3, 60);

  const current = await repository.findById(ticketId);
  if (!current) throw new AppError(404, 'NOT_FOUND', 'El turno no existe');

  if (!TRANSITIONS[current.estado].includes(data.estado)) {
    throw new AppError(409, 'TRANSICION_INVALIDA',
      `No se puede pasar de ${current.estado} a ${data.estado}`);
  }

   const updated = await repository.updateStatus({
    id: ticketId,
    currentStatus: current.estado,
    currentVersion: current.version,
    newStatus: data.estado,
    officer,
  });

  if (!updated) {
    throw new AppError(409, 'CONFLICTO_CONCURRENCIA',
      'Otro funcionario modificó este turno al mismo tiempo. Intente de nuevo.');
  }
  return updated;
}

module.exports = { list, getById, create, changeStatus };