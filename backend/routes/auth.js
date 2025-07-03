const express = require('express');
const router = express.Router();
const { db, admin } = require('../config/firebase');

// POST /api/auth/register
// Creates a user in Firebase Auth and a corresponding user profile in Firestore
router.post('/register', async (req, res) => {
    try {
        const { email, password, name } = req.body;

        if (!email || !password || !name) {
            return res.status(400).json({ message: 'Email, password, and name are required.' });
        }

        // 1. Create user in Firebase Authentication
        const userRecord = await admin.auth().createUser({
            email: email,
            password: password,
            displayName: name,
        });

        // 2. Create user profile in Firestore
        // Default role is 'customer'. Admins would need to be created manually or via a separate process.
        const userProfile = {
            uid: userRecord.uid,
            name: name,
            email: email,
            role: 'customer', 
            createdAt: new Date().toISOString(),
        };

        await db.collection('users').doc(userRecord.uid).set(userProfile);

        res.status(201).json({ 
            message: 'User registered successfully', 
            uid: userRecord.uid 
        });

    } catch (error) {
        // Check for specific Firebase auth errors
        if (error.code === 'auth/email-already-exists') {
            return res.status(409).json({ message: 'The email address is already in use by another account.' });
        }
        console.error('Error in user registration:', error);
        res.status(500).json({ message: 'Error registering user', error: error.message });
    }
});

module.exports = router; 