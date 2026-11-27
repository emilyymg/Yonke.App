const crypto = require('crypto');
const db = require('../config/db');
const { piezaDelUsuario } = require('../utils/acceso');
const { s3, BUCKET } = require('../config/s3');
const { withUser } = require('../utils/tx');
const httpError = require('../utils/pgErrors');
const { PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const EXPIRA_SEGUNDOS = 300;

// POST /api/fotos/upload-url  { pieza_id }
// 1. Verifica que la pieza sea del yonque del usuario.
// 2. Inserta la fila en `fotos` con s3_key = originales/{vehiculo}/{pieza}/{foto}.jpg.
// 3. Devuelve una URL prefirmada PUT. La app sube el JPEG directo a S3.
// Los derivados thumb/medium los genera la Lambda al recibir el objeto.
//
// Pendiente: `cliente_id` (idempotencia de reintentos) no se guarda porque `fotos`
// no tiene columna para ello. Un reintento tras un PUT fallido crea otra fila; esa
// fila no tendrá derivados. Requiere una columna `cliente_id UNIQUE` en `fotos`.
const postUploadUrl = async (req, res) => {
  try {
    const { pieza_id } = req.body;
    if (!pieza_id) return res.status(400).json({ error: 'pieza_id es obligatorio' });
    if (!BUCKET) return res.status(500).json({ error: 'Configuración incompleta: falta S3_BUCKET_NAME' });

    const pieza = await piezaDelUsuario(null, req.user.id, pieza_id);
    if (!pieza) return res.status(404).json({ error: 'Pieza no encontrada' });

    const fotoId = crypto.randomUUID();
    const key = `originales/${pieza.vehiculo_id}/${pieza_id}/${fotoId}.jpg`;

    await db.query(
      `INSERT INTO fotos (id, pieza_id, s3_key, orden, es_principal, publicable)
       SELECT $1::uuid, $2::uuid, $3::text,
              COALESCE(MAX(orden) + 1, 0)::smallint,
              NOT EXISTS (SELECT 1 FROM fotos WHERE pieza_id = $2::uuid AND es_principal),
              TRUE
         FROM fotos WHERE pieza_id = $2::uuid`,
      [fotoId, pieza_id, key]
    );

    const uploadUrl = await getSignedUrl(
      s3,
      new PutObjectCommand({ Bucket: BUCKET, Key: key, ContentType: 'image/jpeg' }),
      { expiresIn: EXPIRA_SEGUNDOS }
    );

    res.status(201).json({ foto_id: fotoId, upload_url: uploadUrl });
  } catch (error) {
    const [status, msg] = httpError(error);
    if (status === 500) console.error('postUploadUrl', error);
    res.status(status).json({ error: msg });
  }
};

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Id de cada elemento de fotos_marketplace: el contrato son strings,
// pero hay filas guardadas con objetos { id, ... } (ver borradorController).
const ID_ELEMENTO = `(CASE WHEN jsonb_typeof(x) = 'string' THEN x #>> '{}' ELSE x ->> 'id' END)`;

// DELETE /api/fotos/:id
// Quita la foto de la base. Si era la principal, pasa a principal la siguiente.
// Quita su id de los borradores abiertos de la pieza (fotos_marketplace).
// El objeto en S3 no se borra: el rol del backend solo tiene s3:PutObject.
const deleteFoto = async (req, res) => {
  try {
    const fotoId = req.params.id;
    if (!UUID_RE.test(fotoId)) return res.status(400).json({ error: 'id de foto no válido' });

    const { rows } = await db.query('SELECT pieza_id FROM fotos WHERE id = $1', [fotoId]);
    if (!rows[0]) return res.status(404).json({ error: 'Foto no encontrada' });
    const piezaId = rows[0].pieza_id;

    // Misma regla de autorización que la pieza: miembro activo del yonque.
    const pieza = await piezaDelUsuario(null, req.user.id, piezaId);
    if (!pieza) return res.status(404).json({ error: 'Foto no encontrada' });
    if (pieza.estado_inventario === 'vendido') {
      return res.status(409).json({ error: 'Una pieza vendida no se puede editar' });
    }

    await withUser(req.user.id, 'Eliminar foto', async (client) => {
      const { rows: borrada } = await client.query(
        'DELETE FROM fotos WHERE id = $1 RETURNING es_principal', [fotoId]
      );
      if (!borrada[0]) {
        const e = new Error('Foto no encontrada'); e.status = 404; throw e;
      }

      if (borrada[0].es_principal) {
        await client.query(
          `UPDATE fotos SET es_principal = TRUE
            WHERE id = (SELECT id FROM fotos WHERE pieza_id = $1
                         ORDER BY orden, fecha_creacion LIMIT 1)`,
          [piezaId]
        );
      }

      await client.query(
        `UPDATE borradores_publicacion b
            SET fotos_marketplace = COALESCE(
                  (SELECT jsonb_agg(x) FROM jsonb_array_elements(b.fotos_marketplace) x
                    WHERE ${ID_ELEMENTO} IS DISTINCT FROM $1::text),
                  '[]'::jsonb),
                fecha_ultima_edicion = now()
          WHERE b.pieza_id = $2
            AND b.estado IN ('pendiente', 'en_edicion', 'listo_para_publicar')
            AND EXISTS (SELECT 1 FROM jsonb_array_elements(b.fotos_marketplace) x
                         WHERE ${ID_ELEMENTO} = $1::text)`,
        [fotoId, piezaId]
      );
    });

    res.json({ message: 'Foto eliminada', pieza_id: piezaId });
  } catch (error) {
    if (error.status) return res.status(error.status).json({ error: error.message });
    const [status, msg] = httpError(error);
    if (status === 500) console.error('deleteFoto', error);
    res.status(status).json({ error: msg });
  }
};

module.exports = { postUploadUrl, deleteFoto };
