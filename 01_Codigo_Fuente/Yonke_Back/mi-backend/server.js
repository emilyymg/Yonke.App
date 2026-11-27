require('dotenv').config();
const express = require('express');
const cors = require('cors');

const userRoutes = require('./routes/userRoutes');
const yonqueRoutes = require('./routes/yonqueRoutes');
const vehiculoRoutes = require('./routes/vehiculoRoutes');
const piezaRoutes = require('./routes/piezaRoutes');
const borradorRoutes = require('./routes/borradorRoutes');
const ventaRoutes = require('./routes/ventaRoutes');
const fotoRoutes = require('./routes/fotoRoutes');
const catalogoRoutes = require('./routes/catalogoRoutes');
const publicacionRoutes = require('./routes/publicacionRoutes');
const autoRoutes = require('./routes/autoRoutes');
const categoryRoutes = require('./routes/categoryRoutes');
const locationRoutes = require('./routes/locationRoutes');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.use('/api/users', userRoutes);
app.use('/api/yonques', yonqueRoutes);
app.use('/api/vehiculos', vehiculoRoutes);
app.use('/api/piezas', piezaRoutes);
app.use('/api/borradores', borradorRoutes);
app.use('/api/ventas', ventaRoutes);
app.use('/api/fotos', fotoRoutes);
app.use('/api/catalogos', catalogoRoutes);
app.use('/api/publicaciones', publicacionRoutes);
app.use('/api/autos', autoRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/locations', locationRoutes);

app.get('/', (req, res) => {
  res.send('API del Yonke funcionando correctamente...');
});

// Errores no capturados por los controladores.
app.use((err, req, res, next) => {
  console.error(err);
  res.status(err.status || 500).json({ error: 'Error interno' });
});

// 127.0.0.1 para que solo sea accesible de forma local.
app.listen(PORT, '127.0.0.1', () => {
  console.log(`API en :${PORT}`);
});
