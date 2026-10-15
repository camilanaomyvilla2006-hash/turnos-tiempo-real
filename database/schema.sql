-- Sistema de gestión de turnos en tiempo real
-- Ejecutar completo en MySQL Workbench (Ctrl + Shift + Enter).
-- OJO: borra la base de datos si ya existe.

DROP DATABASE IF EXISTS turnos_db;
CREATE DATABASE turnos_db;
USE turnos_db;

-- Último número entregado (una sola fila, como el dispensador de tiquetes)
CREATE TABLE contador_turnos (
  id     TINYINT PRIMARY KEY,
  valor  INT NOT NULL
);
INSERT INTO contador_turnos (id, valor) VALUES (1, 0);

-- Un registro por turno
CREATE TABLE turnos (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  numero       INT NOT NULL UNIQUE,
  nombre       VARCHAR(80) NOT NULL,
  tramite      ENUM('CAJA', 'CONSULTA', 'TRAMITES') NOT NULL,
  estado       ENUM('PENDIENTE', 'LLAMADO', 'ATENDIDO') NOT NULL DEFAULT 'PENDIENTE',
  funcionario  VARCHAR(60) NULL,
  version      INT NOT NULL DEFAULT 1,      -- aumenta en cada cambio (control de concurrencia)
  creado_en    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  llamado_en   DATETIME NULL,
  atendido_en  DATETIME NULL
);

-- Bitácora de cambios de estado (un turno tiene muchos movimientos: 1 a N)
CREATE TABLE historial_turnos (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  turno_id         INT NOT NULL,
  estado_anterior  ENUM('PENDIENTE', 'LLAMADO', 'ATENDIDO') NULL,
  estado_nuevo     ENUM('PENDIENTE', 'LLAMADO', 'ATENDIDO') NOT NULL,
  funcionario      VARCHAR(60) NULL,
  fecha            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_historial_turno
    FOREIGN KEY (turno_id) REFERENCES turnos (id)
);

-- Usuario propio para la API (mínimo privilegio: solo datos de turnos_db).
-- La contraseña debe coincidir con la de backend/.env
CREATE USER IF NOT EXISTS 'turnos_app'@'localhost' IDENTIFIED BY 'Turnos2026!';
GRANT SELECT, INSERT, UPDATE, DELETE ON turnos_db.* TO 'turnos_app'@'localhost';
FLUSH PRIVILEGES;

-- Consultas útiles para revisar los datos:
-- SELECT * FROM turnos ORDER BY numero;
-- SELECT * FROM historial_turnos ORDER BY id;