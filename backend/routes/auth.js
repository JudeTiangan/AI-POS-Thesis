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
        const { email, password, name, role = 'user' } = req.body;
        
        if (!email || !password || !name) {
            return res.status(400).json({ message: 'Email, password, and name are required' });
        }
        
        if (!db) {
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

        // Check if user already exists
        const existingUserSnapshot = await db.collection('users').where('email', '==', email).get();
        
        if (!existingUserSnapshot.empty) {
            return res.status(400).json({ message: 'User with this email already exists' });
        }
        
        // Create new user
        const userData = {
            email,
            password, // In real app, hash this password
            name,
            role,
            isActive: true,
            createdAt: new Date()
        };
        
        const docRef = await db.collection('users').add(userData);
        
        res.status(201).json({
            success: true,
            message: 'User registered successfully',
            user: {
                id: docRef.id,
                email: userData.email,
                name: userData.name,
                role: userData.role,
                isActive: userData.isActive
            }
        });
        
    } catch (error) {
        console.error('Error during registration:', error);
        res.status(500).json({ message: 'Error during registration', error: error.message });
    }
});

module.exports = router; 