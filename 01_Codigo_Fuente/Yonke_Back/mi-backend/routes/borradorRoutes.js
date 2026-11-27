const express = require('express');
const router = express.Router();
const borradorController = require('../controllers/borradorController');
const auth = require('../middleware/auth');

// Todas requieren JWT y se filtran por el yonque del usuario.
router.get('/', auth, borradorController.getBorradores);
router.post('/', auth, borradorController.postBorrador);
router.get('/:id', auth, borradorController.getBorradorById);
router.put('/:id', auth, borradorController.putBorrador);
router.post('/:id/publicar', auth, borradorController.publicarBorrador);
router.post('/:id/reabrir', auth, borradorController.reabrirBorrador);
router.delete('/:id', auth, borradorController.descartarBorrador);

module.exports = router;
