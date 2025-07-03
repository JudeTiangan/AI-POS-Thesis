const express = require('express');
const cors = require('cors');
// Load environment variables from .env file
require('dotenv').config();
// Initialize Firebase Admin SDK
require('./config/firebase');

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Import routes
const categoryRoutes = require('./routes/categories');
const itemRoutes = require('./routes/items');
const recommendationRoutes = require('./routes/recommendations');
const authRoutes = require('./routes/auth');
const orderRoutes = require('./routes/orders');
const analyticsRoutes = require('./routes/analytics');

// Use routes
app.use('/api/categories', categoryRoutes);
app.use('/api/items', itemRoutes);
app.use('/api/recommendations', recommendationRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/analytics', analyticsRoutes);

// Routes
app.get('/', (req, res) => {
  res.send('🧠 AI-Powered POS System Backend - Ready to serve intelligent recommendations!');
});

// TODO: Add other routes for API endpoints (items, categories, users, etc.)

// Start the server
app.listen(port, () => {
  console.log(`🚀 AI POS Backend server is running on port ${port}`);
  console.log(`🧠 Features: Market Basket Analysis, Customer Analytics, AI Recommendations`);
}); 