const admin = require('firebase-admin');

// IMPORTANT: This file assumes you have 'serviceAccountKey.json' in this same directory.
try {
  const serviceAccount = require('./serviceAccountKey.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    // TODO: Replace with your actual Firebase Storage bucket URL if it's different
    storageBucket: "thesis-ai-pos.appspot.com" 
  });
  
  console.log('Firebase Admin SDK initialized successfully.');

} catch (error) {
  console.error('Error initializing Firebase Admin SDK:', error);
  if (error.code === 'MODULE_NOT_FOUND') {
    console.log("CRITICAL: 'serviceAccountKey.json' not found in the 'config' folder. Please add it.");
  }
}

const db = admin.firestore();
const bucket = admin.storage().bucket();

module.exports = { db, bucket, admin }; 