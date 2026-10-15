// CONCURRENCY TEST: two officers try to call the SAME ticket at the same time.
// Usage (with the server running):  node scripts/concurrency-test.js
const API = 'http://localhost:3000/api/turnos';

async function request(method, url, body) {
  const response = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() };
}

async function main() {
  // 1. Create a new ticket to fight over.
  const created = await request('POST', API, { nombre: 'Prueba Concurrencia', tramite: 'CAJA' });
  const id = created.body.id;
  console.log(`Turno creado: id ${id}, número ${created.body.numero}\n`);

  // 2. Fire BOTH requests at the same time (Promise.all does not wait for the first one).
  const [camila, darlin] = await Promise.all([
    request('PATCH', `${API}/${id}`, { estado: 'LLAMADO', funcionario: 'Camila' }),
    request('PATCH', `${API}/${id}`, { estado: 'LLAMADO', funcionario: 'Darlin' }),
  ]);

  console.log(`Camila -> ${camila.status}`, camila.body.message || `ganó (${camila.body.funcionario})`);
  console.log(`Darlin -> ${darlin.status}`, darlin.body.message || `ganó (${darlin.body.funcionario})`);

  const winners = [camila, darlin].filter((r) => r.status === 200).length;
  console.log(winners === 1 ? '\n✔ Solo una persona llamó el turno.' : `\n✘ Ganaron ${winners}: hay un problema.`);
}

main().catch((error) => console.error('¿Está corriendo el servidor?', error.message));