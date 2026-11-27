const db = require('../config/db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { withUser } = require('../utils/tx');
const httpError = require('../utils/pgErrors');

const CREDENCIALES_INVALIDAS = 'Credenciales inválidas';
const EMAIL_RX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// ✔️ REGISTRO
// Body: nombre, email, contrasena (>= 8), telefono?, y dirección opcional
// (calle, ciudad, estado obligatorios si se envía dirección; numero, colonia, codigo_postal, referencia).
const createUser = async (req, res) => {
  try {
    const { nombre, email, contrasena, telefono } = req.body;
    const dir = req.body.direccion || {};

    if (!nombre || !email || !contrasena) {
      return res.status(400).json({ error: 'nombre, email y contraseña son obligatorios' });
    }
    if (!EMAIL_RX.test(email)) {
      return res.status(400).json({ error: 'Correo inválido' });
    }
    if (String(contrasena).length < 8) {
      return res.status(400).json({ error: 'La contraseña debe tener al menos 8 caracteres' });
    }
    const rolId = process.env.DEFAULT_ROL_ID;
    if (!rolId) {
      return res.status(500).json({ error: 'Configuración incompleta: falta DEFAULT_ROL_ID' });
    }

    const hashedPassword = await bcrypt.hash(contrasena, 10);
    const tieneDireccion = dir.calle || dir.ciudad || dir.estado;
    if (tieneDireccion && !(dir.calle && dir.ciudad && dir.estado)) {
      return res.status(400).json({ error: 'La dirección requiere calle, ciudad y estado' });
    }

    const usuario = await withUser('', 'Registro de usuario', async (client) => {
      let ubicacionId = null;
      if (tieneDireccion) {
        const u = await client.query(
          `INSERT INTO ubicaciones (calle, numero, colonia, codigo_postal, ciudad, estado, referencia)
           VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
          [dir.calle, dir.numero || null, dir.colonia || null, dir.codigo_postal || null,
           dir.ciudad, dir.estado, dir.referencia || null]
        );
        ubicacionId = u.rows[0].id;
      }
      const r = await client.query(
        `INSERT INTO usuarios (nombre, email, contrasena_hash, telefono, rol_id, ubicacion_id)
         VALUES ($1,$2,$3,$4,$5,$6)
         RETURNING id, nombre, email`,
        [nombre, email, hashedPassword, telefono || null, rolId, ubicacionId]
      );
      return r.rows[0];
    });

    res.status(201).json({ message: 'Usuario creado correctamente', user: usuario });
  } catch (error) {
    const [status, msg] = httpError(error);
    if (status === 500) console.error('createUser', error);
    res.status(status).json({ error: msg });
  }
};

// 🔐 LOGIN
// Body: email, contrasena. Responde { token, user: { id, nombre, email } }.
const loginUser = async (req, res) => {
  try {
    const { email, contrasena } = req.body;
    if (!email || !contrasena) {
      return res.status(400).json({ error: 'email y contraseña son obligatorios' });
    }

    const { rows } = await db.query(
      `SELECT id, nombre, email, contrasena_hash, rol_id, estado
         FROM usuarios WHERE lower(email) = lower($1)`,
      [email]
    );
    const u = rows[0];
    const ok = u && u.estado === 'activo' && await bcrypt.compare(contrasena, u.contrasena_hash);
    if (!ok) return res.status(401).json({ error: CREDENCIALES_INVALIDAS });

    db.query('UPDATE usuarios SET ultimo_acceso = now() WHERE id = $1', [u.id]).catch(() => {});

    const token = jwt.sign({ sub: u.id, rol: u.rol_id }, process.env.JWT_SECRET,
                           { expiresIn: process.env.JWT_EXPIRES_IN || '7d' });
    res.json({ token, user: { id: u.id, nombre: u.nombre, email: u.email } });
  } catch (error) {
    console.error('loginUser', error);
    res.status(500).json({ error: 'Error en login' });
  }
};

// Solo el propio usuario. Sin contrasena_hash.
const getUserById = async (req, res) => {
  try {
    if (req.params.id !== req.user.id) return res.status(403).json({ error: 'No autorizado' });

    const { rows } = await db.query(
      `SELECT id, nombre, email, telefono, rol_id, estado FROM usuarios WHERE id = $1`,
      [req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json(rows[0]);
  } catch (error) {
    console.error('getUserById', error);
    res.status(500).json({ error: 'Error al obtener usuario' });
  }
};

// Solo el propio usuario. Campos editables: nombre, email, telefono.
const updateUser = async (req, res) => {
  try {
    if (req.params.id !== req.user.id) return res.status(403).json({ error: 'No autorizado' });

    const { nombre, email, telefono } = req.body;
    if (email !== undefined && !EMAIL_RX.test(email)) {
      return res.status(400).json({ error: 'Correo inválido' });
    }

    const { rows } = await db.query(
      `UPDATE usuarios
          SET nombre = COALESCE($1, nombre),
              email = COALESCE($2, email),
              telefono = COALESCE($3, telefono),
              fecha_actualizacion = now()
        WHERE id = $4
        RETURNING id, nombre, email, telefono`,
      [nombre ?? null, email ?? null, telefono ?? null, req.user.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json({ message: 'Usuario actualizado', user: rows[0] });
  } catch (error) {
    const [status, msg] = httpError(error);
    if (status === 500) console.error('updateUser', error);
    res.status(status).json({ error: msg });
  }
};

// Solo el propio usuario. Baja lógica: el usuario tiene FKs (yonques, ventas, historial)
// que impiden borrarlo físicamente.
const deleteUser = async (req, res) => {
  try {
    if (req.params.id !== req.user.id) return res.status(403).json({ error: 'No autorizado' });

    await db.query(
      `UPDATE usuarios SET estado = 'inactivo', fecha_actualizacion = now() WHERE id = $1`,
      [req.user.id]
    );
    res.json({ message: 'Cuenta desactivada' });
  } catch (error) {
    console.error('deleteUser', error);
    res.status(500).json({ error: 'Error al desactivar la cuenta' });
  }
};

module.exports = {
  createUser,
  getUserById,
  updateUser,
  deleteUser,
  loginUser,
};
