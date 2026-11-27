const db = require('../config/db');
const { fotoDTO } = require('../utils/s3');

// Marketplace público (lo usa la web). La app de yonqueros no lo necesita.
// Las escrituras de publicaciones van por /api/borradores (publicar_borrador).

const getAllPublicaciones = async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 20, 100);
    const offset = parseInt(req.query.offset, 10) || 0;
    const q = String(req.query.q || '').trim();

    // Filtros opcionales: q (texto), categoria (nombres separados por coma),
    // precio_min y precio_max.
    const params = [limit, offset];
    const condiciones = [];
    if (q) {
      params.push(q);
      condiciones.push(`p.palabras_clave @@ websearch_to_tsquery('spanish', $${params.length})`);
    }
    const categorias = String(req.query.categoria || '')
      .split(',').map((c) => c.trim()).filter(Boolean);
    if (categorias.length) {
      params.push(categorias);
      condiciones.push(`cp.nombre = ANY($${params.length})`);
    }
    const precioMin = parseFloat(req.query.precio_min);
    if (Number.isFinite(precioMin)) {
      params.push(precioMin);
      condiciones.push(`p.precio >= $${params.length}`);
    }
    const precioMax = parseFloat(req.query.precio_max);
    if (Number.isFinite(precioMax)) {
      params.push(precioMax);
      condiciones.push(`p.precio <= $${params.length}`);
    }
    const filtros = condiciones.map((c) => `AND ${c}`).join(' ');

    const { rows } = await db.query(
      `SELECT p.id, p.titulo, p.precio::float8 AS precio, p.condicion,
              p.fecha_publicacion, y.nombre AS nombre_yonque,
              ft.s3_key AS foto_key
         FROM publicaciones p
         JOIN yonques y ON y.id = p.yonque_id
         LEFT JOIN piezas pz ON pz.id = p.pieza_id
         LEFT JOIN categorias_piezas cp ON cp.id = pz.categoria_id
         LEFT JOIN LATERAL (
              SELECT f.s3_key FROM fotos f
               WHERE f.pieza_id = p.pieza_id AND f.publicable
               ORDER BY f.es_principal DESC, f.orden ASC
               LIMIT 1) ft ON TRUE
        WHERE p.estado = 'activa' ${filtros}
        ORDER BY p.fecha_publicacion DESC
        LIMIT $1 OFFSET $2`,
      params
    );

    res.json(rows.map(({ foto_key, ...r }) => {
      const foto = fotoDTO({ s3_key: foto_key, orden: 0, principal: false, id: null });
      return {
        ...r,
        imagen_thumb_url: foto.thumb_url,
        imagen_medium_url: foto.medium_url,
      };
    }));
  } catch (error) {
    console.error('getAllPublicaciones', error);
    res.status(500).json({ error: 'Error al obtener publicaciones' });
  }
};

const getPublicacionById = async (req, res) => {
  try {
    const { id } = req.params;

    const { rows } = await db.query(
      `SELECT p.id, p.titulo, p.descripcion, p.precio::float8 AS precio, p.condicion,
              p.vistas, pz.nombre AS nombre_pieza, pz.codigo_sku AS codigo_sku,
              y.nombre AS yonque_nombre, u.telefono AS yonque_telefono, u.email AS yonque_correo,
              ub.direccion_linea AS ubicacion_direccion, ub.ciudad, ub.estado, ub.codigo_postal,
              ub.latitud::float8 AS latitud, ub.longitud::float8 AS longitud,
              (SELECT COALESCE(json_agg(json_build_object(
                        'id', f.id, 's3_key', f.s3_key,
                        'orden', f.orden, 'principal', f.es_principal)
                      ORDER BY f.es_principal DESC, f.orden), '[]'::json)
                 FROM fotos f
                WHERE f.pieza_id = p.pieza_id AND f.publicable) AS fotos
         FROM publicaciones p
         JOIN piezas pz ON pz.id = p.pieza_id
         JOIN yonques y ON y.id = p.yonque_id
         JOIN usuarios u ON u.id = y.usuario_id
         LEFT JOIN LATERAL (
              SELECT CONCAT_WS(' ', ubi.calle, ubi.numero) AS direccion_linea,
                     ubi.ciudad, ubi.estado, ubi.codigo_postal, ubi.latitud, ubi.longitud
                FROM ubicaciones ubi WHERE ubi.id = y.ubicacion_id) ub ON TRUE
        WHERE p.id = $1 AND p.estado IN ('activa', 'pausada')`,
      [id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Publicación no encontrada' });

    // Contador de vistas sin bloquear la respuesta.
    db.query('UPDATE publicaciones SET vistas = vistas + 1 WHERE id = $1', [id]).catch(() => {});

    const { fotos, ...p } = rows[0];
    res.json({
      id: p.id,
      titulo: p.titulo,
      descripcion: p.descripcion,
      precio: p.precio,
      condicion: p.condicion,
      vistas: p.vistas,
      nombre_pieza: p.nombre_pieza,
      codigo_sku: p.codigo_sku,
      fotos: fotos.map((f) => fotoDTO(f)),
      yonque: {
        nombre: p.yonque_nombre,
        // Teléfono solo para visitantes; decisión de privacidad pendiente (plan §6.2).
        telefono: p.yonque_telefono,
        correo: p.yonque_correo,
        ubicacion: {
          direccion: p.ubicacion_direccion,
          ciudad: p.ciudad,
          estado: p.estado,
          codigoPostal: p.codigo_postal,
          latitud: p.latitud,
          longitud: p.longitud,
        },
      },
    });
  } catch (error) {
    console.error('getPublicacionById', error);
    res.status(500).json({ error: 'Error al obtener la publicación' });
  }
};

module.exports = {
  getAllPublicaciones,
  getPublicacionById,
};
