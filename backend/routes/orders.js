const express = require('express');
const path = require('path');
const router = express.Router();
const { db } = require('../config/firebase');
const { PayMongoAPI } = require('../config/paymongo');
const { paypalAPI, getRedirectUrls } = require('../config/paypal');
const { paypalDemoAPI } = require('../config/paypal-demo');

// Initialize PayMongo
const payMongo = new PayMongoAPI();

// POST /api/orders
// Creates a new order with enhanced features (online ordering, payment, delivery)
router.post('/', async (req, res) => {
    try {
        const { 
            userId, 
            items, 
            totalPrice, 
            orderType, 
            paymentMethod, 
            deliveryAddress,
            deliveryInstructions,
            customerName,
            customerEmail,
            customerPhone
        } = req.body;

        // Validate required fields
        if (!userId || !items || !totalPrice || !orderType || !paymentMethod || !customerName || !customerEmail) {
            return res.status(400).json({ message: 'Missing required fields' });
        }

        // Debug delivery instructions (simplified)
        if (orderType === 'delivery') {
            console.log('✅ DELIVERY INSTRUCTIONS:', deliveryInstructions);
        }

        // Validate delivery address for delivery orders
        if (orderType === 'delivery' && (!deliveryAddress || !deliveryAddress.street || !deliveryAddress.city)) {
            return res.status(400).json({ message: 'Delivery address is required for delivery orders' });
        }

        // Validate minimum amount for GCash payments (PayMongo requirement)
        if (paymentMethod === 'gcash' && totalPrice < 20) {
            return res.status(400).json({ 
                message: 'Minimum amount for GCash payments is ₱20.00', 
                currentAmount: totalPrice,
                minimumAmount: 20
            });
        }

        // Create order data
        const orderData = {
            userId: userId,
            items: items,
            totalPrice: totalPrice,
            orderType: orderType,
            orderStatus: 'pending',
            paymentMethod: paymentMethod,
            paymentStatus: paymentMethod === 'cash' ? 'pending' : 'pending', // GCash will be updated after payment
            deliveryAddress: deliveryAddress || null,
            deliveryInstructions: deliveryInstructions !== undefined ? deliveryInstructions : null,
            estimatedReadyTime: null, // Will be set by admin
            completedAt: null,
            paymentTransactionId: null, // Will be set after payment
            paymentIntentId: null, // For PayMongo tracking
            adminNotes: null,
            customerName: customerName,
            customerEmail: customerEmail,
            customerPhone: customerPhone || null,
            createdAt: new Date(),
        };

        let orderId = 'temp_' + Date.now(); // Fallback ID if Firebase unavailable
        
        // Save to Firebase if available
        if (db) {
            const orderRef = await db.collection('orders').add(orderData);
            orderId = orderRef.id;
        } else {
            console.log('⚠️  Firebase unavailable - using temporary order ID for PayMongo testing');
        }
        
        // Handle payment processing based on payment method
        let paymentUrl = null;
        let paymentSourceId = null;
        let paypalOrderId = null;
        
        if (paymentMethod === 'gcash') {
            const paymentResult = await createGCashPayment(orderId, totalPrice, customerName, customerEmail, items);
            
            if (paymentResult.success) {
                paymentUrl = paymentResult.paymentUrl;
                paymentSourceId = paymentResult.paymentSourceId;
                
                // Update order with payment source ID (if Firebase available)
                if (db) {
                    const orderRef = db.collection('orders').doc(orderId);
                    await orderRef.update({ paymentSourceId: paymentSourceId });
                }
            } else {
                // If payment creation fails, delete the order and return error (if Firebase available)
                if (db) {
                    const orderRef = db.collection('orders').doc(orderId);
                    await orderRef.delete();
                }
                return res.status(500).json({ 
                    message: 'Failed to create GCash payment', 
                    error: paymentResult.error 
                });
            }
        } else if (paymentMethod === 'paypal') {
            console.log('🎭 Starting PayPal payment creation...');
            console.log('🎭 Order ID:', orderId);
            console.log('🎭 Amount:', totalPrice);
            console.log('🎭 Customer:', customerName, customerEmail);
            
            try {
                // Use demo PayPal API for thesis presentation
                const paymentResult = await createDemoPayPalPayment(orderId, totalPrice, customerName, customerEmail, items);
                
                console.log('🎭 PayPal payment result:', paymentResult);
            } catch (error) {
                console.error('❌ PayPal payment creation error:', error);
                return res.status(500).json({ 
                    message: 'PayPal payment creation failed', 
                    error: error.message 
                });
            }
            
            if (paymentResult.success) {
                paymentUrl = paymentResult.paymentUrl;
                paypalOrderId = paymentResult.orderId;
                paymentSourceId = paypalOrderId; // Set paymentSourceId for PayPal
                
                console.log('✅ PayPal payment created successfully');
                console.log('🔗 PayPal URL:', paymentUrl);
                console.log('🆔 PayPal Order ID:', paypalOrderId);
                console.log('🆔 Payment Source ID:', paymentSourceId);
                
                // Update order with PayPal order ID (if Firebase available)
                if (db) {
                    const orderRef = db.collection('orders').doc(orderId);
                    await orderRef.update({ 
                        paypalOrderId: paypalOrderId,
                        paymentSourceId: paypalOrderId // Use PayPal order ID as payment source ID
                    });
                    console.log('✅ Order updated with PayPal details');
                }
            } else {
                console.error('❌ PayPal payment creation failed:', paymentResult.error);
                // If payment creation fails, delete the order and return error (if Firebase available)
                if (db) {
                    const orderRef = db.collection('orders').doc(orderId);
                    await orderRef.delete();
                }
                return res.status(500).json({ 
                    message: 'Failed to create PayPal payment', 
                    error: paymentResult.error 
                });
            }
        }
        
        // Update customer analytics for AI recommendations (if Firebase available)
        if (db) {
            await updateCustomerAnalytics(userId, items);
        }

        const response = { 
            success: true,
            message: db ? 'Order created successfully' : 'PayMongo payment test successful (Firebase disabled)', 
            order: { id: orderId, ...orderData, paymentSourceId }
        };

        // Add payment URL and paymentSourceId if applicable
        if (paymentUrl) {
            response.paymentUrl = paymentUrl;
        }
        
        // Add paymentSourceId at the top level for frontend compatibility
        if (paymentSourceId) {
            response.paymentSourceId = paymentSourceId;
        }

        res.status(201).json(response);

    } catch (error) {
        console.error('Error creating order:', error);
        res.status(500).json({ message: 'Error creating order', error: error.message });
    }
});

// Real PayMongo GCash Payment Integration
async function createGCashPayment(orderId, amount, customerName, customerEmail, items) {
    try {
        console.log('🔄 Creating PayMongo GCash payment for order:', orderId);
        console.log('💰 Amount:', amount, 'PHP');
        console.log('👤 Customer:', customerName, customerEmail);
        
        // Create payment intent
        const paymentData = {
            amount: amount,
            currency: 'PHP',
            description: `GENSUGGEST POS Order #${orderId}`,
            metadata: {
                orderId: String(orderId),
                customerName: String(customerName || 'Anonymous'),
                customerEmail: String(customerEmail || 'no-email'),
                itemCount: String(items.length)
            }
        };

        const paymentResult = await payMongo.createGCashPayment(paymentData);
        
        if (!paymentResult.success) {
            throw new Error(`GCash payment creation failed: ${JSON.stringify(paymentResult.error)}`);
        }

        const paymentSource = paymentResult.paymentIntent;
        const paymentUrl = paymentResult.paymentUrl;
        
        console.log('✅ GCash payment source created:', paymentSource.id);
        console.log('🔗 Payment URL generated:', paymentUrl);

        if (!paymentUrl) {
            throw new Error('No payment URL returned from PayMongo');
        }

        return {
            success: true,
            paymentUrl: paymentUrl,
            paymentSourceId: paymentSource.id
        };
        
    } catch (error) {
        console.error('❌ PayMongo GCash payment error:', error);
        return {
            success: false,
            error: error.message
        };
    }
}

// Demo PayPal Payment Integration for Thesis Presentation
async function createDemoPayPalPayment(orderId, amount, customerName, customerEmail, items) {
    try {
        console.log('🔄 Creating PayPal payment for order:', orderId);
        console.log('💰 Amount:', amount, 'PHP');
        console.log('👤 Customer:', customerName, customerEmail);
        console.log('📦 Items count:', items.length);
        
        // Check if paypalDemoAPI is available
        if (!paypalDemoAPI) {
            console.error('❌ paypalDemoAPI is not available');
            throw new Error('PayPal Demo API not initialized');
        }
        
        console.log('✅ paypalDemoAPI is available');
        
        // Get redirect URLs
        const redirectUrls = getRedirectUrls();
        console.log('🔄 Redirect URLs:', redirectUrls);
        
        // Create PayPal order
        const paymentData = {
            amount: amount,
            currency: 'PHP',
            description: `GENSUGGEST POS Order #${orderId}`,
            metadata: {
                orderId: String(orderId),
                customerName: String(customerName || 'Anonymous'),
                customerEmail: String(customerEmail || 'no-email'),
                itemCount: String(items.length)
            },
            returnUrl: redirectUrls.success,
            cancelUrl: redirectUrls.cancel
        };

        console.log('🎭 Calling paypalDemoAPI.createPayPalOrder with data:', paymentData);
        
        let paymentResult;
        try {
            paymentResult = await paypalDemoAPI.createPayPalOrder(paymentData);
            console.log('🎭 PayPal API response:', paymentResult);
        } catch (apiError) {
            console.error('❌ PayPal API call failed:', apiError);
            throw apiError;
        }
        
        if (!paymentResult.success) {
            console.error('❌ PayPal API returned failure:', paymentResult.error);
            throw new Error(`PayPal payment creation failed: ${JSON.stringify(paymentResult.error)}`);
        }

        const paypalOrderId = paymentResult.orderId;
        const paymentUrl = paymentResult.paymentUrl;
        
        console.log('✅ PayPal order created:', paypalOrderId);
        console.log('🔗 Payment URL generated:', paymentUrl);

        if (!paymentUrl) {
            console.error('❌ No payment URL returned from PayPal API');
            throw new Error('No payment URL returned from PayPal');
        }

        console.log('✅ PayPal payment creation successful');
        return {
            success: true,
            paymentUrl: paymentUrl,
            orderId: paypalOrderId
        };
        
    } catch (error) {
        console.error('❌ PayPal payment error:', error);
        return {
            success: false,
            error: error.message
        };
    }
}

// POST /api/orders/paymongo/webhook
// Webhook endpoint for PayMongo payment notifications
router.post('/paymongo/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
    try {
        const signature = req.headers['paymongo-signature'];
        const payload = req.body;
        
        // Verify webhook signature for security
        if (!payMongo.verifyWebhookSignature(payload.toString(), signature)) {
            console.error('❌ Invalid webhook signature');
            return res.status(401).json({ message: 'Invalid webhook signature' });
        }
        
        const event = JSON.parse(payload);
        console.log('📨 PayMongo webhook received:', event.data.type);
        
        // Handle source events (for GCash payments)
        if (event.data.type === 'source.chargeable') {
            await handlePaymentSuccess(event.data.attributes);
        } else if (event.data.type === 'payment.paid') {
            await handlePaymentSuccess(event.data.attributes);
        } else if (event.data.type === 'payment.failed') {
            await handlePaymentFailure(event.data.attributes);
        }
        
        res.status(200).json({ message: 'Webhook processed successfully' });
        
    } catch (error) {
        console.error('❌ Error processing PayMongo webhook:', error);
        res.status(500).json({ message: 'Error processing webhook' });
    }
});

// POST /api/orders/paypal/webhook
// Webhook endpoint for PayPal payment notifications
router.post('/paypal/webhook', express.json(), async (req, res) => {
    try {
        const payload = req.body;
        const signature = req.headers['paypal-transmission-sig'];
        
        // Verify webhook signature for security
        if (!paypalAPI.verifyWebhookSignature(payload, signature)) {
            console.error('❌ Invalid PayPal webhook signature');
            return res.status(401).json({ message: 'Invalid webhook signature' });
        }
        
        console.log('📨 PayPal webhook received:', payload.event_type);
        
        // Handle PayPal events
        if (payload.event_type === 'PAYMENT.CAPTURE.COMPLETED') {
            await handlePayPalPaymentSuccess(payload.resource);
        } else if (payload.event_type === 'PAYMENT.CAPTURE.DENIED') {
            await handlePayPalPaymentFailure(payload.resource);
        }
        
        res.status(200).json({ message: 'PayPal webhook processed successfully' });
        
    } catch (error) {
        console.error('❌ Error processing PayPal webhook:', error);
        res.status(500).json({ message: 'Error processing webhook' });
    }
});

// POST /api/orders/paypal/capture/:orderId
// Capture PayPal payment after customer approval
router.post('/paypal/capture/:orderId', async (req, res) => {
    try {
        const { orderId } = req.params;
        
        console.log('🔄 Capturing PayPal payment for order:', orderId);
        
        const captureResult = await paypalAPI.capturePayment(orderId);
        
        if (!captureResult.success) {
            console.error('❌ PayPal capture failed:', captureResult.error);
            return res.status(500).json({ 
                success: false, 
                message: 'Failed to capture PayPal payment', 
                error: captureResult.error 
            });
        }
        
        console.log('✅ PayPal payment captured successfully:', captureResult.captureId);
        
        // Update order payment status (if Firebase available)
        if (db) {
            const updateData = {
                paymentStatus: 'paid',
                paymentTransactionId: captureResult.captureId,
                paidAt: new Date()
            };
            
            await db.collection('orders').doc(orderId).update(updateData);
        }
        
        res.json({ 
            success: true, 
            message: 'Payment captured successfully',
            captureId: captureResult.captureId
        });
        
    } catch (error) {
        console.error('❌ Error capturing PayPal payment:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Error capturing payment', 
            error: error.message 
        });
    }
});

// Handle PayPal payment success
async function handlePayPalPaymentSuccess(paymentData) {
    try {
        const orderId = paymentData.custom_id || paymentData.invoice_id;
        const transactionId = paymentData.id;
        
        if (!orderId) {
            console.error('❌ No order ID in PayPal payment data');
            return;
        }

        // Update order payment status (if Firebase available)
        if (db) {
            const updateData = {
                paymentStatus: 'paid',
                paymentTransactionId: transactionId,
                paidAt: new Date()
            };
            
            await db.collection('orders').doc(orderId).update(updateData);
        }
        
        console.log(`✅ Order ${orderId} PayPal payment successful - Transaction: ${transactionId}`);
        
    } catch (error) {
        console.error('❌ Error handling PayPal payment success:', error);
    }
}

// Handle PayPal payment failure
async function handlePayPalPaymentFailure(paymentData) {
    try {
        const orderId = paymentData.custom_id || paymentData.invoice_id;
        
        if (!orderId) {
            console.error('❌ No order ID in PayPal payment data');
            return;
        }

        // Update order payment status (if Firebase available)
        if (db) {
            const updateData = {
                paymentStatus: 'failed',
                failedAt: new Date()
            };
            
            await db.collection('orders').doc(orderId).update(updateData);
        }
        
        console.log(`❌ Order ${orderId} PayPal payment failed`);
        
    } catch (error) {
        console.error('❌ Error handling PayPal payment failure:', error);
    }
}

// Handle successful payment
async function handlePaymentSuccess(paymentData) {
    try {
        const orderId = paymentData.metadata?.orderId;
        const transactionId = paymentData.id || paymentData.payments?.[0]?.id;
        
        if (!orderId) {
            console.error('❌ No order ID in payment metadata');
            return;
        }

        // Update order payment status (if Firebase available)
        if (db) {
            const updateData = {
                paymentStatus: 'paid',
                paymentTransactionId: transactionId,
                paidAt: new Date()
            };
            
            await db.collection('orders').doc(orderId).update(updateData);
        }
        
        console.log(`✅ Order ${orderId} payment successful - Transaction: ${transactionId}`);
        
    } catch (error) {
        console.error('❌ Error handling payment success:', error);
    }
}

// Handle failed payment
async function handlePaymentFailure(paymentData) {
    try {
        const orderId = paymentData.metadata?.orderId;
        
        if (!orderId) {
            console.error('❌ No order ID in payment metadata');
            return;
        }

        // Update order payment status (if Firebase available)
        if (db) {
            const updateData = {
                paymentStatus: 'failed',
                failedAt: new Date()
            };
            
            await db.collection('orders').doc(orderId).update(updateData);
        }
        
        console.log(`❌ Order ${orderId} payment failed`);
        
    } catch (error) {
        console.error('❌ Error handling payment failure:', error);
    }
}

// GET /api/orders/payment-status/:paymentSourceId
// Check payment status manually (for polling if needed)
router.get('/payment-status/:paymentSourceId', async (req, res) => {
    try {
        const { paymentSourceId } = req.params;
        
        console.log('🔍 Checking payment status for source:', paymentSourceId);
        
        const result = await payMongo.getPaymentStatus(paymentSourceId);
        
        console.log('💳 PayMongo response:', JSON.stringify(result, null, 2));
        
        if (!result.success) {
            console.error('❌ PayMongo API error:', result.error);
            return res.status(500).json({ 
                success: false, 
                message: 'Failed to check payment status', 
                error: result.error 
            });
        }

        const paymentSource = result.paymentIntent;
        const status = paymentSource.attributes?.status || 'unknown';
        
        console.log('📊 Payment status:', status);
        
        res.json({
            success: true,
            status: status,
            paymentSource: paymentSource
        });
        
    } catch (error) {
        console.error('❌ Error checking payment status:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Error checking payment status', 
            error: error.message 
        });
    }
});

// Helper function to update customer analytics
async function updateCustomerAnalytics(userId, items) {
    try {
        console.log('🔄 Updating customer analytics for user:', userId);
        console.log('📊 Order items:', items);
        
        const analyticsRef = db.collection('customerAnalytics').doc(userId);
        const analyticsDoc = await analyticsRef.get();
        
        // Get all orders for this user to calculate comprehensive analytics
        const userOrdersSnapshot = await db.collection('orders')
            .where('userId', '==', userId)
            .get();
        
        const allOrders = [];
        userOrdersSnapshot.forEach(doc => {
            allOrders.push({ id: doc.id, ...doc.data() });
        });
        
        console.log('📋 Found', allOrders.length, 'total orders for user');
        
        // Calculate comprehensive analytics
        const itemPurchaseFrequency = {};
        const categoryPreferences = {};
        const purchaseHistory = [];
        let totalOrderValue = 0;
        let totalOrders = allOrders.length;
        let lastPurchaseDate = new Date();
        
        // Process all orders to build analytics
        for (const order of allOrders) {
            if (order.items && Array.isArray(order.items)) {
                const orderCategories = [];
                const orderItemIds = [];
                
                // Process each item in the order
                for (const item of order.items) {
                    const itemId = item.itemId || item.id;
                    if (itemId) {
                        // Update item frequency
                        itemPurchaseFrequency[itemId] = (itemPurchaseFrequency[itemId] || 0) + (item.quantity || 1);
                        orderItemIds.push(itemId);
                        
                        // Get item details to find category
                        try {
                            const itemDoc = await db.collection('items').doc(itemId).get();
                            if (itemDoc.exists) {
                                const itemData = itemDoc.data();
                                if (itemData.categoryId) {
                                    orderCategories.push(itemData.categoryId);
                                    // Update category preferences
                                    categoryPreferences[itemData.categoryId] = (categoryPreferences[itemData.categoryId] || 0) + 1;
                                }
                            }
                        } catch (error) {
                            console.log('Could not fetch item details for:', itemId);
                        }
                    }
                }
                
                // Add to purchase history
                purchaseHistory.push({
                    orderId: order.id,
                    itemIds: orderItemIds,
                    timestamp: order.createdAt ? (order.createdAt.toDate ? order.createdAt.toDate().toISOString() : order.createdAt) : new Date().toISOString(),
                    totalAmount: order.totalPrice || 0,
                    categories: [...new Set(orderCategories)] // Remove duplicates
                });
                
                totalOrderValue += order.totalPrice || 0;
                
                // Update last purchase date
                const orderDate = order.createdAt ? (order.createdAt.toDate ? order.createdAt.toDate() : new Date(order.createdAt)) : new Date();
                if (orderDate > lastPurchaseDate) {
                    lastPurchaseDate = orderDate;
                }
            }
        }
        
        // Calculate average order value
        const averageOrderValue = totalOrders > 0 ? totalOrderValue / totalOrders : 0;
        
        // Find frequent items (top 5 most purchased)
        const frequentItems = Object.entries(itemPurchaseFrequency)
            .sort(([,a], [,b]) => b - a)
            .slice(0, 5)
            .map(([itemId]) => itemId);
        
        // Normalize category preferences to percentages
        const totalCategoryCount = Object.values(categoryPreferences).reduce((sum, count) => sum + count, 0);
        if (totalCategoryCount > 0) {
            Object.keys(categoryPreferences).forEach(categoryId => {
                categoryPreferences[categoryId] = categoryPreferences[categoryId] / totalCategoryCount;
            });
        }
        
        // Simple association rules (items bought together)
        const associationRules = {};
        for (const purchase of purchaseHistory) {
            if (purchase.itemIds.length > 1) {
                for (const itemId of purchase.itemIds) {
                    if (!associationRules[itemId]) {
                        associationRules[itemId] = [];
                    }
                    for (const otherItemId of purchase.itemIds) {
                        if (itemId !== otherItemId && !associationRules[itemId].includes(otherItemId)) {
                            associationRules[itemId].push(otherItemId);
                        }
                    }
                }
            }
        }
        
        // Create the analytics object matching the frontend model
        const customerAnalytics = {
            customerId: userId,
            itemPurchaseFrequency: itemPurchaseFrequency,
            purchaseHistory: purchaseHistory,
            categoryPreferences: categoryPreferences,
            lastPurchase: lastPurchaseDate.toISOString(),
            averageOrderValue: averageOrderValue,
            totalOrders: totalOrders,
            frequentItems: frequentItems,
            associationRules: associationRules,
            updatedAt: new Date().toISOString()
        };
        
        console.log('✅ Customer analytics calculated:', {
            totalOrders,
            totalItems: Object.keys(itemPurchaseFrequency).length,
            averageOrderValue,
            frequentItemsCount: frequentItems.length
        });
        
        // Save to Firestore
        await analyticsRef.set(customerAnalytics);
        console.log('✅ Customer analytics saved to Firestore');
        
    } catch (error) {
        console.error('❌ Error updating customer analytics:', error);
        // Don't fail the order if analytics update fails
    }
}

// POST /api/orders/regenerate-analytics
// Manually regenerate customer analytics for all users (admin debugging tool)
router.post('/regenerate-analytics', async (req, res) => {
    try {
        console.log('🔄 Starting manual regeneration of all customer analytics...');
        
        // Get all orders
        const ordersSnapshot = await db.collection('orders').get();
        const userOrdersMap = new Map();
        
        // Group orders by user
        ordersSnapshot.forEach(doc => {
            const order = { id: doc.id, ...doc.data() };
            const userId = order.userId;
            
            if (userId) {
                if (!userOrdersMap.has(userId)) {
                    userOrdersMap.set(userId, []);
                }
                userOrdersMap.get(userId).push(order);
            }
        });
        
        console.log(`📊 Found ${userOrdersMap.size} unique customers with orders`);
        
        let successCount = 0;
        let errorCount = 0;
        
        // Regenerate analytics for each user
        for (const [userId, orders] of userOrdersMap) {
            try {
                console.log(`🔄 Processing analytics for user: ${userId} (${orders.length} orders)`);
                
                // Get all items from all orders for this user
                const allItems = [];
                for (const order of orders) {
                    if (order.items && Array.isArray(order.items)) {
                        allItems.push(...order.items);
                    }
                }
                
                if (allItems.length > 0) {
                    await updateCustomerAnalytics(userId, allItems);
                    successCount++;
                    console.log(`✅ Analytics updated for user: ${userId}`);
                } else {
                    console.log(`⚠️ No items found for user: ${userId}`);
                }
                
            } catch (userError) {
                console.error(`❌ Error processing user ${userId}:`, userError);
                errorCount++;
            }
        }
        
        console.log(`🎉 Analytics regeneration complete! Success: ${successCount}, Errors: ${errorCount}`);
        
        res.status(200).json({
            message: 'Customer analytics regeneration completed',
            totalUsers: userOrdersMap.size,
            successCount: successCount,
            errorCount: errorCount,
            details: {
                totalOrders: ordersSnapshot.size,
                usersProcessed: userOrdersMap.size
            }
        });
        
    } catch (error) {
        console.error('❌ Error regenerating customer analytics:', error);
        res.status(500).json({ 
            message: 'Error regenerating customer analytics', 
            error: error.message 
        });
    }
});

// GET /api/orders/user/:userId
// Gets all orders for a specific user
router.get('/user/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const ordersSnapshot = await db.collection('orders')
            .where('userId', '==', userId)
            .orderBy('createdAt', 'desc')
            .get();
        
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

// GET /api/orders/admin
// Gets all orders for admin management
router.get('/admin', async (req, res) => {
    try {
        const { status, orderType, limit = 50 } = req.query;
        
        let query = db.collection('orders').orderBy('createdAt', 'desc').limit(parseInt(limit));
        
        if (status) {
            query = query.where('orderStatus', '==', status);
        }
        
        if (orderType) {
            query = query.where('orderType', '==', orderType);
        }
        
        const ordersSnapshot = await query.get();
        
        const orders = [];
        ordersSnapshot.forEach(doc => {
            orders.push({ id: doc.id, ...doc.data() });
        });

        res.status(200).json(orders);
    } catch (error) {
        console.error('Error fetching admin orders:', error);
        res.status(500).json({ message: 'Error fetching admin orders', error: error.message });
    }
});

// PUT /api/orders/:orderId/status
// Updates order status (admin only)
router.put('/:orderId/status', async (req, res) => {
    try {
        const { orderId } = req.params;
        const { orderStatus, adminNotes, estimatedReadyTime } = req.body;
        
        if (!orderStatus || !['pending', 'preparing', 'ready', 'completed', 'cancelled'].includes(orderStatus)) {
            return res.status(400).json({ message: 'Invalid orderStatus.' });
        }
        
        const updateData = {
            orderStatus: orderStatus,
            adminNotes: adminNotes || null,
        };
        
        if (estimatedReadyTime) {
            updateData.estimatedReadyTime = new Date(estimatedReadyTime);
        }
        
        if (orderStatus === 'completed') {
            updateData.completedAt = new Date();
        }
        
        await db.collection('orders').doc(orderId).update(updateData);
        
        res.status(200).json({ message: 'Order status updated successfully' });
    } catch (error) {
        console.error('Error updating order status:', error);
        res.status(500).json({ message: 'Error updating order status', error: error.message });
    }
});

// PUT /api/orders/:orderId/payment
// Updates payment status (for GCash integration)
router.put('/:orderId/payment', async (req, res) => {
    try {
        const { orderId } = req.params;
        const { paymentStatus, paymentTransactionId } = req.body;
        
        if (!paymentStatus || !['pending', 'paid', 'failed', 'refunded'].includes(paymentStatus)) {
            return res.status(400).json({ message: 'Invalid paymentStatus.' });
        }
        
        const updateData = {
            paymentStatus: paymentStatus,
        };
        
        if (paymentTransactionId) {
            updateData.paymentTransactionId = paymentTransactionId;
        }
        
        await db.collection('orders').doc(orderId).update(updateData);
        
        res.status(200).json({ message: 'Payment status updated successfully' });
    } catch (error) {
        console.error('Error updating payment status:', error);
        res.status(500).json({ message: 'Error updating payment status', error: error.message });
    }
});

// GET /api/orders/:orderId
// Gets a specific order by ID
router.get('/:orderId', async (req, res) => {
    try {
        const { orderId } = req.params;
        const orderDoc = await db.collection('orders').doc(orderId).get();
        
        if (!orderDoc.exists) {
            return res.status(404).json({ message: 'Order not found' });
        }
        
        res.status(200).json({ id: orderDoc.id, ...orderDoc.data() });
    } catch (error) {
        console.error('Error fetching order:', error);
        res.status(500).json({ message: 'Error fetching order', error: error.message });
    }
});

// PayPal Demo Checkout Page
router.get('/paypal-demo.html', (req, res) => {
    res.sendFile(path.join(__dirname, '../public/paypal-demo.html'));
});

// Payment redirect routes
router.get('/payment-success', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>Payment Successful - PayPal</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body { 
                    font-family: 'Helvetica Neue', Arial, sans-serif; 
                    text-align: center; 
                    padding: 50px; 
                    background: #f7f9fa;
                    margin: 0;
                }
                .success-container {
                    max-width: 500px;
                    margin: 0 auto;
                    background: white;
                    border-radius: 8px;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
                    padding: 40px;
                }
                .success-icon { 
                    color: #28a745; 
                    font-size: 48px; 
                    margin-bottom: 20px; 
                }
                .success-title { 
                    color: #28a745; 
                    font-size: 24px; 
                    margin-bottom: 20px; 
                    font-weight: bold;
                }
                .message { 
                    font-size: 16px; 
                    margin-bottom: 20px; 
                    color: #6b7c93;
                }
                .order-details {
                    background: #f7f9fa;
                    padding: 20px;
                    border-radius: 4px;
                    margin: 20px 0;
                    text-align: left;
                }
                .order-detail {
                    display: flex;
                    justify-content: space-between;
                    margin-bottom: 10px;
                    font-size: 14px;
                }
                .close-btn { 
                    background: #0070ba; 
                    color: white; 
                    padding: 12px 24px; 
                    border: none; 
                    border-radius: 4px; 
                    cursor: pointer;
                    font-size: 16px;
                    font-weight: bold;
                }
                .close-btn:hover {
                    background: #005ea6;
                }
            </style>
        </head>
        <body>
            <div class="success-container">
                <div class="success-icon">✅</div>
                <div class="success-title">Payment Successful!</div>
                <div class="message">Your PayPal payment has been processed successfully.</div>
                
                <div class="order-details">
                    <div class="order-detail">
                        <span>Order ID:</span>
                        <span>${req.query.orderId || 'DEMO-ORDER'}</span>
                    </div>
                    <div class="order-detail">
                        <span>Amount:</span>
                        <span>${req.query.amount || '₱157.50'}</span>
                    </div>
                    <div class="order-detail">
                        <span>Status:</span>
                        <span style="color: #28a745; font-weight: bold;">Paid</span>
                    </div>
                </div>
                
                <div class="message">You can now close this window and return to the app.</div>
                <button class="close-btn" onclick="window.close()">Close Window</button>
            </div>
            <script>
                // Auto-close after 8 seconds
                setTimeout(() => {
                    window.close();
                }, 8000);
            </script>
        </body>
        </html>
    `);
});

router.get('/payment-failed', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>Payment Failed</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #fff5f5; }
                .error { color: #dc3545; font-size: 24px; margin-bottom: 20px; }
                .message { font-size: 18px; margin-bottom: 30px; }
                .close-btn { background: #dc3545; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
            </style>
        </head>
        <body>
            <div class="error">❌ Payment Failed</div>
            <div class="message">Your payment could not be processed.</div>
            <div class="message">Please try again or contact support.</div>
            <button class="close-btn" onclick="window.close()">Close Window</button>
            <script>
                // Auto-close after 5 seconds
                setTimeout(() => {
                    window.close();
                }, 5000);
            </script>
        </body>
        </html>
    `);
});

// DELETE /api/orders/:orderId
// Deletes an order (admin only, typically for completed/picked up orders)
router.delete('/:orderId', async (req, res) => {
    try {
        const { orderId } = req.params;
        
        console.log('🗑️ Delete request received for order:', orderId);
        
        // Check if order exists
        const orderDoc = await db.collection('orders').doc(orderId).get();
        if (!orderDoc.exists) {
            console.log('❌ Order not found:', orderId);
            return res.status(404).json({ message: 'Order not found' });
        }
        
        const orderData = orderDoc.data();
        console.log('📋 Order data:', {
            id: orderId,
            status: orderData.orderStatus,
            type: typeof orderData.orderStatus
        });
        
        // Optional: Only allow deletion of completed or cancelled orders
        if (orderData.orderStatus !== 'completed' && orderData.orderStatus !== 'cancelled') {
            console.log('❌ Invalid order status for deletion:', orderData.orderStatus);
            return res.status(400).json({ 
                message: 'Only completed or cancelled orders can be deleted',
                currentStatus: orderData.orderStatus,
                allowedStatuses: ['completed', 'cancelled']
            });
        }
        
        console.log('✅ Order status valid for deletion:', orderData.orderStatus);
        
        // Delete the order
        await db.collection('orders').doc(orderId).delete();
        console.log('✅ Order document deleted from Firestore');
        
        // Also delete related order items if they exist in a separate collection
        const orderItemsSnapshot = await db.collection('orderItems')
            .where('orderId', '==', orderId)
            .get();
        
        console.log('📋 Found', orderItemsSnapshot.size, 'related order items to delete');
        
        const batch = db.batch();
        orderItemsSnapshot.forEach(doc => {
            batch.delete(doc.ref);
        });
        await batch.commit();
        
        console.log('✅ Related order items deleted');
        
        res.status(200).json({ 
            message: 'Order deleted successfully',
            deletedOrderId: orderId
        });
        
    } catch (error) {
        console.error('❌ Error deleting order:', error);
        res.status(500).json({ message: 'Error deleting order', error: error.message });
    }
});

module.exports = router; 