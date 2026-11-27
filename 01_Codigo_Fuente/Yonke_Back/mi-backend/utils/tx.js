const db = require('../config/db');

// Ejecuta `fn(client)` dentro de una transacción con el usuario y el motivo
// en la configuración de sesión. Los triggers de auditoría los leen de
// `app.usuario_id` y `app.motivo`. Con `db.query` suelto no sirve: cada query
// puede ir en una conexión distinta del pool.
async function withUser(userId, motivo, fn) {
  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `SELECT set_config('app.usuario_id', $1, true), set_config('app.motivo', $2, true)`,
      [userId, motivo || '']
    );
    const out = await fn(client);
    await client.query('COMMIT');
    return out;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

module.exports = { withUser };
