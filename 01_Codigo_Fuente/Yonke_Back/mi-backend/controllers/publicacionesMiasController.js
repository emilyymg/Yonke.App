const db = require('../config/db');
const { SQL_YONQUES_DEL_USUARIO } = require('../utils/acceso');
const { derivadoUrl } = require('../utils/s3');
const { withUser } = require('../utils/tx');
const httpError = require('../utils/pgErrors');
const { prepararReactivacionPieza } = require('../utils/reactivacion');

// Por defecto se listan las vigentes e históricas; "eliminada" solo si se pide explícitamente.
const FILTRABLES = ['activa', 'pausada', 'vendida'];
const CONSULTABLES = [...FILTRABLES, 'eliminada'];

// Transiciones que la app puede pedir. "vendida" lo pone procesar_venta, no la API.
const DESTINOS_API = ['activa', 'pausada', 'eliminada'];
const TRANSICIONES = {
  activa: ['pausada', 'eliminada'],
  pausada: ['activa', 'eliminada'],
  eliminada: ['activa'],
};

// Misma forma que GET /mias: la app decodifica ambas con el mismo modelo.
const SQL_PUBLICACION_MIA = `
  SELECT p.id, p.pieza_id, p.titulo, p.descripcion,
         p.precio::float8 AS precio, p.condicion, p.estado, p.vistas,
         p.fecha_publicacion,
         pz.nombre AS pieza_nombre, pz.codigo_sku AS pieza_sku,
         CONCAT_WS(' ', ve.anio, COALESCE(mk.nombre, ve.marca_texto),
                   COALESCE(mo.nombre, ve.modelo_texto)) AS vehiculo_titulo,
         ft.s3_key AS foto_key,
         p.yonque_id
    FROM publicaciones p
    JOIN piezas pz ON pz.id = p.pieza_id
    JOIN vehiculos ve ON ve.id = pz.vehiculo_id
    LEFT JOIN marcas_vehiculo mk ON mk.id = ve.marca_id
    LEFT JOIN modelos_vehiculo mo ON mo.id = ve.modelo_id
    LEFT JOIN LATERAL (
         SELECT f.s3_key FROM fotos f
          WHERE f.pieza_id = pz.id
          ORDER BY f.es_principal DESC, f.orden LIMIT 1) ft ON TRUE`;

function mapPublicacion(row) {
  const { foto_key, yonque_id, ...p } = row;
  return { ...p, foto_thumb_url: derivadoUrl(foto_key, 'thumb') };
}

// GET /api/publicaciones/mias?estado=  → publicaciones del yonque del usuario.
const getMias = async (req, res) => {
  try {
    const estado = req.query.estado;
    const estados = CONSULTABLES.includes(estado) ? [estado] : FILTRABLES;

    const { rows } = await db.query(
      `${SQL_PUBLICACION_MIA}
        WHERE p.estado = ANY($2::text[])
          AND p.yonque_id IN (${SQL_YONQUES_DEL_USUARIO})
        ORDER BY p.fecha_publicacion DESC NULLS LAST`,
      [req.user.id, estados]
    );

    res.json(rows.map(mapPublicacion));
  } catch (error) {
    console.error('getMias', error);
    res.status(500).json({ error: 'Error al obtener publicaciones' });
  }
};

// POST /api/publicaciones/:id/estado  { estado: 'activa' | 'pausada' | 'eliminada' }
// Solo transiciones permitidas. Pausar, reactivar y eliminar no tocan el inventario.
const cambiarEstado = async (req, res) => {
  try {
    const { estado } = req.body;
    if (!DESTINOS_API.includes(estado)) {
      return res.status(400).json({ error: 'Estado de destino no permitido por esta ruta' });
    }

    // $1 = usuario (lo usa SQL_YONQUES_DEL_USUARIO), $2 = publicación.
    const { rows } = await db.query(
      `${SQL_PUBLICACION_MIA} WHERE p.id = $2 AND p.yonque_id IN (${SQL_YONQUES_DEL_USUARIO})`,
      [req.user.id, req.params.id]
    );
    const actual = rows[0];
    if (!actual) return res.status(404).json({ error: 'Publicación no encontrada' });

    if (!(TRANSICIONES[actual.estado] || []).includes(estado)) {
      return res.status(409).json({
        error: `No se puede pasar de ${actual.estado} a ${estado}`,
      });
    }

    await withUser(req.user.id, `Publicación ${estado}`, async (client) => {
      if (actual.estado === 'eliminada') {
        await prepararReactivacionPieza(client, actual.pieza_id);
      }
      const r = await client.query(
        `UPDATE publicaciones SET estado = $1 WHERE id = $2 AND estado = $3`,
        [estado, req.params.id, actual.estado]
      );
      if (!r.rowCount) {
        const e = new Error('La publicación cambió mientras se actualizaba. Vuelve a intentarlo.');
        e.status = 409;
        throw e;
      }
    });

    const { rows: actualizada } = await db.query(
      `${SQL_PUBLICACION_MIA} WHERE p.id = $1`,
      [req.params.id]
    );
    res.json(mapPublicacion(actualizada[0]));
  } catch (error) {
    if (error.status) return res.status(error.status).json({ error: error.message });
    // Índice único: solo una publicación activa o pausada por pieza.
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Esta pieza ya tiene una publicación activa o pausada' });
    }
    const [status, msg] = httpError(error);
    if (status === 500) console.error('cambiarEstado publicación', error);
    res.status(status).json({ error: msg });
  }
};

module.exports = { getMias, cambiarEstado };
