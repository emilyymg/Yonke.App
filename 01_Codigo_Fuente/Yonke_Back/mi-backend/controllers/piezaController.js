const db = require('../config/db');
const { SQL_YONQUES_DEL_USUARIO, piezaDelUsuario, vehiculoDelUsuario } = require('../utils/acceso');
const { withUser } = require('../utils/tx');
const { fotoDTO } = require('../utils/s3');
const httpError = require('../utils/pgErrors');

const ESTADOS = ['por_confirmar', 'disponible', 'reservado', 'vendido', 'descartado', 'en_revision'];
const CONDICIONES = ['nuevo', 'seminuevo', 'usado', 'refaccionado', 'danado', 'para_reparar'];
// Destinos que la API puede pedir directamente. "vendido" solo lo hace procesar_venta.
const ESTADOS_DESTINO_API = ['disponible', 'reservado', 'descartado', 'en_revision'];

// Consulta de una pieza con sus fotos (todas: es vista del yonquero, no del marketplace).
const SQL_PIEZA = `
  SELECT p.id, p.vehiculo_id, p.codigo_sku AS sku, p.nombre, p.descripcion,
         p.condicion, p.precio_venta::float8 AS precio_venta,
         p.estado_inventario AS estado,
         (SELECT COALESCE(json_agg(json_build_object(
                   'id', f.id, 's3_key', f.s3_key,
                   'orden', f.orden, 'principal', f.es_principal)
                 ORDER BY f.es_principal DESC, f.orden), '[]'::json)
            FROM fotos f WHERE f.pieza_id = p.id) AS fotos
    FROM piezas p`;

function mapPieza(row) {
  const { fotos, ...p } = row;
  return { ...p, fotos: (fotos || []).map((f) => fotoDTO(f)) };
}

async function leerPieza(client, id) {
  const q = client ? client.query.bind(client) : db.query;
  const { rows } = await q(`${SQL_PIEZA} WHERE p.id = $1`, [id]);
  return rows[0] ? mapPieza(rows[0]) : null;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Error con código HTTP para lanzar dentro de withUser.
function conEstado(mensaje, status) {
  const e = new Error(mensaje);
  e.status = status;
  return e;
}

// GET /api/piezas?estado=&sku=&vehiculo_id=  → piezas del yonque del usuario.
// Con vehiculo_id, las piezas salen en el orden del catálogo (prioridad, nombre),
// que es el orden en que se recorren en la verificación.
const getPiezas = async (req, res) => {
  try {
    const estado = req.query.estado || null;
    const sku = req.query.sku ? String(req.query.sku).trim() : null;
    const vehiculoId = req.query.vehiculo_id ? String(req.query.vehiculo_id) : null;
    if (estado && !ESTADOS.includes(estado)) {
      return res.status(400).json({ error: 'Estado de pieza no válido' });
    }
    if (vehiculoId && !UUID_RE.test(vehiculoId)) {
      return res.status(400).json({ error: 'vehiculo_id no válido' });
    }

    const orden = vehiculoId
      ? 'COALESCE(cat.prioridad, 1000), p.nombre'
      : 'p.fecha_creacion DESC';

    const { rows } = await db.query(
      `${SQL_PIEZA}
         JOIN vehiculos v ON v.id = p.vehiculo_id
         LEFT JOIN piezas_catalogo cat ON cat.id = p.catalogo_pieza_id
        WHERE v.activo
          AND v.yonque_id IN (${SQL_YONQUES_DEL_USUARIO})
          AND ($2::text IS NULL OR p.estado_inventario = $2)
          AND ($3::text IS NULL OR upper(p.codigo_sku) = upper($3))
          AND ($4::uuid IS NULL OR p.vehiculo_id = $4::uuid)
        ORDER BY ${orden}`,
      [req.user.id, estado, sku, vehiculoId]
    );
    res.json(rows.map(mapPieza));
  } catch (error) {
    console.error('getPiezas', error);
    res.status(500).json({ error: 'Error al obtener piezas' });
  }
};

// GET /api/piezas/:id
const getPiezaById = async (req, res) => {
  try {
    const autorizada = await piezaDelUsuario(null, req.user.id, req.params.id);
    if (!autorizada) return res.status(404).json({ error: 'Pieza no encontrada' });

    res.json(await leerPieza(null, req.params.id));
  } catch (error) {
    console.error('getPiezaById', error);
    res.status(500).json({ error: 'Error al obtener la pieza' });
  }
};

// POST /api/piezas  { vehiculo_id, nombre, descripcion?, condicion?, precio_venta? }
// Pieza manual. No se envía codigo_sku: lo asigna la base.
const createPieza = async (req, res) => {
  try {
    const { vehiculo_id, nombre, descripcion, condicion, precio_venta } = req.body;
    if (!vehiculo_id || !nombre) {
      return res.status(400).json({ error: 'vehiculo_id y nombre son obligatorios' });
    }
    if (condicion && !CONDICIONES.includes(condicion)) {
      return res.status(400).json({ error: 'Condición no válida' });
    }
    if (precio_venta !== undefined && precio_venta !== null && !(Number(precio_venta) >= 0)) {
      return res.status(400).json({ error: 'El precio no puede ser negativo' });
    }

    const vehiculo = await vehiculoDelUsuario(req.user.id, vehiculo_id);
    if (!vehiculo) return res.status(404).json({ error: 'Vehículo no encontrado' });

    const id = await withUser(req.user.id, 'Pieza manual', async (client) => {
      const r = await client.query(
        `INSERT INTO piezas (vehiculo_id, nombre, descripcion, condicion, precio_venta, origen)
         VALUES ($1, $2, $3, $4, $5, 'manual')
         RETURNING id`,
        [vehiculo_id, nombre, descripcion || null, condicion || null,
         precio_venta ?? null]
      );
      return r.rows[0].id;
    });

    res.status(201).json(await leerPieza(null, id));
  } catch (error) {
    const [status, msg] = httpError(error);
    if (status === 500) console.error('createPieza', error);
    res.status(status).json({ error: msg });
  }
};

// POST /api/piezas/:id/confirmar  { precio_venta, condicion }
// Captura precio y condición y deja la pieza en disponible (por_confirmar → disponible).
const confirmarPieza = async (req, res) => {
  try {
    const { precio_venta, condicion } = req.body;
    if (!(Number(precio_venta) > 0)) {
      return res.status(400).json({ error: 'El precio debe ser mayor a cero' });
    }
    if (!CONDICIONES.includes(condicion)) {
      return res.status(400).json({ error: 'Condición no válida' });
    }

    const id = req.params.id;
    await withUser(req.user.id, 'Confirmar pieza', async (client) => {
      const autorizada = await piezaDelUsuario(client, req.user.id, id);
      if (!autorizada) {
        const e = new Error('Pieza no encontrada'); e.status = 404; throw e;
      }
      await client.query(
        `UPDATE piezas SET precio_venta = $1, condicion = $2, fecha_actualizacion = now() WHERE id = $3`,
        [precio_venta, condicion, id]
      );
      await client.query(`SELECT cambiar_estado_pieza($1, 'disponible', $2, 'Confirmar pieza')`, [id, req.user.id]);
    });

    res.json(await leerPieza(null, id));
  } catch (error) {
    if (error.status) return res.status(error.status).json({ error: error.message });
    const [status, msg] = httpError(error);
    if (status === 500) console.error('confirmarPieza', error);
    res.status(status).json({ error: msg });
  }
};

// POST /api/piezas/:id/estado  { estado, motivo? }
// Cambios directos: disponible, reservado, en_revision, descartado. Vender va por /api/ventas.
const cambiarEstadoPieza = async (req, res) => {
  try {
    const { estado, motivo } = req.body;
    if (!ESTADOS_DESTINO_API.includes(estado)) {
      return res.status(400).json({ error: 'Estado de destino no permitido por esta ruta' });
    }

    const id = req.params.id;
    await withUser(req.user.id, motivo || `Cambio a ${estado}`, async (client) => {
      const autorizada = await piezaDelUsuario(client, req.user.id, id);
      if (!autorizada) {
        const e = new Error('Pieza no encontrada'); e.status = 404; throw e;
      }
      await client.query(`SELECT cambiar_estado_pieza($1, $2, $3, $4)`, [id, estado, req.user.id, motivo || null]);
    });

    res.json(await leerPieza(null, id));
  } catch (error) {
    if (error.status) return res.status(error.status).json({ error: error.message });
    const [status, msg] = httpError(error);
    if (status === 500) console.error('cambiarEstadoPieza', error);
    res.status(status).json({ error: msg });
  }
};

// PATCH /api/piezas/:id  { nombre?, descripcion?, condicion?, precio_venta? }
// Edita las características de la pieza. Una pieza vendida no se edita.
const updatePieza = async (req, res) => {
  try {
    const { nombre, descripcion, condicion, precio_venta } = req.body || {};

    if (nombre !== undefined && !String(nombre).trim()) {
      return res.status(400).json({ error: 'El nombre no puede estar vacío' });
    }
    if (condicion !== undefined && condicion !== null && !CONDICIONES.includes(condicion)) {
      return res.status(400).json({ error: 'Condición no válida' });
    }
    if (precio_venta !== undefined && precio_venta !== null && !(Number(precio_venta) >= 0)) {
      return res.status(400).json({ error: 'El precio no puede ser negativo' });
    }

    // Solo columnas enviadas; los valores van como parámetros.
    const sets = [];
    const params = [];
    const agregar = (columna, valor) => {
      params.push(valor);
      sets.push(`${columna} = $${params.length}`);
    };
    if (nombre !== undefined) agregar('nombre', String(nombre).trim());
    if (descripcion !== undefined) agregar('descripcion', descripcion || null);
    if (condicion !== undefined) agregar('condicion', condicion);
    if (precio_venta !== undefined) agregar('precio_venta', precio_venta === null ? null : Number(precio_venta));
    if (!sets.length) return res.status(400).json({ error: 'No hay campos para actualizar' });

    const id = req.params.id;
    await withUser(req.user.id, 'Editar pieza', async (client) => {
      const actual = await piezaDelUsuario(client, req.user.id, id);
      if (!actual) throw conEstado('Pieza no encontrada', 404);
      if (actual.estado_inventario === 'vendido') {
        throw conEstado('Una pieza vendida no se puede editar', 409);
      }

      params.push(id);
      await client.query(
        `UPDATE piezas SET ${sets.join(', ')}, fecha_actualizacion = now() WHERE id = $${params.length}`,
        params
      );
    });

    res.json(await leerPieza(null, id));
  } catch (error) {
    if (error.status) return res.status(error.status).json({ error: error.message });
    const [status, msg] = httpError(error);
    if (status === 500) console.error('updatePieza', error);
    res.status(status).json({ error: msg });
  }
};

// POST /api/piezas/:id/descartar  { motivo? }
// Solo para piezas por confirmar: "esta pieza no existe en este vehículo".
// Sin fotos, borradores, publicaciones ni ventas, la pieza se borra (queda en historial).
// Si tiene alguno de esos registros, pasa a 'descartado' para conservar el historial.
const descartarPieza = async (req, res) => {
  try {
    const id = req.params.id;
    const motivo = (req.body && req.body.motivo) || 'Pieza no existe en el vehículo';

    const resultado = await withUser(req.user.id, motivo, async (client) => {
      const actual = await piezaDelUsuario(client, req.user.id, id);
      if (!actual) throw conEstado('Pieza no encontrada', 404);
      if (actual.estado_inventario !== 'por_confirmar') {
        throw conEstado('Solo se pueden descartar piezas por confirmar', 409);
      }

      const { rows } = await client.query(
        `SELECT (SELECT count(*) FROM fotos WHERE pieza_id = $1)
              + (SELECT count(*) FROM borradores_publicacion WHERE pieza_id = $1)
              + (SELECT count(*) FROM publicaciones WHERE pieza_id = $1)
              + (SELECT count(*) FROM ventas WHERE pieza_id = $1) AS n`,
        [id]
      );

      if (Number(rows[0].n) === 0) {
        // trg_auditar_piezas solo corre en UPDATE, así que el borrado se registra a mano.
        await client.query(
          `INSERT INTO historial_movimientos
             (tabla_afectada, registro_id, tipo_movimiento, datos_anteriores, usuario_id, descripcion)
           VALUES ('piezas', $1, 'DELETE', $2::jsonb, $3, $4)`,
          [id,
           JSON.stringify({ nombre: actual.nombre, vehiculo_id: actual.vehiculo_id,
                            estado_inventario: actual.estado_inventario, origen: actual.origen }),
           req.user.id, motivo]
        );
        await client.query('DELETE FROM piezas WHERE id = $1', [id]);
        return 'eliminada';
      }

      await client.query(`SELECT cambiar_estado_pieza($1, 'descartado', $2, $3)`, [id, req.user.id, motivo]);
      return 'descartada';
    });

    res.json({ resultado, pieza_id: id });
  } catch (error) {
    if (error.status) return res.status(error.status).json({ error: error.message });
    const [status, msg] = httpError(error);
    if (status === 500) console.error('descartarPieza', error);
    res.status(status).json({ error: msg });
  }
};

module.exports = {
  getPiezas,
  getPiezaById,
  createPieza,
  confirmarPieza,
  cambiarEstadoPieza,
  updatePieza,
  descartarPieza,
  mapPieza,
  leerPieza,
};
