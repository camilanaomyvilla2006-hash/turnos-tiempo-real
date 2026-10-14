// A "controlled" application error: it carries the HTTP status and a
// readable error code, so the API can answer with a consistent structure.
class AppError extends Error {
  constructor(status, error, message) {
    super(message);
    this.status = status;   // 400, 404, 409...
    this.error = error;     // 'VALIDATION_ERROR', 'NOT_FOUND'...
  }
}

module.exports = AppError;