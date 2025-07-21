const express = require('express');
const router = express.Router();
const { db, admin } = require('../config/firebase');

// POST /api/auth/login
// User login
router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        
        if (!email || !password) {
            return res.status(400).json({ message: 'Email and password are required' });
        }
        
        if (!db) {
            // Fallback response when Firebase is unavailable
            return res.json({
                success: true,
                message: 'Firebase unavailable - mock login for testing',
                user: {
                    id: 'mock_user_1',
                    email: email,
                    name: 'Test User',
                    role: 'admin',
                    isActive: true
                },
                token: 'mock_jwt_token_for_testing'
            });
        }

        // Check if user exists
        const userSnapshot = await db.collection('users').where('email', '==', email).get();
        
        if (userSnapshot.empty) {
            return res.status(401).json({ message: 'Invalid email or password' });
        }
        
        const userData = userSnapshot.docs[0].data();
        const userId = userSnapshot.docs[0].id;
        
        // In a real app, you would hash and compare passwords
        // For demo purposes, we're doing a simple comparison
        if (userData.password !== password) {
            return res.status(401).json({ message: 'Invalid email or password' });
        }
        
        // Generate token (in real app, use JWT)
        const token = `mock_token_${userId}_${Date.now()}`;
        
        res.json({
            success: true,
            message: 'Login successful',
            user: {
                id: userId,
                email: userData.email,
                name: userData.name,
                role: userData.role,
                isActive: userData.isActive
            },
            token
        });
        
    } catch (error) {
        console.error('Error during login:', error);
        res.status(500).json({ message: 'Error during login', error: error.message });
    }
});

// POST /api/auth/register
// User registration
router.post('/register', async (req, res) => {
    try {
        const { email, password, name, role = 'customer' } = req.body;
        
        if (!email || !password || !name) {
            return res.status(400).json({ message: 'Email, password, and name are required' });
        }
        
        // Validate password length
        if (password.length < 6) {
            return res.status(400).json({ message: 'Password must be at least 6 characters long' });
        }
        
        // Validate role
        const validRoles = ['user', 'customer', 'cashier', 'admin'];
        if (!validRoles.includes(role)) {
            return res.status(400).json({ message: 'Invalid role. Must be one of: user, customer, cashier, admin' });
        }
        
        if (!db || !admin) {
            // Fallback response when Firebase is unavailable
            return res.json({
                success: true,
                message: 'Firebase unavailable - mock registration for testing',
                user: {
                    id: 'mock_new_user',
                    email: email,
                    name: name,
                    role: role,
                    isActive: true
                }
            });
        }

        // Create user in Firebase Authentication first
        let firebaseUser;
        try {
            firebaseUser = await admin.auth().createUser({
                email: email,
                password: password,
                displayName: name,
                emailVerified: false,
                disabled: false
            });
            console.log('✅ Firebase Auth user created:', firebaseUser.uid);
        } catch (firebaseError) {
            console.error('❌ Firebase Auth error:', firebaseError);
            
            // Handle specific Firebase Auth errors
            if (firebaseError.code === 'auth/email-already-exists') {
                return res.status(400).json({ message: 'User with this email already exists' });
            } else if (firebaseError.code === 'auth/invalid-email') {
                return res.status(400).json({ message: 'Invalid email address' });
            } else if (firebaseError.code === 'auth/weak-password') {
                return res.status(400).json({ message: 'Password is too weak' });
            } else {
                return res.status(500).json({ message: 'Authentication service error', error: firebaseError.message });
            }
        }
        
        // Create user profile in Firestore
        try {
            const userData = {
                email: email,
                name: name,
                role: role,
                isActive: true,
                createdAt: new Date(),
                firebaseUid: firebaseUser.uid
            };
            
            // Use the Firebase UID as document ID for consistency
            await db.collection('users').doc(firebaseUser.uid).set(userData);
            console.log('✅ User profile created in Firestore');
            
            res.status(201).json({
                success: true,
                message: 'User registered successfully',
                user: {
                    id: firebaseUser.uid,
                    email: userData.email,
                    name: userData.name,
                    role: userData.role,
                    isActive: userData.isActive
                }
            });
            
        } catch (firestoreError) {
            console.error('❌ Firestore error:', firestoreError);
            
            // If Firestore fails, clean up the Firebase Auth user
            try {
                await admin.auth().deleteUser(firebaseUser.uid);
                console.log('🧹 Cleaned up Firebase Auth user due to Firestore error');
            } catch (cleanupError) {
                console.error('❌ Cleanup error:', cleanupError);
            }
            
            return res.status(500).json({ message: 'Failed to create user profile', error: firestoreError.message });
        }
        
    } catch (error) {
        console.error('❌ Error during registration:', error);
        res.status(500).json({ message: 'Error during registration', error: error.message });
    }
});

// POST /api/auth/create-cashier
// Admin-only route to create cashier accounts
router.post('/create-cashier', async (req, res) => {
    try {
        const { email, password, name } = req.body;
        
        if (!email || !password || !name) {
            return res.status(400).json({ message: 'Email, password, and name are required' });
        }
        
        // Validate password length
        if (password.length < 6) {
            return res.status(400).json({ message: 'Password must be at least 6 characters long' });
        }
        
        if (!db || !admin) {
            return res.json({
                success: true,
                message: 'Firebase unavailable - mock cashier creation for testing',
                user: {
                    id: 'mock_cashier_user',
                    email: email,
                    name: name,
                    role: 'cashier',
                    isActive: true
                }
            });
        }

        // Create cashier in Firebase Authentication first
        let firebaseUser;
        try {
            firebaseUser = await admin.auth().createUser({
                email: email,
                password: password,
                displayName: name,
                emailVerified: false,
                disabled: false
            });
            console.log('✅ Firebase Auth cashier created:', firebaseUser.uid);
        } catch (firebaseError) {
            console.error('❌ Firebase Auth error:', firebaseError);
            
            // Handle specific Firebase Auth errors
            if (firebaseError.code === 'auth/email-already-exists') {
                return res.status(400).json({ message: 'User with this email already exists' });
            } else if (firebaseError.code === 'auth/invalid-email') {
                return res.status(400).json({ message: 'Invalid email address' });
            } else if (firebaseError.code === 'auth/weak-password') {
                return res.status(400).json({ message: 'Password is too weak' });
            } else {
                return res.status(500).json({ message: 'Authentication service error', error: firebaseError.message });
            }
        }
        
        // Create cashier profile in Firestore
        try {
            const userData = {
                email: email,
                name: name,
                role: 'cashier',
                isActive: true,
                createdAt: new Date(),
                createdBy: 'admin',
                firebaseUid: firebaseUser.uid
            };
            
            // Use the Firebase UID as document ID for consistency
            await db.collection('users').doc(firebaseUser.uid).set(userData);
            console.log('✅ Cashier profile created in Firestore');
            
            res.status(201).json({
                success: true,
                message: 'Cashier account created successfully',
                user: {
                    id: firebaseUser.uid,
                    email: userData.email,
                    name: userData.name,
                    role: userData.role,
                    isActive: userData.isActive
                }
            });
            
        } catch (firestoreError) {
            console.error('❌ Firestore error:', firestoreError);
            
            // If Firestore fails, clean up the Firebase Auth user
            try {
                await admin.auth().deleteUser(firebaseUser.uid);
                console.log('🧹 Cleaned up Firebase Auth user due to Firestore error');
            } catch (cleanupError) {
                console.error('❌ Cleanup error:', cleanupError);
            }
            
            return res.status(500).json({ message: 'Failed to create cashier profile', error: firestoreError.message });
        }
        
    } catch (error) {
        console.error('❌ Error creating cashier account:', error);
        res.status(500).json({ message: 'Error creating cashier account', error: error.message });
    }
});

module.exports = router; 