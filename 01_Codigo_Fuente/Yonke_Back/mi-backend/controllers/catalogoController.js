const db = require('../config/db');

// Catálogo de marcas y modelos para registrar vehículos.

const getMarcas = async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT id, nombre FROM marcas_vehiculo WHERE activo ORDER BY nombre`
    );
    res.json(rows);
  } catch (error) {
    console.error('getMarcas', error);
    res.status(500).json({ error: 'Error al obtener marcas' });
  }
};

const getModelos = async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT id, marca_id, nombre FROM modelos_vehiculo WHERE marca_id = $1 ORDER BY nombre`,
      [req.params.marcaId]
    );
    res.json(rows);
  } catch (error) {
    console.error('getModelos', error);
    res.status(500).json({ error: 'Error al obtener modelos' });
  }
};

module.exports = { getMarcas, getModelos };
