// REPOSITORY: the only layer that talks to MySQL.
// It saves, finds and updates data. It does NOT decide business rules.
const pool = require('../config/db');

// List tickets, optionally filtered by status, ordered by number.
async function findAll(status) {
  if (status) {
    const [rows] = await pool.query('SELECT * FROM turnos WHERE estado = ? ORDER BY numero', [status]);
    return rows;
  }
  const [rows] = await pool.query('SELECT * FROM turnos ORDER BY numero');
  return rows;
}

async function findById(id) {
  const [rows] = await pool.query('SELECT * FROM turnos WHERE id = ?', [id]);
  return rows[0] || null; // null if it does not exist
}

// Create a ticket with a consecutive number (the transaction we already tested).
async function create({ name, procedure }) {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const [[counter]] = await connection.query(
      'SELECT valor FROM contador_turnos WHERE id = 1 FOR UPDATE',
    );
    const number = counter.valor + 1;
    await connection.query('UPDATE contador_turnos SET valor = ? WHERE id = 1', [number]);

    const [result] = await connection.query(
      'INSERT INTO turnos (numero, nombre, tramite) VALUES (?, ?, ?)',
      [number, name, procedure],
    );

    await connection.query(
      "INSERT INTO historial_turnos (turno_id, estado_anterior, estado_nuevo) VALUES (?, NULL, 'PENDIENTE')",
      [result.insertId],
    );

    await connection.commit();
    return findById(result.insertId);
  } catch (error) {
    await connection.rollback();
    throw error; // let the upper layers decide what to answer
  } finally {
    connection.release();
  }
}

// Change the status with OPTIMISTIC CONCURRENCY CONTROL.
// The UPDATE only applies if the ticket is still in the status AND version we read.
// If someone changed it first, affectedRows is 0 and we return null.
async function updateStatus({ id, currentStatus, currentVersion, newStatus, officer }) {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const [result] = await connection.query(
      `UPDATE turnos
          SET estado      = ?,
              funcionario = ?,
              version     = version + 1,
              llamado_en  = IF(? = 'LLAMADO',  NOW(), llamado_en),
              atendido_en = IF(? = 'ATENDIDO', NOW(), atendido_en)
        WHERE id = ? AND estado = ? AND version = ?`,
      [newStatus, officer, newStatus, newStatus, id, currentStatus, currentVersion],
    );

    if (result.affectedRows === 0) {
      await connection.rollback();
      return null; // someone else won the race
    }

    await connection.query(
      'INSERT INTO historial_turnos (turno_id, estado_anterior, estado_nuevo, funcionario) VALUES (?, ?, ?, ?)',
      [id, currentStatus, newStatus, officer],
    );

    await connection.commit();
    return findById(id);
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

// The first PENDING ticket (the one with the lowest number).
async function findFirstPending() {
  const [rows] = await pool.query(
    "SELECT * FROM turnos WHERE estado = 'PENDIENTE' ORDER BY numero LIMIT 1",
  );
  return rows[0] || null;
}

module.exports = { findAll, findById, findFirstPending, create, updateStatus };