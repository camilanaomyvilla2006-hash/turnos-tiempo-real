# Sistema de gestión de turnos en tiempo real

**IF0009 · Desarrollo de Software IV · Examen parcial I · Parte práctica**
Universidad de Costa Rica · Sede del Sur

| Integrante | Responsabilidad principal |
| --- | --- |
| Camila | Base de datos MySQL, API REST, control de concurrencia y servidor WebSocket |
| Darlin | Frontend Flutter Web, manejo de estado con Cubit y cliente WebSocket con reconexión |

Aplicación web donde varios funcionarios ven la misma lista de turnos al mismo tiempo. Cuando uno registra, llama o atiende un turno, **todos los navegadores conectados se actualizan sin recargar**. Si dos funcionarios intentan llamar el mismo turno a la vez, **el backend garantiza que solo uno lo logre**.

---

## 1. Requerimientos y cómo se cumplen

| # | Requerimiento | Solución |
| --- | --- | --- |
| 1 | Registrar turnos con consecutivo asignado por el sistema | `POST /api/turnos`. El número sale de la tabla `contador_turnos`, dentro de una transacción con `SELECT ... FOR UPDATE`. Si el cliente envía un número, se ignora. |
| 2 | Consultar pendientes, llamados y atendidos | `GET /api/turnos?estado=...` y tres columnas en Flutter. |
| 3 | Llamar al siguiente turno disponible | `POST /api/turnos/llamar-siguiente`: toma el pendiente con el número más bajo y reintenta si otro funcionario se lo lleva. |
| 4 | Reflejar cambios en todos los clientes | El servidor envía `TURNO_CREADO` y `TURNO_ACTUALIZADO` por WebSocket a todos los navegadores conectados. |
| 5 | Impedir que dos funcionarios llamen el mismo turno | Concurrencia optimista: `UPDATE ... WHERE estado = ? AND version = ?`. Solo uno gana; el otro recibe HTTP 409. |
| 6 | Historial de atendidos con fecha y hora | Columnas `llamado_en` y `atendido_en`, y tabla `historial_turnos` con cada cambio de estado, funcionario y fecha. |

---

## 2. Arquitectura

```
 Navegador A (Flutter Web)        Navegador B (Flutter Web)
        │   ▲                             │   ▲
   HTTP │   │ WebSocket              HTTP │   │ WebSocket
        ▼   │                             ▼   │
 ┌─────────────────────── Backend Node.js (puerto 3000) ─────────────────────┐
 │  Routes → Controller → Service (reglas de negocio) → Repository (SQL)     │
 │                            │                                             │
 │                            └── notifica ──► Servidor WebSocket (/ws)     │
 └──────────────────────────────────────┬────────────────────────────────────┘
                                        ▼
                                MySQL (turnos_db)
```

**Idea central:** las **acciones** (registrar, llamar, atender) viajan por **HTTP**, porque necesitan una respuesta con código de estado. Los **avisos** a los demás navegadores viajan por **WebSocket**, porque el servidor necesita hablar sin que le pregunten.

**Backend, separado en capas:**
- **Controller:** recibe la solicitud HTTP y responde con el código correcto. No tiene reglas.
- **Service:** reglas de negocio y validaciones (trámites y estados permitidos, transiciones, concurrencia). Después de guardar, notifica por WebSocket.
- **Repository:** única capa que habla con MySQL. Usa transacciones.

**Frontend:**
- **ApiService:** única parte que hace solicitudes HTTP.
- **SocketService:** mantiene la conexión WebSocket y se reconecta sola.
- **TicketsCubit:** maneja el estado. La pantalla solo muestra el estado y avisa las acciones del usuario.

---

## 3. Tecnologías

| Parte | Tecnología |
| --- | --- |
| Frontend | Flutter Web (Dart), `flutter_bloc` (Cubit), `http`, `web_socket_channel` |
| Backend | Node.js con Express 5, `ws`, `mysql2`, `dotenv`, `cors` |
| Base de datos | MySQL 8 (MySQL Workbench) |
| Control de versiones | Git y GitHub, con ramas `backend` y `frontend` integradas en `main` |

---

## 4. Instalación y ejecución

### Requisitos
- MySQL 8 y MySQL Workbench
- Node.js 18 o superior
- Flutter 3.22 o superior, con Chrome

### Paso 1 · Base de datos
1. Abrir MySQL Workbench con el usuario `root`.
2. **File → Open SQL Script** → `database/schema.sql`.
3. Ejecutar todo el script con **Ctrl + Shift + Enter**.

El script crea la base `turnos_db`, sus tres tablas y el usuario `turnos_app`, que es el que usa la API (principio de mínimo privilegio: no se conecta como `root`).

> ⚠️ El script empieza con `DROP DATABASE IF EXISTS`: ejecutarlo de nuevo borra todos los turnos.

### Paso 2 · Backend
```bash
cd backend
npm install
```
Crear el archivo `backend/.env` a partir de `backend/.env.example`:
```
PORT=3000
DB_HOST=localhost
DB_PORT=3306
DB_USER=turnos_app
DB_PASSWORD=Turnos2026!
DB_NAME=turnos_db
```
Iniciar:
```bash
npm run dev
```
Debe mostrar:
```
API REST:  http://localhost:3000/api/turnos
WebSocket: ws://localhost:3000/ws
```
El archivo `.env` no se sube a Git porque contiene la contraseña.

### Paso 3 · Frontend
En otra terminal:
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

### Paso 4 · Probar con dos navegadores
Copiar la dirección de la app (por ejemplo `http://localhost:52712`) y abrirla también en una ventana de incógnito o en otro navegador. Usar un nombre de funcionario distinto en cada una.

---

## 5. API REST

Base: `http://localhost:3000/api`

| Método | Ruta | Propósito | Respuestas |
| --- | --- | --- | --- |
| GET | `/turnos` | Listar turnos | 200 |
| GET | `/turnos?estado=PENDIENTE` | Filtrar por estado | 200, 400 |
| GET | `/turnos/:id` | Consultar un turno | 200, 400, 404 |
| POST | `/turnos` | Crear turno y asignar consecutivo | 201, 400 |
| PATCH | `/turnos/:id` | Cambiar estado (llamar o atender) | 200, 400, 404, 409 |
| POST | `/turnos/llamar-siguiente` | Llamar el siguiente pendiente | 200, 400, 404, 409 |

**Reglas de negocio**
- Todo turno nuevo inicia en `PENDIENTE`.
- Nombre obligatorio, de 3 a 80 caracteres. Funcionario de 3 a 60.
- Trámite: solo `CAJA`, `CONSULTA` o `TRAMITES`.
- Transiciones válidas: `PENDIENTE → LLAMADO → ATENDIDO`. Un turno atendido no regresa.
- El backend valida todo aunque Flutter ya haya validado, porque alguien podría enviar la solicitud sin usar la app.

**Errores:** siempre con la misma estructura.
```json
{ "status": 409, "error": "CONFLICTO_CONCURRENCIA", "message": "Otro funcionario modificó este turno al mismo tiempo. Intente de nuevo.", "timestamp": "..." }
```
- **400:** dato inválido (un trámite que no existe, un nombre vacío, un id no numérico).
- **404:** el turno no existe, o no hay pendientes.
- **409:** dato válido que choca con la situación actual (transición no permitida o conflicto de concurrencia).

**Mensajes WebSocket** (`ws://localhost:3000/ws`)

| Dirección | `tipo` | Cuándo |
| --- | --- | --- |
| Servidor → cliente | `SNAPSHOT` | Al conectarse o reconectarse, y cuando el cliente pide `SYNC` |
| Servidor → todos | `TURNO_CREADO` | Después de registrar un turno |
| Servidor → todos | `TURNO_ACTUALIZADO` | Después de llamar o atender |
| Cliente → servidor | `SYNC` | El cliente pide el estado real, por ejemplo tras un 409 |

---

## 6. Base de datos

| Tabla | Para qué |
| --- | --- |
| `contador_turnos` | Una fila con el último número entregado (como el dispensador de tiquetes) |
| `turnos` | Un registro por turno: número único, nombre, trámite, estado, funcionario, `version` y fechas |
| `historial_turnos` | Cada cambio de estado con fecha y funcionario. Relación 1:N con `turnos` mediante llave foránea |

---

## 7. Investigación

### 7.1 HTTP vs WebSockets

| | HTTP | WebSocket |
| --- | --- | --- |
| Conexión | Se abre por cada solicitud y se cierra con la respuesta | Queda abierta |
| Quién inicia | Siempre el cliente | Cualquiera de los dos, en cualquier momento (bidireccional) |
| Para enterarse de un cambio | El cliente debe volver a preguntar (*polling*) | El servidor avisa apenas ocurre |
| Uso en este proyecto | Acciones: crear, llamar, atender | Avisos en tiempo real a todos los navegadores |

Una conexión WebSocket empieza como una solicitud HTTP con el encabezado `Upgrade: websocket`; si el servidor acepta (código `101 Switching Protocols`), esa misma conexión se vuelve un canal bidireccional (RFC 6455).

**Por qué no *polling*:** con 10 funcionarios consultando cada 2 segundos serían 300 solicitudes por minuto, aunque no haya cambios, y los cambios se verían con retraso. Con WebSocket, el servidor solo envía mensajes cuando algo cambia, y llegan al instante.

### 7.2 Eventos entre Flutter y el backend

1. Al abrir la app, `SocketService` se conecta a `/ws` y el servidor responde con un `SNAPSHOT`: la lista completa de turnos desde MySQL.
2. El funcionario A presiona **Llamar**. El Cubit envía un `PATCH` por HTTP.
3. El backend actualiza MySQL y, después de confirmar, envía `TURNO_ACTUALIZADO` a todos los sockets conectados.
4. En el navegador B, `SocketService` convierte el mensaje en un objeto `Ticket` con `fromJson` y se lo pasa al Cubit.
5. El Cubit compara la `version`: solo aplica el turno si es más nuevo que el que tiene. Emite un estado nuevo y Flutter redibuja la pantalla.

**Mensajes desordenados:** el mismo cambio puede llegar dos veces (por la respuesta HTTP y por el WebSocket), o un aviso viejo puede llegar tarde. Como el Cubit solo aplica versiones mayores, la pantalla nunca retrocede a datos viejos.

### 7.3 Desconexión, reconexión y sincronización

- **Detección:** si el canal se cierra o falla, `SocketService` lo detecta y la app muestra una barra roja: *"Sin conexión en tiempo real. Reconectando..."*.
- **Reintento con espera creciente (*backoff* exponencial):** 1 s, 2 s, 4 s, 8 s y luego cada 15 s como máximo, para no saturar el servidor mientras está caído.
- **Recuperación del estado real:** al reconectarse, el servidor envía un `SNAPSHOT` nuevo. Así el navegador recupera lo que hicieron otros funcionarios mientras estuvo desconectado. MySQL es la fuente de verdad.
- **Sincronización tras un conflicto:** si una acción recibe 409, el Cubit pide `SYNC` y recibe el estado real.
- **Conexiones muertas (*heartbeat*):** cada 30 s el servidor envía un `ping`; si un cliente no respondió el anterior, se cierra su conexión.

### 7.4 Control de concurrencia

**Problema:** si el servidor hiciera "leer → revisar → guardar" en pasos separados, dos funcionarios que llaman el mismo turno al mismo tiempo leerían ambos `PENDIENTE` y los dos lo llamarían (condición de carrera).

**Solución: concurrencia optimista.** El cambio se hace en una sola sentencia atómica que revisa y escribe a la vez:
```sql
UPDATE turnos
   SET estado = 'LLAMADO', funcionario = ?, version = version + 1, llamado_en = NOW()
 WHERE id = ? AND estado = 'PENDIENTE' AND version = ?;
```
InnoDB bloquea la fila durante el `UPDATE`. El primero la cambia y aumenta la versión; el segundo ya no encuentra una fila con esa versión (`affectedRows = 0`) y el backend responde **409**, sin enviar ningún aviso.

El Service tiene dos defensas:
1. **Revisión de la transición:** atrapa a quien llega **después** de que otro ya guardó → `409 TRANSICION_INVALIDA`.
2. **`UPDATE` condicional:** atrapa a quien llega **al mismo tiempo** → `409 CONFLICTO_CONCURRENCIA`.

**Por qué optimista y no pesimista:** los choques son poco frecuentes, así que no vale la pena bloquear la fila desde que se lee. Además, la `version` sirve en el frontend para descartar avisos viejos.

**Llamar siguiente:** si varios funcionarios presionan el botón a la vez, el que pierde la carrera **reintenta** con el siguiente pendiente, así cada uno recibe un turno distinto sin ver errores.

**Consecutivo:** al crear un turno, `SELECT valor FROM contador_turnos ... FOR UPDATE` bloquea la fila del contador hasta el `COMMIT`. Si dos registros llegan juntos, el segundo espera. Además, `numero` es `UNIQUE`.

---

## 8. Evidencia y pruebas

- `backend/scripts/concurrency-test.js`: dos funcionarios llaman el mismo turno al mismo tiempo; siempre gana uno solo.
- `backend/scripts/call-next-test.js`: tres funcionarios presionan "Llamar siguiente" a la vez; cada uno recibe un turno distinto.

Con el backend corriendo:
```bash
cd backend
node scripts/concurrency-test.js
node scripts/call-next-test.js
```

Capturas en la carpeta `docs/evidencia/`.
