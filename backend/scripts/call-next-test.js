// CONCURRENCY TEST: three officers press "Llamar siguiente" at the same time.
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
  for (const name of ['Persona Uno', 'Persona Dos', 'Persona Tres']) {
    await request('POST', API, { nombre: name, tramite: 'CAJA' });
  }

  const officers = ['Camila', 'Darlin', 'Laura'];
  const results = await Promise.all(
    officers.map((officer) => request('POST', `${API}/llamar-siguiente`, { funcionario: officer })),
  );

  results.forEach((r, i) => {
    const detail = r.status === 200 ? `turno ${r.body.numero} (${r.body.nombre})` : r.body.message;
    console.log(`${officers[i]} -> ${r.status} ${detail}`);
  });

  const numbers = results.filter((r) => r.status === 200).map((r) => r.body.numero);
  const allSucceeded = numbers.length === officers.length;
  const allDifferent = new Set(numbers).size === numbers.length;
  console.log(allSucceeded && allDifferent
    ? '\n✔ Cada funcionario recibió un turno distinto.'
    : `\n✘ Algo falló: ${numbers.length} de ${officers.length} lograron llamar un turno.`);
} // <- this brace closes main()

main().catch((error) => console.error('¿Está corriendo el servidor?', error.message));