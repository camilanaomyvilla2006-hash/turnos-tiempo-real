// WEBSOCKET SERVER: an open, two-way channel with every browser.
// HTTP is used for ACTIONS (create, call, attend).
// WebSocket is used to NOTIFY every client that something changed.
const { WebSocketServer, WebSocket } = require('ws');
const repository = require('../repositories/tickets.repository');

const HEARTBEAT_MS = 30000;
let wss = null;

function send(socket, message) {
  if (socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify(message));
  }
}

// SNAPSHOT = a full picture of the real state in MySQL.
// Sent when a client connects (or reconnects), so it recovers
// everything that happened while it was disconnected.
async function sendSnapshot(socket) {
  try {
    const tickets = await repository.findAll();
    send(socket, { tipo: 'SNAPSHOT', turnos: tickets });
  } catch (error) {
    console.error('Could not send the snapshot:', error.message);
    send(socket, { tipo: 'ERROR', mensaje: 'No se pudo cargar el estado actual' });
  }
}

// Attach the WebSocket server to the same HTTP server (same port as the API).
function attach(httpServer) {
  wss = new WebSocketServer({ server: httpServer, path: '/ws' });

  wss.on('connection', (socket) => {
    socket.isAlive = true;
    socket.on('pong', () => { socket.isAlive = true; });

    // The client can ask for a fresh snapshot: { "tipo": "SYNC" }
    socket.on('message', (data) => {
      try {
        const message = JSON.parse(data.toString());
        if (message.tipo === 'SYNC') sendSnapshot(socket);
      } catch {
        send(socket, { tipo: 'ERROR', mensaje: 'Mensaje no válido' });
      }
    });

    sendSnapshot(socket);
  });

  // HEARTBEAT: every 30 s send a ping. If a client did not answer the
  // previous one, its connection is dead and we close it.
  const heartbeat = setInterval(() => {
    wss.clients.forEach((socket) => {
      if (!socket.isAlive) return socket.terminate();
      socket.isAlive = false;
      socket.ping();
    });
  }, HEARTBEAT_MS);
  wss.on('close', () => clearInterval(heartbeat));
}

// Send an event to ALL connected browsers.
function broadcast(type, ticket) {
  if (!wss) return;
  const message = { tipo: type, turno: ticket };
  wss.clients.forEach((socket) => send(socket, message));
}

module.exports = { attach, broadcast };