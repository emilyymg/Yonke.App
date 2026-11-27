const express = require('express');
const router = express.Router();
const locationController = require('../controllers/locationController');

// Obtener todas las ubicaciones
router.get('/', locationController.getAllLocations);
// Obtener una ubicación por ID
router.get('/:id', locationController.getLocationById);
// Crear una nueva ubicación
router.post('/', locationController.createLocation);
// Actualizar una ubicación existente
router.put('/:id', locationController.updateLocation);
// Eliminar una ubicación
router.delete('/:id', locationController.deleteLocation);

module.exports = router;
