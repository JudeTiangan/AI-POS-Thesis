const express = require('express');
const router = express.Router();
const multer = require('multer');
const { db } = require('../config/firebase');

// Configure multer for memory storage
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5 MB
  },
});

// Helper to convert image buffer to base64
const convertImageToBase64 = (file) => {
  if (!file) {
    return null;
  }
  
  // Convert buffer to base64 and include the MIME type
  const base64String = `data:${file.mimetype};base64,${file.buffer.toString('base64')}`;
  return base64String;
};

// GET all items OR an item by barcode
router.get('/', async (req, res) => {
    try {
        const { barcode } = req.query;
        let itemsSnapshot;

        if (barcode) {
            // If barcode query parameter exists, search for that item
            itemsSnapshot = await db.collection('items').where('barcode', '==', barcode).limit(1).get();
        } else {
            // Otherwise, get all items
            itemsSnapshot = await db.collection('items').get();
        }

        const items = [];
        itemsSnapshot.forEach(doc => {
            items.push({ id: doc.id, ...doc.data() });
        });
        
        res.status(200).json(items);
    } catch (error) {
        res.status(500).json({ message: 'Error getting items', error: error.message });
    }
});

// POST a new item with an image
router.post('/', upload.single('image'), async (req, res) => {
    try {
        const { name, description, price, categoryId, barcode, quantity } = req.body;
        if (!name || !price || !categoryId) {
            return res.status(400).json({ message: 'Missing required fields: name, price, categoryId' });
        }

        const imageBase64 = convertImageToBase64(req.file);

        const newItem = {
            name,
            description: description || '',
            price: parseFloat(price),
            categoryId,
            barcode: barcode || '',
            quantity: parseInt(quantity) || 0, // Default to 0 if not provided
            imageUrl: imageBase64 || ''
        };

        const docRef = await db.collection('items').add(newItem);
        res.status(201).json({ id: docRef.id, ...newItem });
    } catch (error) {
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