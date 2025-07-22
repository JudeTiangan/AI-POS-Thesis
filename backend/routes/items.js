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
    console.log('📦 GET /items - Fetching all items');
    const itemsSnapshot = await db.collection('items').get();
    const items = itemsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    console.log(`📦 Successfully fetched ${items.length} items`);
    res.json(items);
    } catch (error) {
    console.error('Error fetching items:', error);
    
    // DEMO FALLBACK: Use local JSON data when Firebase fails
    try {
      const fs = require('fs');
      const path = require('path');
      const localItems = JSON.parse(
        fs.readFileSync(path.join(__dirname, '../data/items.json'), 'utf8')
      );
      console.log('🔄 Using local JSON data for demo (Firebase unavailable)');
      res.json(localItems);
    } catch (fallbackError) {
      console.error('Failed to load local items:', fallbackError);
      res.status(500).json({ 
        message: 'Error fetching items', 
        error: error.message 
      });
    }
  }
});

// POST /api/items
// Create a new item (updated for Firebase Storage + JSON)
router.post('/', async (req, res) => {
    try {
        if (!db) {
            return res.json({
                success: true,
                message: 'Firebase unavailable - mock item creation',
                item: { id: 'mock_new', ...req.body, createdAt: new Date() }
            });
        }

        const { name, description, price, categoryId, barcode, quantity, imageUrl } = req.body;
        
        if (!name || !price || !categoryId) {
            return res.status(400).json({ message: 'Name, price, and categoryId are required' });
        }
        
        const itemData = {
            name,
            description: description || '',
            price: parseFloat(price),

            categoryId,
            barcode: barcode || null,
            quantity: parseInt(quantity) || 0,
            imageUrl: imageUrl || null,
            isActive: true,
            createdAt: new Date()
        };
        
        console.log('📦 Creating item:', itemData);
        const docRef = await db.collection('items').add(itemData);
        
        const responseItem = {
            id: docRef.id,
            ...itemData
        };
        
        console.log('✅ Item created successfully:', responseItem);
        res.status(201).json(responseItem);
        
    } catch (error) {
        console.error('❌ Error creating item:', error);
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

// PUT to update an item by ID (updated for Firebase Storage + JSON)
router.put('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { name, description, price, categoryId, barcode, quantity, imageUrl } = req.body;

        const itemRef = db.collection('items').doc(id);
        const itemDoc = await itemRef.get();

        if (!itemDoc.exists) {
            return res.status(404).json({ message: 'Item not found' });
        }

        const updatedData = {
            name: name || itemDoc.data().name,
            description: description || itemDoc.data().description,
            price: price ? parseFloat(price) : itemDoc.data().price,
            categoryId: categoryId || itemDoc.data().categoryId,
            barcode: barcode || itemDoc.data().barcode,
            quantity: quantity !== undefined ? parseInt(quantity) : itemDoc.data().quantity || 0,
            imageUrl: imageUrl !== undefined ? imageUrl : itemDoc.data().imageUrl,
            updatedAt: new Date()
        };

        console.log('🔄 Updating item:', id, updatedData);
        await itemRef.update(updatedData);
        
        console.log('✅ Item updated successfully:', id);
        res.status(200).json({ message: `Item ${id} updated successfully` });

    } catch (error) {
        console.error('❌ Error updating item:', error);
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