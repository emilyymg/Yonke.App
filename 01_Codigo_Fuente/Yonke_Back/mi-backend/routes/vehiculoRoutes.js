const express = require('express');
const router = express.Router();
const vehiculoController = require('../controllers/vehiculoController');
const auth = require('../middleware/auth');

router.get('/', auth, vehiculoController.getVehiculos);
router.post('/', auth, vehiculoController.postVehiculo);
router.delete('/:id', auth, vehiculoController.deleteVehiculo);
router.post('/:id/verificacion/confirmar', auth, vehiculoController.confirmarVerificacion);

module.exports = router;
