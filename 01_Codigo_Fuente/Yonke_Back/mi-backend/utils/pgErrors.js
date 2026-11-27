// Traduce errores de Postgres (y de las funciones de negocio) a HTTP.
// Devuelve [status, mensaje].
module.exports = function httpError(err) {
  if (err && err.status) return [err.status, err.message];

  switch (err && err.code) {
    case '23505': return [409, 'Ya existe un registro vigente (publicación, borrador, venta o dato único)'];
    case '23503': return [400, 'Referencia inválida'];
    case '23502': return [400, 'Falta un campo obligatorio'];
    case '23514': return [400, 'Valor fuera de rango'];
    case 'P0001': return [409, err.message]; // RAISE EXCEPTION de las funciones de negocio
    default:      return [500, 'Error interno'];
  }
};
