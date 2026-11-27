const db = require('../config/db');
const { yonqueDelUsuario } = require('../utils/acceso');

// GET /api/yonques/mio → datos del yonque del usuario y resumen de inventario.
const getMio = async (req, res) => {
  try {
    const yonqueId = await yonqueDelUsuario(null, req.user.id);
    if (!yonqueId) return res.status(404).json({ error: 'Tu cuenta no está asociada a un yonque' });

    const { rows } = await db.query(
      `SELECT y.id, y.nombre, y.estado,
              u.telefono AS telefono,
              ub.calle, ub.numero, ub.colonia, ub.ciudad, ub.estado AS estado_geo, ub.codigo_postal
         FROM yonques y
         JOIN usuarios u ON u.id = y.usuario_id
         LEFT JOIN ubicaciones ub ON ub.id = y.ubicacion_id
        WHERE y.id = $1`,
      [yonqueId]
    );
    const y = rows[0];

    const resumen = await db.query(
      `SELECT COALESCE(SUM(piezas_por_confirmar), 0)::int AS piezas_por_confirmar,
              COALESCE(SUM(piezas_disponibles), 0)::int AS piezas_disponibles,
              COALESCE(SUM(total_vehiculos), 0)::int AS total_vehiculos
         FROM v_inventario_actual WHERE yonque_id = $1`,
      [yonqueId]
    );
    const publicaciones = await db.query(
      `SELECT COUNT(*)::int AS activas FROM publicaciones WHERE yonque_id = $1 AND estado = 'activa'`,
      [yonqueId]
    );

    res.json({
      id: y.id,
      nombre: y.nombre,
      estado: y.estado,
      telefono: y.telefono,
      ubicacion: {
        direccion: [y.calle, y.numero].filter(Boolean).join(' ') || null,
        ciudad: y.ciudad || null,
        estado: y.estado_geo || null,
        codigoPostal: y.codigo_postal || null,
      },
      resumen: {
        piezas_por_confirmar: resumen.rows[0].piezas_por_confirmar,
        piezas_disponibles: resumen.rows[0].piezas_disponibles,
        total_vehiculos: resumen.rows[0].total_vehiculos,
        publicaciones_activas: publicaciones.rows[0].activas,
      },
    });
  } catch (error) {
    console.error('getMio', error);
    res.status(500).json({ error: 'Error al obtener el yonque' });
  }
};

module.exports = { getMio };
