const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const auth = require('../middleware/auth');

// Públicas
router.post('/', userController.createUser);          // registro
router.post('/login', userController.loginUser);      // login → JWT

// Requieren JWT; solo el propio usuario (el controlador lo verifica)
router.get('/:id', auth, userController.getUserById);
router.put('/:id', auth, userController.updateUser);
router.delete('/:id', auth, userController.deleteUser);

module.exports = router;
