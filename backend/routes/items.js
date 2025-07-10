const express = require('express');
const router = express.Router();
const multer = require('multer');
const { db } = require('../config/firebase');

// Configure multer for file uploads
const upload = multer({ 
    dest: 'uploads/',
    limits: { fileSize: 5 * 1024 * 1024 } // 5MB limit
});

// GET /api/items
// Get all items
router.get('/', async (req, res) => {
    try {
        if (!db) {
            // Fallback response when Firebase is unavailable
            return res.json({
                success: true,
                message: 'Firebase unavailable - returning mock items for testing',
                items: [
                    {
                        id: 'mock_1',
                        name: 'Sample Burger',
                        description: 'Delicious test burger',
                        price: 25.00,
                        category: 'Main Dishes',
                        isActive: true,
                        imageUrl: null,
                        stock: 50
                    },
                    {
                        id: 'mock_2', 
                        name: 'Test Coffee',
                        description: 'Premium test coffee',
                        price: 15.00,
                        category: 'Beverages',
                        isActive: true,
                        imageUrl: null,
                        stock: 100
                    }
                ]
            });
        }

        const snapshot = await db.collection('items').orderBy('name').get();
        const items = [];
        
        snapshot.forEach(doc => {
            items.push({
                id: doc.id,
                ...doc.data()
            });
        });
        
        res.json({ success: true, items });
    } catch (error) {
        console.error('Error fetching items:', error);
        res.status(500).json({ message: 'Error fetching items', error: error.message });
    }
});

// POST /api/items
// Create a new item
router.post('/', upload.single('image'), async (req, res) => {
    try {
        if (!db) {
            return res.json({
                success: true,
                message: 'Firebase unavailable - mock item creation',
                item: { id: 'mock_new', ...req.body, createdAt: new Date() }
            });
        }

        const { name, description, price, category, stock } = req.body;
        
        if (!name || !price || !category) {
            return res.status(400).json({ message: 'Name, price, and category are required' });
        }
        
        const itemData = {
            name,
            description: description || '',
            price: parseFloat(price),
            category,
            stock: parseInt(stock) || 0,
            isActive: true,
            imageUrl: null, // Will be updated if image upload is implemented
            createdAt: new Date()
        };
        
        const docRef = await db.collection('items').add(itemData);
        
        res.status(201).json({
            success: true,
            message: 'Item created successfully',
            item: {
                id: docRef.id,
                ...itemData
            }
        });
    } catch (error) {
        console.error('Error creating item:', error);
        res.status(500).json({ message: 'Error creating item', error: error.message });
    }
});

// GET a single item by ID
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const itemDoc = await db.collection('items').doc(id).get();
        if (!itemDoc.exists) {
            return res.status(404).json({ message: 'Item not found' });
        }
        res.status(200).json({ id: itemDoc.id, ...itemDoc.data() });
    } catch (error) {
        res.status(500).json({ message: 'Error getting item', error: error.message });
    }
});

// PUT to update an item by ID
router.put('/:id', upload.single('image'), async (req, res) => {
    try {
        const { id } = req.params;
        const { name, description, price, categoryId, barcode, quantity } = req.body;

        const itemRef = db.collection('items').doc(id);
        const itemDoc = await itemRef.get();

        if (!itemDoc.exists) {
            return res.status(404).json({ message: 'Item not found' });
        }
        
        let imageUrl = itemDoc.data().imageUrl; // Keep old image if new one isn't provided
        if (req.file) {
            imageUrl = convertImageToBase64(req.file);
        }

        const updatedData = {
            name: name || itemDoc.data().name,
            description: description || itemDoc.data().description,
            price: price ? parseFloat(price) : itemDoc.data().price,
            categoryId: categoryId || itemDoc.data().categoryId,
            barcode: barcode || itemDoc.data().barcode,
            quantity: quantity !== undefined ? parseInt(quantity) : itemDoc.data().quantity || 0,
            imageUrl
        };

        await itemRef.update(updatedData);
        res.status(200).json({ message: `Item ${id} updated successfully` });

    } catch (error) {
        res.status(500).json({ message: 'Error updating item', error: error.message });
    }
});

// DELETE an item by ID
router.delete('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const itemRef = db.collection('items').doc(id);
        const itemDoc = await itemRef.get();

        if (!itemDoc.exists) {
            return res.status(404).json({ message: 'Item not found' });
        }

        await itemRef.delete();
        res.status(200).json({ message: `Item ${id} deleted successfully` });
    } catch (error) {
        res.status(500).json({ message: 'Error deleting item', error: error.message });
    }
});

module.exports = router; 