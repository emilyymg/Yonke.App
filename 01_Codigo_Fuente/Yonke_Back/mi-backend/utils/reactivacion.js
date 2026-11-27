// Reglas para reactivar una publicación o un borrador descartado.
// Se ejecutan dentro de la transacción de withUser (cliente dedicado).

function conEstado(mensaje, status) {
  const e = new Error(mensaje);
  e.status = status;
  return e;
}

// Verifica que la pieza pueda volver a publicarse y restaura su vehículo si fue eliminado.
async function prepararReactivacionPieza(client, piezaId) {
  const { rows } = await client.query(
    `SELECT pz.estado_inventario, ve.id AS vehiculo_id, ve.activo AS vehiculo_activo
       FROM piezas pz
       JOIN vehiculos ve ON ve.id = pz.vehiculo_id
      WHERE pz.id = $1`,
    [piezaId]
  );
  const pieza = rows[0];
  if (!pieza) throw conEstado('Pieza no encontrada', 404);
  if (pieza.estado_inventario !== 'disponible') {
    throw conEstado('La pieza debe estar disponible para publicarse', 409);
  }

  const vigente = await client.query(
    `SELECT 1 FROM publicaciones
      WHERE pieza_id = $1 AND estado IN ('activa', 'pausada') LIMIT 1`,
    [piezaId]
  );
  if (vigente.rowCount) {
    throw conEstado('Esta pieza ya tiene una publicación activa o pausada', 409);
  }

  // Al eliminar el vehículo se eliminaron también sus publicaciones.
  // Al reactivar una de ellas, el vehículo vuelve al inventario.
  if (!pieza.vehiculo_activo) {
    try {
      await client.query('UPDATE vehiculos SET activo = TRUE WHERE id = $1', [pieza.vehiculo_id]);
    } catch (error) {
      if (error.code === '23505') {
        throw conEstado('Ya hay un vehículo activo con el mismo VIN', 409);
      }
      throw error;
    }
  }
}

module.exports = { conEstado, prepararReactivacionPieza };
