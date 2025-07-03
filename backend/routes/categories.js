const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');

// GET all categories
router.get('/', async (req, res) => {
    try {
        const categoriesSnapshot = await db.collection('categories').get();
        const categories = [];
        categoriesSnapshot.forEach(doc => {
            categories.push({ id: doc.id, ...doc.data() });
        });
        res.status(200).json(categories);
    } catch (error) {
        res.status(500).json({ message: 'Error getting categories', error });
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

// POST a new category
router.post('/', async (req, res) => {
    try {
        const { name, description } = req.body;
        if (!name) {
            return res.status(400).json({ message: 'Category name is required' });
        }
        const newCategory = { name, description: description || '' };
        const docRef = await db.collection('categories').add(newCategory);
        res.status(201).json({ id: docRef.id, ...newCategory });
    } catch (error) {
        res.status(500).json({ message: 'Error creating category', error });
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