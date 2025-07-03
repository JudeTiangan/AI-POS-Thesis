const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');

// POST /api/orders
// Creates a new order in Firestore from a shopping cart
router.post('/', async (req, res) => {
    try {
        const { userId, items, totalPrice } = req.body;

        if (!userId || !items || !Array.isArray(items) || items.length === 0 || totalPrice == null) {
            return res.status(400).json({ message: 'Missing required fields: userId, items, and totalPrice.' });
        }

        // Create the main order document
        const orderData = {
            userId: userId,
            createdAt: new Date(),
            totalPrice: totalPrice,
            itemCount: items.length,
        };

        const orderRef = await db.collection('orders').add(orderData);
        
        // In a real application, you might want to store the line items in a subcollection
        // for more detailed querying, but for simplicity, we'll store them directly.
        const orderItems = items.map(item => ({
            orderId: orderRef.id,
            itemId: item.id,
            itemName: item.name,
            price: item.price,
        }));
        
        // Using a batch write to save all order items at once
        const batch = db.batch();
        orderItems.forEach(item => {
            const itemRef = db.collection('orderItems').doc(); // Auto-generate ID
            batch.set(itemRef, item);
        });
        await batch.commit();

        res.status(201).json({ 
            message: 'Order created successfully', 
            orderId: orderRef.id 
        });

    } catch (error) {
        console.error('Error creating order:', error);
        res.status(500).json({ message: 'Error creating order', error: error.message });
    }
});

// GET /api/orders/user/:userId
// Gets all orders for a specific user
router.get('/user/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const ordersSnapshot = await db.collection('orders').where('userId', '==', userId).orderBy('createdAt', 'desc').get();
        
        const orders = [];
        ordersSnapshot.forEach(doc => {
            orders.push({ id: doc.id, ...doc.data() });
        });

        res.status(200).json(orders);
    } catch (error) {
        console.error('Error fetching user orders:', error);
        res.status(500).json({ message: 'Error fetching user orders', error: error.message });
    }
});


module.exports = router; 