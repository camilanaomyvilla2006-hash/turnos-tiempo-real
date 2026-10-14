// ENTRY POINT: puts all the pieces together and starts the server.
//   Request -> routes -> controller -> service -> repository -> MySQL
require('dotenv').config();
const express = require('express');
const cors = require('cors');

const ticketsRouter = require('./routes/tickets.routes');
const { notFound, handleErrors } = require('./middlewares/errorHandler');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/turnos', ticketsRouter);

app.use(notFound);     // any route that does not exist
app.use(handleErrors); // any error thrown in the layers

const PORT = Number(process.env.PORT || 3000);
app.listen(PORT, () => {
  console.log(`API listening on http://localhost:${PORT}/api/turnos`);
});