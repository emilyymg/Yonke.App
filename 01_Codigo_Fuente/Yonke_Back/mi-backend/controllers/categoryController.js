const db = require('../config/db');

// Obtener todas las categorías
const getAllCategories = async (req, res) => {
  try {
    // const result = await db.query('SELECT * FROM categorias_piezas');
    // res.json(result.rows);
    res.json({ message: 'Lista de categorías' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al obtener categorías' });
  }
};

// Obtener categoría por ID
const getCategoryById = async (req, res) => {
  try {
    const { id } = req.params;
    // const result = await db.query('SELECT * FROM categorias_piezas WHERE id = $1', [id]);
    // res.json(result.rows[0]);
    res.json({ message: `Categoría ${id}` });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al obtener categoría' });
  }
};

// Crear nueva categoría
const createCategory = async (req, res) => {
  try {
    const { nombre, categoria_padre_id } = req.body;
    // await db.query('INSERT INTO categorias_piezas (nombre, categoria_padre_id) VALUES ($1, $2)', [nombre, categoria_padre_id]);
    res.status(201).json({ message: 'Categoría creada', data: { nombre, categoria_padre_id } });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al crear categoría' });
  }
};

// Actualizar categoría existente
const updateCategory = async (req, res) => {
  try {
    const { id } = req.params;
    const { nombre, categoria_padre_id } = req.body;
    // await db.query('UPDATE categorias_piezas SET nombre = $1, categoria_padre_id = $2 WHERE id = $3', [nombre, categoria_padre_id, id]);
    res.json({ message: `Categoría ${id} actualizada` });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al actualizar categoría' });
  }
};

// Eliminar categoría
const deleteCategory = async (req, res) => {
  try {
    const { id } = req.params;
    // await db.query('DELETE FROM categorias_piezas WHERE id = $1', [id]);
    res.json({ message: `Categoría ${id} eliminada` });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al eliminar categoría' });
  }
};

module.exports = {
  getAllCategories,
  getCategoryById,
  createCategory,
  updateCategory,
  deleteCategory,
};
