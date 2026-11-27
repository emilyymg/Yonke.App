const express = require('express');
const router = express.Router();
const yonqueController = require('../controllers/yonqueController');
const auth = require('../middleware/auth');

router.get('/mio', auth, yonqueController.getMio);

module.exports = router;
