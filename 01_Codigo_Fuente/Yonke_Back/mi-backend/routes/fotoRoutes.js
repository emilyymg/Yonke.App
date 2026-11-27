const express = require('express');
const router = express.Router();
const fotoController = require('../controllers/fotoController');
const auth = require('../middleware/auth');

router.post('/upload-url', auth, fotoController.postUploadUrl);
router.delete('/:id', auth, fotoController.deleteFoto);

module.exports = router;
