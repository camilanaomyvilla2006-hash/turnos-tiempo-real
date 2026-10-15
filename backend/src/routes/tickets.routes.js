// ROUTES: map each HTTP method + path to a controller function.
// It works like a Map: "GET /" -> controller.list
const express = require('express');
const controller = require('../controllers/tickets.controller');

const router = express.Router();

router.get('/', controller.list);                         // GET   /api/turnos?estado=PENDIENTE
router.post('/llamar-siguiente', controller.callNext);    // POST  /api/turnos/llamar-siguiente
router.get('/:id', controller.getById);                   // GET   /api/turnos/7
router.post('/', controller.create);                      // POST  /api/turnos
router.patch('/:id', controller.changeStatus);            // PATCH /api/turnos/7

module.exports = router;