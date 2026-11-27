const express = require('express');
const router = express.Router();
const categoryController = require('../controllers/categoryController');

// Obtener todas las categorías de piezas
router.get('/', categoryController.getAllCategories);
// Obtener una categoría por ID
router.get('/:id', categoryController.getCategoryById);
// Crear una nueva categoría
router.post('/', categoryController.createCategory);
// Actualizar una categoría existente
router.put('/:id', categoryController.updateCategory);
// Eliminar una categoría
router.delete('/:id', categoryController.deleteCategory);

module.exports = router;
