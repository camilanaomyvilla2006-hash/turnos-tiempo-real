// Error handling with a CONSISTENT structure for the whole API:
// { status, error, message, timestamp }
const AppError = require('../utils/AppError');

function notFound(req, res) {
  res.status(404).json({
    status: 404,
    error: 'NOT_FOUND',
    message: `La ruta ${req.method} ${req.originalUrl} no existe`,
    timestamp: new Date().toISOString(),
  });
}

// Express recognizes an error handler because it has 4 parameters.
// eslint-disable-next-line no-unused-vars
function handleErrors(err, req, res, next) {
  let status = 500;
  let error = 'INTERNAL_ERROR';
  let message = 'Ocurrió un error interno en el servidor';

  if (err instanceof AppError) {
    ({ status, error, message } = err); // our controlled errors
  } else if (err.type === 'entity.parse.failed') {
    status = 400;                        // malformed JSON in the body
    error = 'JSON_INVALIDO';
    message = 'El cuerpo de la solicitud no es un JSON válido';
  } else {
    console.error(err);                  // unexpected errors: log them
  }

  res.status(status).json({ status, error, message, timestamp: new Date().toISOString() });
}

module.exports = { notFound, handleErrors };