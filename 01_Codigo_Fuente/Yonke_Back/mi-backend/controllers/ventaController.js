const db = require('../config/db');
const { SQL_YONQUES_DEL_USUARIO, piezaDelUsuario } = require('../utils/acceso');
const { withUser } = require('../utils/tx');
const { derivadoUrl } = require('../utils/s3');
const httpError = require('../utils/pgErrors');

const METODOS = ['efectivo', 'tarjeta', 'transferencia', 'deposito', 'credito', 'otro'];

const SQL_VENTA = `
  SELECT v.id, v.pieza_id, v.comprador_nombre, v.precio_final::float8 AS precio_final,
         v.metodo_pago, v.estado, v.notas, v.fecha_venta,
         pz.nombre AS pieza_nombre, pz.codigo_sku AS pieza_sku,
         CONCAT_WS(' ', ve.anio, COALESCE(mk.nombre, ve.marca_texto),
                   COALESCE(mo.nombre, ve.modelo_texto)) AS vehiculo_titulo,
         ft.s3_key AS foto_key,
         v.yonque_id
    FROM ventas v
    JOIN piezas pz ON pz.id = v.pieza_id
    JOIN vehiculos ve ON ve.id = pz.vehiculo_id
    LEFT JOIN marcas_vehiculo mk ON mk.id = ve.marca_id
    LEFT JOIN modelos_vehiculo mo ON mo.id = ve.modelo_id
    LEFT JOIN LATERAL (
         SELECT f.s3_key FROM fotos f
          WHERE f.pieza_id = pz.id
          ORDER BY f.es_principal DESC, f.orden LIMIT 1) ft ON TRUE`;

function mapVenta(row) {
  const { foto_key, yonque_id, ...v } = row;
  return { ...v, foto_thumb_url: derivadoUrl(foto_key, 'thumb') };
}

// GET /api/ventas → historial del yonque del usuario.
const getVentas = async (req, res) => {
  try {
    const { rows } = await db.query(
      `${SQL_VENTA}
        WHERE v.yonque_id IN (${SQL_YONQUES_DEL_USUARIO})
        ORDER BY v.fecha_venta DESC`,
      [req.user.id]
    );
    res.json(rows.map(mapVenta));
  } catch (error) {
    console.error('getVentas', error);
    res.status(500).json({ error: 'Error al obtener ventas' });
  }
};

// POST /api/ventas  { pieza_id, precio_final, metodo_pago, comprador_nombre?, notas? }
// Llama a procesar_venta(): cierra la publicación, crea la venta y deja la pieza vendida.
const postVenta = async (req, res) => {
  try {
    const { pieza_id, precio_final, metodo_pago, comprador_nombre, notas } = req.body;
    if (!pieza_id) return res.status(400).json({ error: 'pieza_id es obligatorio' });
    if (!(Number(precio_final) > 0)) {
      return res.status(400).json({ error: 'El precio final debe ser mayor a cero' });
    }
    if (metodo_pago && !METODOS.includes(metodo_pago)) {
      return res.status(400).json({ error: 'Método de pago no válido' });
    }

    const pieza = await piezaDelUsuario(null, req.user.id, pieza_id);
    if (!pieza) return res.status(404).json({ error: 'Pieza no encontrada' });

    const ventaId = await withUser(req.user.id, 'Venta', async (client) => {
      const r = await client.query(
        `SELECT procesar_venta($1, $2, $3, $4, $5, $6) AS id`,
        [pieza_id, req.user.id, comprador_nombre || null, precio_final,
         metodo_pago || 'efectivo', notas || null]
      );
      return r.rows[0].id;
    });

    const { rows } = await db.query(`${SQL_VENTA} WHERE v.id = $1`, [ventaId]);
    res.status(201).json(mapVenta(rows[0]));
  } catch (error) {
    const [status, msg] = httpError(error);
    if (status === 500) console.error('postVenta', error);
    res.status(status).json({ error: msg });
  }
};

// POST /api/ventas/:id/devolver → estado 'devuelta'. El trigger regresa la pieza a disponible.
const devolverVenta = async (req, res) => {
  try {
    // $1 = usuario (lo usa SQL_YONQUES_DEL_USUARIO), $2 = venta.
    const { rows: existentes } = await db.query(
      `${SQL_VENTA} WHERE v.id = $2 AND v.yonque_id IN (${SQL_YONQUES_DEL_USUARIO})`,
      [req.user.id, req.params.id]
    );
    if (!existentes[0]) return res.status(404).json({ error: 'Venta no encontrada' });

    const { rowCount } = await withUser(req.user.id, 'Devolver venta', async (client) =>
      client.query(
        `UPDATE ventas SET estado = 'devuelta' WHERE id = $1 AND estado = 'completada'`,
        [req.params.id]
      )
    );
    if (!rowCount) return res.status(409).json({ error: 'Solo se pueden devolver ventas completadas' });

    const { rows } = await db.query(`${SQL_VENTA} WHERE v.id = $1`, [req.params.id]);
    res.json(mapVenta(rows[0]));
  } catch (error) {
    const [status, msg] = httpError(error);
    if (status === 500) console.error('devolverVenta', error);
    res.status(status).json({ error: msg });
  }
};

module.exports = { getVentas, postVenta, devolverVenta };
