const db = require('../config/db');

// Filtro SQL: los vehículos del yonque al que pertenece el usuario (membresía activa).
// Uso: `WHERE v.yonque_id IN (${SQL_YONQUES_DEL_USUARIO})` con el usuario como $1.
const SQL_YONQUES_DEL_USUARIO =
  `SELECT m.yonque_id FROM miembros_yonque m WHERE m.usuario_id = $1 AND m.activo`;

// Pieza solo si el usuario es miembro activo del yonque de su vehículo.
// Devuelve null si no existe o no es del usuario (no revela cuál de los dos casos es).
async function piezaDelUsuario(client, userId, piezaId) {
  const q = client ? client.query.bind(client) : db.query;
  const { rows } = await q(
    `SELECT p.*, v.yonque_id, v.marca_texto, v.modelo_texto, v.anio
       FROM piezas p
       JOIN vehiculos v ON v.id = p.vehiculo_id
       JOIN miembros_yonque m ON m.yonque_id = v.yonque_id
                             AND m.usuario_id = $1 AND m.activo
      WHERE p.id = $2`,
    [userId, piezaId]
  );
  return rows[0] || null;
}

// Vehículo solo si el usuario es miembro activo de su yonque.
async function vehiculoDelUsuario(userId, vehiculoId) {
  const { rows } = await db.query(
    `SELECT v.* FROM vehiculos v
       JOIN miembros_yonque m ON m.yonque_id = v.yonque_id
                             AND m.usuario_id = $1 AND m.activo
      WHERE v.id = $2`,
    [userId, vehiculoId]
  );
  return rows[0] || null;
}

// Yonque activo del usuario. Si pertenece a varios, toma el más antiguo.
// (El selector de yonque queda para después; ver plan de la app.)
async function yonqueDelUsuario(client, userId) {
  const q = client ? client.query.bind(client) : db.query;
  const { rows } = await q(
    `SELECT y.id FROM yonques y
       JOIN miembros_yonque m ON m.yonque_id = y.id AND m.usuario_id = $1 AND m.activo
      ORDER BY y.fecha_creacion LIMIT 1`,
    [userId]
  );
  return rows[0] ? rows[0].id : null;
}

module.exports = {
  SQL_YONQUES_DEL_USUARIO,
  piezaDelUsuario,
  vehiculoDelUsuario,
  yonqueDelUsuario,
};
