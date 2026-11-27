const express = require('express');
const router = express.Router();
const autoController = require('../controllers/autoController');

// Obtener todos los autos
router.get('/', autoController.getAllAutos);
// Obtener un auto por ID
router.get('/:id', autoController.getAutoById);
// Crear un nuevo auto
router.post('/', autoController.createAuto);
// Actualizar un auto existente
router.put('/:id', autoController.updateAuto);
// Eliminar un auto
router.delete('/:id', autoController.deleteAuto);

module.exports = router;
