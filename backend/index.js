const express = require('express');
const cors = require('cors');
const path = require('path');
// Load environment variables from .env file
require('dotenv').config();

// Debug: Log environment variables to see if they're loaded
console.log('🔍 DEBUG: Environment variables loaded:');
console.log('PAYMONGO_SECRET_KEY:', process.env.PAYMONGO_SECRET_KEY ? process.env.PAYMONGO_SECRET_KEY.substring(0, 10) + '...' : 'NOT FOUND');
console.log('PAYMONGO_PUBLIC_KEY:', process.env.PAYMONGO_PUBLIC_KEY ? process.env.PAYMONGO_PUBLIC_KEY.substring(0, 10) + '...' : 'NOT FOUND');

// Initialize Firebase Admin SDK
require('./config/firebase');

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// Middleware
app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? [process.env.FRONTEND_URL, 'https://your-deployed-frontend.com'] 
    : ['http://localhost:3000', 'http://10.0.2.2:3000'],
  credentials: true
}));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Serve static files from public directory
app.use('/public', express.static(path.join(__dirname, 'public')));

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

// Health check endpoint for hosting platforms
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Routes
app.get('/', (req, res) => {
  res.send('🧠 AI-Powered POS System Backend - Ready to serve intelligent recommendations!');
});

// Start the server with proper host binding for cloud platforms
app.listen(PORT, HOST, () => {
  console.log(`🚀 AI POS Backend server is running on ${HOST}:${PORT}`);
  console.log(`🧠 Features: Market Basket Analysis, Customer Analytics, AI Recommendations`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔗 Health check: http://${HOST}:${PORT}/health`);
}); 