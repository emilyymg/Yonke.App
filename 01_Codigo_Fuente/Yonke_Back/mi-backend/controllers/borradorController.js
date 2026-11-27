const db = require('../config/db');
const { SQL_YONQUES_DEL_USUARIO, piezaDelUsuario } = require('../utils/acceso');
const { withUser } = require('../utils/tx');
const { derivadoUrl } = require('../utils/s3');
const httpError = require('../utils/pgErrors');
const { conEstado, prepararReactivacionPieza } = require('../utils/reactivacion');

const ABIERTOS = ['pendiente', 'en_edicion', 'listo_para_publicar'];
const CONDICIONES = ['nuevo', 'seminuevo', 'usado', 'refaccionado', 'danado', 'para_reparar'];

const SQL_BORRADOR = `
  SELECT b.id, b.pieza_id, b.titulo, b.descripcion_marketplace,
         b.precio_publico::float8 AS precio_publico, b.condicion_publicada,
          b.fotos_marketplace, b.estado, b.motivo_descarte,
          pz.nombre AS pieza_nombre, pz.codigo_sku AS pieza_sku,
         CONCAT_WS(' ', ve.anio, COALESCE(mk.nombre, ve.marca_texto),
                   COALESCE(mo.nombre, ve.modelo_texto)) AS vehiculo_titulo,
         ft.s3_key AS foto_key,
         ve.yonque_id
    FROM borradores_publicacion b
    JOIN piezas pz ON pz.id = b.pieza_id
    JOIN vehiculos ve ON ve.id = pz.vehiculo_id
    LEFT JOIN marcas_vehiculo mk ON mk.id = ve.marca_id
    LEFT JOIN modelos_vehiculo mo ON mo.id = ve.modelo_id
    LEFT JOIN LATERAL (
         SELECT f.s3_key FROM fotos f
          WHERE f.pieza_id = pz.id
          ORDER BY f.es_principal DESC, f.orden LIMIT 1) ft ON TRUE`;

// El contrato es una lista de ids de `fotos`. Algunas filas guardadas tienen objetos
// ({ id, ... }) en el JSONB; se normalizan a id para que la app pueda decodificarlas.
function fotoId(f) {
  return typeof f === 'string' ? f : (f && f.id) || null;
}

function mapBorrador(row) {
  const { foto_key, yonque_id, ...b } = row;
  return {
    ...b,
    fotos_marketplace: (b.fotos_marketplace || []).map(fotoId).filter(Boolean),
    foto_thumb_url: derivadoUrl(foto_key, 'thumb'),
  };
}

// Borrador solo si su pieza pertenece al yonque del usuario.
async function borradorDelUsuario(client, userId, borradorId) {
  const q = client ? client.query.bind(client) : db.query;
  // $1 = usuario (lo usa SQL_YONQUES_DEL_USUARIO), $2 = borrador.
  const { rows } = await q(
    `${SQL_BORRADOR} WHERE b.id = $2 AND ve.yonque_id IN (${SQL_YONQUES_DEL_USUARIO})`,
    [userId, borradorId]
  );
  return rows[0] || null;
}

// GET /api/borradores?estado=descartado → borradores abiertos del yonque (por defecto),
// o los descartados si se pide estado=descartado.
const getBorradores = async (req, res) => {
  try {
    const estados = req.query.estado === 'descartado' ? ['descartado'] : ABIERTOS;
    const { rows } = await db.query(
      `${SQL_BORRADOR}
        WHERE b.estado = ANY($2::text[])
          AND ve.yonque_id IN (${SQL_YONQUES_DEL_USUARIO})
        ORDER BY b.fecha_ultima_edicion DESC`,
      [req.user.id, estados]
    );
    res.json(rows.map(mapBorrador));
  } catch (error) {
    console.error('getBorradores', error);
    res.status(500).json({ error: 'Error al obtener borradores' });
  }
};

// GET /api/borradores/:id
const getBorradorById = async (req, res) => {
  try {
    const row = await borradorDelUsuario(null, req.user.id, req.params.id);
    if (!row) return res.status(404).json({ error: 'Borrador no encontrado' });
    res.json(mapBorrador(row));
  } catch (error) {
    console.error('getBorradorById', error);
    res.status(500).json({ error: 'Error al obtener el borrador' });
  }
};

// POST /api/borradores  { pieza_id }
// Crea el borrador con título y descripción sugeridos. La pieza debe estar disponible.
const postBorrador = async (req, res) => {
  try {
    const { pieza_id } = req.body;
    if (!pieza_id) return res.status(400).json({ error: 'pieza_id es obligatorio' });

    const pieza = await piezaDelUsuario(null, req.user.id, pieza_id);
    if (!pieza) return res.status(404).json({ error: 'Pieza no encontrada' });
    if (pieza.estado_inventario !== 'disponible') {
      return res.status(409).json({ error: 'La pieza debe estar disponible para publicarse' });
    }

    const sugerido = await db.query(
      `SELECT pz.nombre, pz.descripcion, pz.precio_venta::float8 AS precio, pz.condicion,
              CONCAT_WS(' ', ve.anio, COALESCE(mk.nombre, ve.marca_texto),
                        COALESCE(mo.nombre, ve.modelo_texto)) AS vehiculo
         FROM piezas pz
         JOIN vehiculos ve ON ve.id = pz.vehiculo_id
         LEFT JOIN marcas_vehiculo mk ON mk.id = ve.marca_id
         LEFT JOIN modelos_vehiculo mo ON mo.id = ve.modelo_id
        WHERE pz.id = $1`,
      [pieza_id]
    );
    const s = sugerido.rows[0];

    const principal = await db.query(
      `SELECT id FROM fotos WHERE pieza_id = $1 ORDER BY es_principal DESC, orden LIMIT 1`,
      [pieza_id]
    );
    const fotos = principal.rows[0] ? [principal.rows[0].id] : [];

    const id = await withUser(req.user.id, 'Crear borrador', async (client) => {
      const r = await client.query(
        `INSERT INTO borradores_publicacion
           (pieza_id, usuario_id, titulo, descripcion_marketplace, precio_publico,
            condicion_publicada, fotos_marketplace, estado)
         VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, 'pendiente')
         RETURNING id`,
        [pieza_id, req.user.id, [s.nombre, s.vehiculo].filter(Boolean).join(' '),
         s.descripcion || '', s.precio, s.condicion, JSON.stringify(fotos)]
      );
      return r.rows[0].id;
    });

    res.status(201).json(mapBorrador(await borradorDelUsuario(null, req.user.id, id)));
  } catch (error) {
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Esta pieza ya tiene un borrador abierto' });
    }
    const [status, msg] = httpError(error);
    if (status === 500) console.error('postBorrador', error);
    res.status(status).json({ error: msg });
  }
};

// PUT /api/borradores/:id
// Body: titulo, descripcion, precio_publico, condicion_publicada, fotos_marketplace (ids de fotos), marcar_listo
const putBorrador = async (req, res) => {
  try {
    const actual = await borradorDelUsuario(null, req.user.id, req.params.id);
    if (!actual) return res.status(404).json({ error: 'Borrador no encontrado' });
    if (!ABIERTOS.includes(actual.estado)) {
      return res.status(409).json({ error: 'Este borrador ya no se puede editar' });
    }

    const cambios = req.body;
    const titulo = cambios.titulo !== undefined ? (cambios.titulo || '').trim() || null : actual.titulo;
    const descripcion = cambios.descripcion !== undefined ? cambios.descripcion : actual.descripcion_marketplace;
    const precio = cambios.precio_publico !== undefined ? cambios.precio_publico : actual.precio_publico;
    const condicion = cambios.condicion_publicada !== undefined ? cambios.condicion_publicada : actual.condicion_publicada;
    const fotos = cambios.fotos_marketplace !== undefined ? cambios.fotos_marketplace : actual.fotos_marketplace;
    const marcarListo = cambios.marcar_listo === true;

    if (condicion && !CONDICIONES.includes(condicion)) {
      return res.status(400).json({ error: 'Condición no válida' });
    }
    if (marcarListo && (!titulo || !(Number(precio) > 0))) {
      return res.status(400).json({ error: 'Título y precio son obligatorios para publicar' });
    }
    if (!Array.isArray(fotos)) {
      return res.status(400).json({ error: 'fotos_marketplace debe ser una lista de ids' });
    }
    if (fotos.length > 0) {
      const { rows } = await db.query(
        `SELECT COUNT(*)::int AS n FROM fotos WHERE pieza_id = $1 AND id = ANY($2::uuid[])`,
        [actual.pieza_id, fotos]
      );
      if (rows[0].n !== fotos.length) {
        return res.status(400).json({ error: 'Alguna foto no pertenece a la pieza' });
      }
    }

    const nuevoEstado = marcarListo ? 'listo_para_publicar' : 'en_edicion';
    await withUser(req.user.id, 'Editar borrador', async (client) => {
      await client.query(
        `UPDATE borradores_publicacion
            SET titulo = $1, descripcion_marketplace = $2, precio_publico = $3,
                condicion_publicada = $4, fotos_marketplace = $5::jsonb,
                estado = $6, fecha_ultima_edicion = now()
          WHERE id = $7 AND estado = ANY($8::text[])`,
        [titulo, descripcion, precio, condicion, JSON.stringify(fotos),
         nuevoEstado, req.params.id, ABIERTOS]
      );
    });

    res.json(mapBorrador(await borradorDelUsuario(null, req.user.id, req.params.id)));
  } catch (error) {
    const [status, msg] = httpError(error);
    if (status === 500) console.error('putBorrador', error);
    res.status(status).json({ error: msg });
  }
};

// POST /api/borradores/:id/publicar → publicar_borrador(). Devuelve el id de la publicación.
const publicarBorrador = async (req, res) => {
  try {
    const actual = await borradorDelUsuario(null, req.user.id, req.params.id);
    if (!actual) return res.status(404).json({ error: 'Borrador no encontrado' });

    const publicacionId = await withUser(req.user.id, `Publicar borrador ${req.params.id}`, async (client) => {
      const r = await client.query('SELECT publicar_borrador($1, $2) AS id', [req.params.id, req.user.id]);
      return r.rows[0].id;
    });

    res.status(201).json({ message: 'Publicado correctamente', publicacion_id: publicacionId });
  } catch (error) {
    const [status, msg] = httpError(error);
    if (status === 500) console.error('publicarBorrador', error);
    res.status(status).json({ error: msg });
  }
};

// DELETE /api/borradores/:id  { motivo? } → estado 'descartado' (sin borrado físico).
const descartarBorrador = async (req, res) => {
  try {
    const actual = await borradorDelUsuario(null, req.user.id, req.params.id);
    if (!actual) return res.status(404).json({ error: 'Borrador no encontrado' });

    const { rowCount } = await db.query(
      `UPDATE borradores_publicacion
          SET estado = 'descartado', motivo_descarte = $1, fecha_ultima_edicion = now()
        WHERE id = $2 AND estado = ANY($3::text[])`,
      [req.body.motivo || null, req.params.id, ABIERTOS]
    );
    if (!rowCount) return res.status(409).json({ error: 'Este borrador ya no se puede descartar' });

    res.json({ message: 'Borrador descartado' });
  } catch (error) {
    console.error('descartarBorrador', error);
    res.status(500).json({ error: 'Error al descartar el borrador' });
  }
};

// POST /api/borradores/:id/reabrir → 'descartado' vuelve a 'en_edicion'.
// El borrador regresa a Borradores; desde ahí se edita y se publica con las validaciones normales.
const reabrirBorrador = async (req, res) => {
  try {
    const actual = await borradorDelUsuario(null, req.user.id, req.params.id);
    if (!actual) return res.status(404).json({ error: 'Borrador no encontrado' });
    if (actual.estado !== 'descartado') {
      return res.status(409).json({ error: 'Solo se pueden restaurar borradores descartados' });
    }

    await withUser(req.user.id, 'Reabrir borrador', async (client) => {
      await prepararReactivacionPieza(client, actual.pieza_id);
      const r = await client.query(
        `UPDATE borradores_publicacion
            SET estado = 'en_edicion', motivo_descarte = NULL, fecha_ultima_edicion = now()
          WHERE id = $1 AND estado = 'descartado'`,
        [req.params.id]
      );
      if (!r.rowCount) throw conEstado('Este borrador ya no se puede restaurar', 409);
    });

    res.json(mapBorrador(await borradorDelUsuario(null, req.user.id, req.params.id)));
  } catch (error) {
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Esta pieza ya tiene un borrador abierto' });
    }
    const [status, msg] = httpError(error);
    if (status === 500) console.error('reabrirBorrador', error);
    res.status(status).json({ error: msg });
  }
};

module.exports = {
  getBorradores,
  getBorradorById,
  postBorrador,
  putBorrador,
  publicarBorrador,
  descartarBorrador,
  reabrirBorrador,
};
