// ENTRY POINT: puts all the pieces together and starts the server.
//   Flutter --HTTP--> routes -> controller -> service -> repository -> MySQL
//      ^                                  |
//      +-------- WebSocket <--------------+  (notify every client)
require('dotenv').config();
const http = require('http');
const express = require('express');
const cors = require('cors');

const ticketsRouter = require('./routes/tickets.routes');
const { notFound, handleErrors } = require('./middlewares/errorHandler');
const realtime = require('./websocket/socket');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/turnos', ticketsRouter);
app.use(notFound);
app.use(handleErrors);

// Express and WebSocket share the same HTTP server and port.
const server = http.createServer(app);
realtime.attach(server);

const PORT = Number(process.env.PORT || 3000);
server.listen(PORT, () => {
  console.log(`API REST:  http://localhost:${PORT}/api/turnos`);
  console.log(`WebSocket: ws://localhost:${PORT}/ws`);
});