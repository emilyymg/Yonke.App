const express = require('express');
const router = express.Router();
const catalogoController = require('../controllers/catalogoController');
const auth = require('../middleware/auth');

router.get('/marcas', auth, catalogoController.getMarcas);
router.get('/marcas/:marcaId/modelos', auth, catalogoController.getModelos);

module.exports = router;
