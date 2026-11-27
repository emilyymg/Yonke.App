// Cliente S3 para generar URLs prefirmadas de subida.
// Credenciales: cadena estándar del SDK (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY en .env).
// El rol debe tener s3:PutObject solo sobre originales/*.
const { S3Client } = require('@aws-sdk/client-s3');

const REGION = process.env.AWS_REGION || 'us-east-1';

const s3 = new S3Client({ region: REGION });

module.exports = {
  s3,
  BUCKET: process.env.S3_BUCKET_NAME,
};
