const express = require('express');
const router = express.Router();
const piezaController = require('../controllers/piezaController');
const auth = require('../middleware/auth');

// Todas requieren JWT y se filtran por el yonque del usuario.
router.get('/', auth, piezaController.getPiezas);             // ?estado= &sku= &vehiculo_id=
router.post('/', auth, piezaController.createPieza);          // pieza manual
router.get('/:id', auth, piezaController.getPiezaById);
router.patch('/:id', auth, piezaController.updatePieza);
router.post('/:id/confirmar', auth, piezaController.confirmarPieza);
router.post('/:id/estado', auth, piezaController.cambiarEstadoPieza);
router.post('/:id/descartar', auth, piezaController.descartarPieza);

module.exports = router;
