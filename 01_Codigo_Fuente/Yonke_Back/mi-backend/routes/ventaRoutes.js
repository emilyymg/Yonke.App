const express = require('express');
const router = express.Router();
const ventaController = require('../controllers/ventaController');
const auth = require('../middleware/auth');

router.get('/', auth, ventaController.getVentas);
router.post('/', auth, ventaController.postVenta);
router.post('/:id/devolver', auth, ventaController.devolverVenta);

module.exports = router;
