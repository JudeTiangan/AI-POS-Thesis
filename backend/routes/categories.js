const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');

// GET /api/categories
// Get all categories
router.get('/', async (req, res) => {
    try {
        if (!db) {
            // Fallback response when Firebase is unavailable
            return res.json({
                success: true,
                message: 'Firebase unavailable - returning mock categories for testing',
                categories: [
                    { id: 'mock_1', name: 'Main Dishes', description: 'Primary menu items', isActive: true },
                    { id: 'mock_2', name: 'Beverages', description: 'Drinks and refreshments', isActive: true },
                    { id: 'mock_3', name: 'Desserts', description: 'Sweet treats', isActive: true }
                ]
            });
        }

        const snapshot = await db.collection('categories').orderBy('name').get();
        const categories = [];
        
        snapshot.forEach(doc => {
            categories.push({
                id: doc.id,
                ...doc.data()
            });
        });
        
        res.json({ success: true, categories });
    } catch (error) {
        console.error('Error fetching categories:', error);
        res.status(500).json({ message: 'Error fetching categories', error: error.message });
    }
});

// GET a single category by ID
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const categoryDoc = await db.collection('categories').doc(id).get();
        if (!categoryDoc.exists) {
            return res.status(404).json({ message: 'Category not found' });
        }
        res.status(200).json({ id: categoryDoc.id, ...categoryDoc.data() });
    } catch (error) {
        res.status(500).json({ message: 'Error getting category', error });
    }
});

// POST /api/categories
// Create a new category
router.post('/', async (req, res) => {
    try {
        if (!db) {
            return res.json({
                success: true,
                message: 'Firebase unavailable - mock category creation',
                category: { id: 'mock_new', ...req.body, createdAt: new Date() }
            });
        }

        const { name, description, isActive = true } = req.body;
        
        if (!name) {
            return res.status(400).json({ message: 'Category name is required' });
        }
        
        const categoryData = {
            name,
            description: description || '',
            isActive,
            createdAt: new Date()
        };
        
        const docRef = await db.collection('categories').add(categoryData);
        
        res.status(201).json({
            success: true,
            message: 'Category created successfully',
            category: {
                id: docRef.id,
                ...categoryData
            }
        });
    } catch (error) {
        console.error('Error creating category:', error);
        res.status(500).json({ message: 'Error creating category', error: error.message });
    }
});

// PUT to update a category by ID
router.put('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { name, description } = req.body;
        const categoryRef = db.collection('categories').doc(id);
        const categoryDoc = await categoryRef.get();

        if (!categoryDoc.exists) {
            return res.status(404).json({ message: 'Category not found' });
        }
        
        await categoryRef.update({ name, description });
        res.status(200).json({ message: `Category ${id} updated successfully` });

    } catch (error) {
        res.status(500).json({ message: 'Error updating category', error });
    }
});

// DELETE a category by ID
router.delete('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const categoryRef = db.collection('categories').doc(id);
        const categoryDoc = await categoryRef.get();

        if (!categoryDoc.exists) {
            return res.status(404).json({ message: 'Category not found' });
        }

        await categoryRef.delete();
        res.status(200).json({ message: `Category ${id} deleted successfully` });
    } catch (error) {
        res.status(500).json({ message: 'Error deleting category', error });
    }
});

module.exports = router; 