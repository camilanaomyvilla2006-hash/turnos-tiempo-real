// CONTROLLER: receives the HTTP request, calls the service and answers.
// It contains NO business rules (the waiter does not cook).
const service = require('../services/tickets.service');

async function list(req, res) {
  res.status(200).json(await service.list(req.query.estado));
}

async function getById(req, res) {
  res.status(200).json(await service.getById(req.params.id));
}

async function create(req, res) {
  res.status(201).json(await service.create(req.body)); // 201 = created
}

async function changeStatus(req, res) {
  res.status(200).json(await service.changeStatus(req.params.id, req.body));
}

module.exports = { list, getById, create, changeStatus };