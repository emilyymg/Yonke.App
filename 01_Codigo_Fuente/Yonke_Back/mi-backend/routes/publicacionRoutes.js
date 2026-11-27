const express = require('express');
const router = express.Router();
const publicacionController = require('../controllers/publicacionController');
const publicacionesDelYonque = require('../controllers/publicacionesMiasController');
const auth = require('../middleware/auth');

// Yonqueros: publicaciones del propio yonque. Debe ir antes de "/:id".
router.get('/mias', auth, publicacionesDelYonque.getMias);
router.post('/:id/estado', auth, publicacionesDelYonque.cambiarEstado);

// Marketplace público (web).
router.get('/', publicacionController.getAllPublicaciones);
router.get('/:id', publicacionController.getPublicacionById);

module.exports = router;
