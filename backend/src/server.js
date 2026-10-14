require('dotenv').config(); // loads the variables from the .env file
const express = require('express');
const cors = require('cors');
const pool = require('./config/db');

const app = express();
app.use(cors());         // lets Flutter (running on another port) call the API
app.use(express.json()); // parses JSON request bodies

// GET /api/turnos -> list all tickets
app.get('/api/turnos', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM turnos ORDER BY numero');
  res.json(rows);
});

// POST /api/turnos -> create a ticket with a number assigned by the system
app.post('/api/turnos', async (req, res) => {
  const { nombre, tramite } = req.body;

  // A transaction needs ONE connection from the pool for all its steps.
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    // 1. Read the counter and LOCK its row (FOR UPDATE).
    //    If two requests arrive at the same time, the second one waits here.
    const [[counter]] = await connection.query(
      'SELECT valor FROM contador_turnos WHERE id = 1 FOR UPDATE',
    );
    const number = counter.valor + 1;
    await connection.query('UPDATE contador_turnos SET valor = ? WHERE id = 1', [number]);

    // 2. Insert the ticket with that number.
    const [result] = await connection.query(
      'INSERT INTO turnos (numero, nombre, tramite) VALUES (?, ?, ?)',
      [number, nombre, tramite],
    );

    // 3. Save the first history record.
    await connection.query(
      "INSERT INTO historial_turnos (turno_id, estado_anterior, estado_nuevo) VALUES (?, NULL, 'PENDIENTE')",
      [result.insertId],
    );

    await connection.commit(); // everything worked: save all the changes

    const [[ticket]] = await connection.query('SELECT * FROM turnos WHERE id = ?', [result.insertId]);
    res.status(201).json(ticket); // 201 = resource created
  } catch (error) {
    await connection.rollback(); // something failed: undo everything
    res.status(500).json({ message: error.message });
  } finally {
    connection.release(); // return the connection to the pool
  }
});

const PORT = Number(process.env.PORT || 3000);
app.listen(PORT, () => {
  console.log(`API listening on http://localhost:${PORT}/api/turnos`);
});