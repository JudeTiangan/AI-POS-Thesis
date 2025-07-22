const express = require('express');
const cors = require('cors');
const path = require('path');

// Load environment variables from .env file
require('dotenv').config();

// Startup validation and environment checks
console.log('🚀 Starting AI POS Backend Server...');
console.log('📊 Environment:', process.env.NODE_ENV || 'development');

// Validate critical environment variables
const requiredEnvVars = {
  PAYMONGO_SECRET_KEY: process.env.PAYMONGO_SECRET_KEY,
  PAYMONGO_PUBLIC_KEY: process.env.PAYMONGO_PUBLIC_KEY
};

console.log('🔍 Environment Variables Status:');
Object.entries(requiredEnvVars).forEach(([key, value]) => {
  if (value) {
    console.log(`✅ ${key}: ${value.substring(0, 10)}...`);
  } else {
    console.log(`⚠️  ${key}: NOT SET (will use defaults)`);
  }
});

// Initialize Firebase Admin SDK (with proper error handling)
let firebaseInitialized = false;
try {
  require('./config/firebase');
  firebaseInitialized = true;
  console.log('✅ Firebase configuration loaded successfully');
} catch (error) {
  console.log('⚠️  Firebase configuration failed, continuing without Firebase:', error.message);
}

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// Middleware
app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? true  // Allow all origins in production for demo/testing
    : [
        'http://localhost:3000', 
        'http://10.0.2.2:3000',
        'http://localhost:8080',
        'http://localhost:8081', 
        'http://localhost:3001',
        'http://localhost:60443',  // Flutter web
        'http://localhost:59945',  // Flutter web alternative
        'http://localhost:5000',
        'http://127.0.0.1:8080',
        'http://127.0.0.1:3000'
      ],
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
    environment: process.env.NODE_ENV || 'development',
    firebase: firebaseInitialized ? 'connected' : 'disabled',
    paymongo: process.env.PAYMONGO_SECRET_KEY ? 'configured' : 'not_configured',
    version: '1.0.0'
  });
});

// Routes
app.get('/', (req, res) => {
  res.send('🧠 AI-Powered POS System Backend - Ready to serve intelligent recommendations!');
});

// Global error handler for unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  // Don't exit the process in production
  if (process.env.NODE_ENV !== 'production') {
    process.exit(1);
  }
});

// Global error handler for uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  // Don't exit the process in production
  if (process.env.NODE_ENV !== 'production') {
    process.exit(1);
  }
});

// Start the server with proper host binding for cloud platforms
const server = app.listen(PORT, HOST, () => {
  console.log(`🚀 AI POS Backend server is running on ${HOST}:${PORT}`);
  console.log(`🧠 Features: Market Basket Analysis, Customer Analytics, AI Recommendations`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔥 Firebase: ${firebaseInitialized ? 'Active' : 'Disabled'}`);
  console.log(`💳 PayMongo: ${process.env.PAYMONGO_SECRET_KEY ? 'Configured' : 'Using Defaults'}`);
  console.log(`🔗 Health check: http://${HOST}:${PORT}/health`);
  console.log('✅ Server startup completed successfully!');
});

// Handle server errors
server.on('error', (error) => {
  console.error('❌ Server startup error:', error);
  if (error.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use`);
  }
}); 