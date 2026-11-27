const db = require('../config/db');
const { SQL_YONQUES_DEL_USUARIO, yonqueDelUsuario, vehiculoDelUsuario } = require('../utils/acceso');
const { withUser } = require('../utils/tx');
const httpError = require('../utils/pgErrors');

const ANIO_MINIMO = 1960;
// Borradores que aún no están publicados ni descartados.
const BORRADORES_ABIERTOS = ['pendiente', 'en_edicion', 'listo_para_publicar'];

// GET /api/vehiculos → vehículos del yonque del usuario.
const getVehiculos = async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT v.id,
              COALESCE(mk.nombre, v.marca_texto) AS marca,
              COALESCE(mo.nombre, v.modelo_texto) AS modelo,
              v.anio, v.vin
         FROM vehiculos v
         LEFT JOIN marcas_vehiculo mk ON mk.id = v.marca_id
         LEFT JOIN modelos_vehiculo mo ON mo.id = v.modelo_id
        WHERE v.activo AND v.yonque_id IN (${SQL_YONQUES_DEL_USUARIO})
        ORDER BY v.fecha_registro DESC`,
      [req.user.id]
    );
    res.json(rows);
  } catch (error) {
    console.error('getVehiculos', error);
    res.status(500).json({ error: 'Error al obtener vehículos' });
  }
};

// POST /api/vehiculos  { modelo_id, anio }
// Llama a registrar_vehiculo_con_piezas: genera las piezas por confirmar desde la plantilla.
// No se envía numero_unidad (lo asigna un trigger).
const postVehiculo = async (req, res) => {
  try {
    const { modelo_id, anio } = req.body;
    if (!modelo_id) return res.status(400).json({ error: 'modelo_id es obligatorio' });

    const anioNum = parseInt(anio, 10);
    const anioMax = new Date().getFullYear() + 1;
    if (!Number.isInteger(anioNum) || anioNum < ANIO_MINIMO || anioNum > anioMax) {
      return res.status(400).json({ error: `El año debe estar entre ${ANIO_MINIMO} y ${anioMax}` });
    }

    const modelo = await db.query('SELECT id FROM modelos_vehiculo WHERE id = $1', [modelo_id]);
    if (!modelo.rows[0]) return res.status(400).json({ error: 'Modelo no encontrado en el catálogo' });

    const yonqueId = await yonqueDelUsuario(null, req.user.id);
    if (!yonqueId) return res.status(403).json({ error: 'Tu cuenta no está asociada a un yonque' });

    const resultado = await withUser(req.user.id, 'Registrar vehículo', async (client) => {
      const r = await client.query(
        `SELECT vehiculo_id, piezas_generadas
           FROM registrar_vehiculo_con_piezas($1, $2, NULL, NULL, $3, '{}'::jsonb, $4)`,
        [yonqueId, req.user.id, anioNum, modelo_id]
      );
      return r.rows[0];
    });

    res.status(201).json(resultado);
  } catch (error) {
    const [status, msg] = httpError(error);
    if (status === 500) console.error('postVehiculo', error);
    res.status(status).json({ error: msg });
  }
};

// DELETE /api/vehiculos/:id
// Baja lógica del vehículo y sus publicaciones, en una sola transacción:
// - publicaciones activas o pausadas de sus piezas → 'eliminada'
//   (las vendidas no se tocan: son historial de ventas)
// - borradores abiertos de sus piezas → 'descartado'
// - vehículo → activo = false (piezas y ventas se conservan)
const deleteVehiculo = async (req, res) => {
  try {
    const vehiculo = await vehiculoDelUsuario(req.user.id, req.params.id);
    if (!vehiculo || !vehiculo.activo) {
      return res.status(404).json({ error: 'Vehículo no encontrado' });
    }

    await withUser(req.user.id, 'Eliminar vehículo', async (client) => {
      await client.query(
        `UPDATE publicaciones
            SET estado = 'eliminada', fecha_eliminacion = now()
          WHERE estado IN ('activa', 'pausada')
            AND pieza_id IN (SELECT id FROM piezas WHERE vehiculo_id = $1)`,
        [req.params.id]
      );
      await client.query(
        `UPDATE borradores_publicacion
            SET estado = 'descartado',
                motivo_descarte = 'Vehículo eliminado del inventario',
                fecha_ultima_edicion = now()
          WHERE estado = ANY($2::text[])
            AND pieza_id IN (SELECT id FROM piezas WHERE vehiculo_id = $1)`,
        [req.params.id, BORRADORES_ABIERTOS]
      );
      await client.query(`UPDATE vehiculos SET activo = FALSE WHERE id = $1`, [req.params.id]);
    });

    res.json({ message: 'Vehículo eliminado' });
  } catch (error) {
    const [status, msg] = httpError(error);
    if (status === 500) console.error('deleteVehiculo', error);
    res.status(status).json({ error: msg });
  }
};

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// POST /api/vehiculos/:id/verificacion/confirmar  { piezas_ids?: [uuid] }
// Pasa a 'disponible' las piezas por confirmar del vehículo que tienen precio (> 0) y condición.
// Si se envía piezas_ids, solo se consideran esas (las aceptadas en la verificación).
// Las que no tienen precio o condición se quedan por confirmar.
const confirmarVerificacion = async (req, res) => {
  try {
    const vehiculo = await vehiculoDelUsuario(req.user.id, req.params.id);
    if (!vehiculo || !vehiculo.activo) {
      return res.status(404).json({ error: 'Vehículo no encontrado' });
    }

    const ids = req.body && req.body.piezas_ids !== undefined ? req.body.piezas_ids : null;
    if (ids !== null && (!Array.isArray(ids) || ids.some((i) => typeof i !== 'string' || !UUID_RE.test(i)))) {
      return res.status(400).json({ error: 'piezas_ids debe ser una lista de ids válidos' });
    }

    const resultado = await withUser(req.user.id, 'Confirmar verificación de vehículo', async (client) => {
      const { rows: candidatas } = await client.query(
        `SELECT id, precio_venta, condicion FROM piezas
          WHERE vehiculo_id = $1
            AND estado_inventario = 'por_confirmar'
            AND ($2::uuid[] IS NULL OR id = ANY($2::uuid[]))
          ORDER BY fecha_creacion
            FOR UPDATE`,
        [req.params.id, ids]
      );

      const confirmadas = [];
      const pendientes = [];
      for (const p of candidatas) {
        const listas = p.condicion && Number(p.precio_venta) > 0;
        if (!listas) {
          pendientes.push(p.id);
          continue;
        }
        await client.query(`SELECT cambiar_estado_pieza($1, 'disponible', $2, $3)`,
          [p.id, req.user.id, 'Confirmar verificación']);
        confirmadas.push(p.id);
      }

      const { rows: conteo } = await client.query(
        `SELECT estado_inventario AS estado, count(*)::int AS n
           FROM piezas WHERE vehiculo_id = $1 GROUP BY estado_inventario`,
        [req.params.id]
      );
      const porEstado = Object.fromEntries(conteo.map((r) => [r.estado, r.n]));

      return { confirmadas: confirmadas.length, pendientes, por_estado: porEstado };
    });

    res.json(resultado);
  } catch (error) {
    const [status, msg] = httpError(error);
    if (status === 500) console.error('confirmarVerificacion', error);
    res.status(status).json({ error: msg });
  }
};

module.exports = { getVehiculos, postVehiculo, deleteVehiculo, confirmarVerificacion };
