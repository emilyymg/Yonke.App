const db = require('../config/db');

// Obtener todos los autos
const getAllAutos = async (req, res) => {
  try {
    // const result = await db.query('SELECT * FROM autos');
    // res.json(result.rows);
    res.json({ message: 'Lista de autos' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al obtener autos' });
  }
};

// Obtener un auto por ID
const getAutoById = async (req, res) => {
  const { id } = req.params;
  try {
    // const result = await db.query('SELECT * FROM autos WHERE id = $1', [id]);
    // res.json(result.rows[0]);
    res.json({ message: `Detalle del auto ${id}` });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al obtener el auto' });
  }
};

// Crear un nuevo auto
const createAuto = async (req, res) => {
  const { usuario_id, marca, modelo, anio, version, vin } = req.body;
  try {
    // await db.query('INSERT INTO autos (...) VALUES (...)', [...]);
    res.status(201).json({ message: 'Auto creado', data: { usuario_id, marca, modelo, anio, version, vin } });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al crear el auto' });
  }
};

// Actualizar un auto existente
const updateAuto = async (req, res) => {
  const { id } = req.params;
  const updates = req.body;
  try {
    // await db.query('UPDATE autos SET ... WHERE id = $1', [id]);
    res.json({ message: `Auto ${id} actualizado`, updates });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al actualizar el auto' });
  }
};

// Eliminar un auto
const deleteAuto = async (req, res) => {
  const { id } = req.params;
  try {
    // await db.query('DELETE FROM autos WHERE id = $1', [id]);
    res.json({ message: `Auto ${id} eliminado` });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al eliminar el auto' });
  }
};

module.exports = {
  getAllAutos,
  getAutoById,
  createAuto,
  updateAuto,
  deleteAuto,
};
