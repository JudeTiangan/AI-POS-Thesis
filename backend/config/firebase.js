const admin = require('firebase-admin');

// Production-safe Firebase configuration
let serviceAccount;

if (process.env.NODE_ENV === 'production') {
  // Production: Use environment variables
  if (process.env.FIREBASE_PROJECT_ID) {
    serviceAccount = {
      type: "service_account",
      project_id: process.env.FIREBASE_PROJECT_ID,
      private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
      private_key: process.env.FIREBASE_PRIVATE_KEY ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n') : undefined,
      client_email: process.env.FIREBASE_CLIENT_EMAIL,
      client_id: process.env.FIREBASE_CLIENT_ID,
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
      client_x509_cert_url: process.env.FIREBASE_CLIENT_CERT_URL
    };
  } else {
    console.log("⚠️  Firebase credentials not found in environment variables.");
    console.log("Firebase features will be disabled. PayMongo will work normally.");
  }
} else {
  // Development: Use local file (safe for local development)
  try {
    serviceAccount = require('./serviceAccountKey.json');
  } catch (error) {
    console.log("⚠️  'serviceAccountKey.json' not found. Please add it for local development.");
    console.log("For production, use environment variables instead.");
  }
}

// Initialize Firebase Admin (only if credentials are available)
let db = null;
if (serviceAccount && !admin.apps.length) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL: process.env.FIREBASE_DATABASE_URL || "https://your-project.firebaseio.com"
    });
    db = admin.firestore();
    console.log("✅ Firebase Admin SDK initialized successfully.");
  } catch (error) {
    console.error("❌ Firebase initialization failed:", error.message);
    console.log("🔄 App will continue without Firebase...");
  }
} else if (!serviceAccount) {
  console.log("⚠️  Firebase configuration missing. App will run without Firebase features.");
  console.log("💳 PayMongo payments will work normally.");
}

module.exports = { admin, db }; 