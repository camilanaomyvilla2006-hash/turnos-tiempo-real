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

const PORT = Number(process.env.PORT || 3000);
app.listen(PORT, () => {
  console.log(`API listening on http://localhost:${PORT}/api/turnos`);
});