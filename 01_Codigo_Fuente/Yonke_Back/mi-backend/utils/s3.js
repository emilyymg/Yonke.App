// Helpers de S3. Solo `derivados/` es público; `originales/` nunca se expone.
//
// originales/{vehiculo}/{pieza}/{foto}.jpg  →  derivados/{vehiculo}/{pieza}/{foto}/{size}.webp
// Los derivados los genera una Lambda al recibir la subida (evento S3).

const BUCKET = process.env.S3_BUCKET_NAME;
const REGION = process.env.AWS_REGION || 'us-east-1';
// Si se usa CloudFront: PUBLIC_MEDIA_BASE_URL=https://dxxxx.cloudfront.net
const BASE = process.env.PUBLIC_MEDIA_BASE_URL || `https://${BUCKET}.s3.${REGION}.amazonaws.com`;

// Quita "s3://bucket/" y las barras iniciales.
function cleanKey(key) {
  return String(key || '').replace(/^s3:\/\/[^/]+\//, '').replace(/^\/+/, '');
}

const encodeKey = (key) => key.split('/').map(encodeURIComponent).join('/');

function derivadoKey(s3Key, size) {
  const m = cleanKey(s3Key).match(/^originales\/(.+)\.[A-Za-z0-9]+$/);
  return m ? `derivados/${m[1]}/${size}.webp` : null;
}

function derivadoUrl(s3Key, size) {
  const key = derivadoKey(s3Key, size);
  return key ? `${BASE}/${encodeKey(key)}` : null;
}

// Fila de la tabla `fotos` → DTO para la app.
function fotoDTO(f) {
  return {
    id: f.id,
    orden: f.orden,
    principal: f.principal,
    thumb_url: derivadoUrl(f.s3_key, 'thumb'),
    medium_url: derivadoUrl(f.s3_key, 'medium'),
  };
}

module.exports = { derivadoUrl, fotoDTO, cleanKey };
