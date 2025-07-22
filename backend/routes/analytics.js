const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');

// Get customer analytics for a specific user
router.get('/customer/:userId', async (req, res) => {
  try {
    if (!db) {
      return res.json({
        success: true,
        message: 'Firebase unavailable - returning mock customer analytics',
        customerId: req.params.userId,
        itemPurchaseFrequency: { 'coffee': 5, 'sugar': 3, 'milk': 2 },
        totalOrders: 8,
        averageOrderValue: 45.50,
        categoryPreferences: { 'beverages': 0.8, 'snacks': 0.3 }
      });
    }

    const { userId } = req.params;
    
    const analyticsDoc = await db.collection('customerAnalytics').doc(userId).get();
    
    if (!analyticsDoc.exists) {
      return res.status(404).json({ error: 'Customer analytics not found' });
    }
    
    res.json(analyticsDoc.data());
  } catch (error) {
    console.error('Error fetching customer analytics:', error);
    res.status(500).json({ error: 'Failed to fetch customer analytics' });
  }
});

// Update customer analytics after a purchase
router.post('/customer/:userId/purchase', async (req, res) => {
  try {
    if (!db) {
      return res.json({
        success: true,
        message: 'Firebase unavailable - mock analytics update successful',
        analytics: {
          customerId: req.params.userId,
          totalOrders: 1,
          lastUpdate: new Date().toISOString()
        }
      });
    }

    const { userId } = req.params;
    const { items, totalAmount } = req.body;
    
    const docRef = db.collection('customerAnalytics').doc(userId);
    const doc = await docRef.get();
    
    let analytics;
    if (doc.exists) {
      analytics = doc.data();
    } else {
      // Create new analytics for first-time customer
      analytics = {
        customerId: userId,
        itemPurchaseFrequency: {},
        purchaseHistory: [],
        categoryPreferences: {},
        lastPurchase: new Date().toISOString(),
        averageOrderValue: 0.0,
        totalOrders: 0,
        frequentItems: [],
        associationRules: {},
      };
    }
    
    // Update analytics with new purchase
    const updatedAnalytics = updateAnalyticsWithPurchase(analytics, items, totalAmount);
    
    await docRef.set(updatedAnalytics);
    
    res.json({ success: true, analytics: updatedAnalytics });
  } catch (error) {
    console.error('Error updating customer analytics:', error);
    res.status(500).json({ error: 'Failed to update customer analytics' });
  }
});

// Get global analytics and association rules
router.get('/global', async (req, res) => {
  try {
    if (!db) {
      return res.json({
        success: true,
        message: 'Firebase unavailable - returning mock global analytics',
        totalCustomers: 25,
        totalOrders: 150,
        totalRevenue: 8750.00,
        averageOrderValue: 58.33,
        popularItems: { 'coffee': 45, 'sugar': 30, 'milk': 25, 'pastry': 20 },
        categoryPreferences: { 'beverages': 65, 'snacks': 35, 'desserts': 15 },
        associationRules: [
          { antecedent: 'coffee', consequent: 'sugar', confidence: 0.78, support: 0.45, lift: 2.1 },
          { antecedent: 'coffee', consequent: 'milk', confidence: 0.65, support: 0.38, lift: 1.8 }
        ]
      });
    }

    // Get all customer analytics
    const analyticsSnapshot = await db.collection('customerAnalytics').get();
    
    let globalItemFrequency = {};
    let globalCategoryPreferences = {};
    let allCustomers = [];
    let totalOrders = 0;
    let totalRevenue = 0.0;
    
    analyticsSnapshot.docs.forEach(doc => {
      const analytics = doc.data();
      allCustomers.push(analytics.customerId);
      totalOrders += analytics.totalOrders || 0;
      totalRevenue += (analytics.averageOrderValue || 0) * (analytics.totalOrders || 0);
      
      // Aggregate item frequencies
      if (analytics.itemPurchaseFrequency) {
        Object.entries(analytics.itemPurchaseFrequency).forEach(([itemId, count]) => {
          globalItemFrequency[itemId] = (globalItemFrequency[itemId] || 0) + count;
        });
      }
      
      // Aggregate category preferences
      if (analytics.categoryPreferences) {
        Object.entries(analytics.categoryPreferences).forEach(([categoryId, preference]) => {
          globalCategoryPreferences[categoryId] = (globalCategoryPreferences[categoryId] || 0.0) + preference;
        });
      }
    });
    
    // Calculate association rules
    const associationRules = await calculateGlobalAssociationRules();
    
    const globalAnalytics = {
      totalCustomers: allCustomers.length,
      totalOrders: totalOrders,
      totalRevenue: totalRevenue,
      averageOrderValue: totalOrders > 0 ? totalRevenue / totalOrders : 0.0,
      popularItems: globalItemFrequency,
      categoryPreferences: globalCategoryPreferences,
      associationRules: associationRules,
    };
    
    res.json(globalAnalytics);
  } catch (error) {
    console.error('Error fetching global analytics:', error);
    res.status(500).json({ error: 'Failed to fetch global analytics' });
  }
});

// Get market basket analysis - association rules
router.get('/association-rules', async (req, res) => {
  try {
    if (!db) {
      return res.json({
        success: true,
        message: 'Firebase unavailable - returning mock association rules',
        rules: [
          { antecedent: 'coffee', consequent: 'sugar', confidence: 0.78, support: 0.45, lift: 2.1 },
          { antecedent: 'coffee', consequent: 'milk', confidence: 0.65, support: 0.38, lift: 1.8 },
          { antecedent: 'burger', consequent: 'fries', confidence: 0.82, support: 0.52, lift: 2.3 },
          { antecedent: 'tea', consequent: 'honey', confidence: 0.71, support: 0.33, lift: 1.9 }
        ]
      });
    }

    const rules = await calculateGlobalAssociationRules();
    res.json(rules);
  } catch (error) {
    console.error('Error calculating association rules:', error);
    res.status(500).json({ error: 'Failed to calculate association rules' });
  }
});

// Calculate popular item combinations
router.get('/popular-combinations', async (req, res) => {
  try {
    if (!db) {
      return res.json({
        success: true,
        message: 'Firebase unavailable - returning mock popular combinations',
        combinations: [
          { item1: 'Coffee', item2: 'Sugar', frequency: 28 },
          { item1: 'Burger', item2: 'Fries', frequency: 24 },
          { item1: 'Coffee', item2: 'Milk', frequency: 22 },
          { item1: 'Tea', item2: 'Honey', frequency: 18 },
          { item1: 'Pizza', item2: 'Soda', frequency: 16 }
        ]
      });
    }

    const ordersSnapshot = await db.collection('orders').get();
    const orderItemsSnapshot = await db.collection('orderItems').get();
    
    // Build transaction database
    let transactions = {};
    let itemNames = {}; // itemId -> itemName
    
    ordersSnapshot.docs.forEach(orderDoc => {
      transactions[orderDoc.id] = [];
    });
    
    orderItemsSnapshot.docs.forEach(orderItemDoc => {
      const data = orderItemDoc.data();
      const orderId = data.orderId;
      const itemId = data.itemId;
      const itemName = data.itemName;
      
      if (transactions[orderId]) {
        transactions[orderId].push(itemId);
        itemNames[itemId] = itemName;
      }
    });
    
    // Find popular 2-item combinations
    let combinations = {};
    
    Object.values(transactions).forEach(transaction => {
      if (transaction.length >= 2) {
        for (let i = 0; i < transaction.length; i++) {
          for (let j = i + 1; j < transaction.length; j++) {
            const combo = [transaction[i], transaction[j]].sort().join('-');
            combinations[combo] = (combinations[combo] || 0) + 1;
          }
        }
      }
    });
    
    // Convert to array and sort by frequency
    const popularCombinations = Object.entries(combinations)
      .map(([combo, count]) => {
        const [item1, item2] = combo.split('-');
        return {
          item1: itemNames[item1] || 'Unknown',
          item2: itemNames[item2] || 'Unknown',
          frequency: count,
        };
      })
      .sort((a, b) => b.frequency - a.frequency)
      .slice(0, 10);
    
    res.json(popularCombinations);
  } catch (error) {
    console.error('Error calculating popular combinations:', error);
    res.status(500).json({ error: 'Failed to calculate popular combinations' });
  }
});

// Get today's analytics for dashboard
router.get('/today', async (req, res) => {
  try {
    if (!db) {
      return res.json({
        success: true,
        message: 'Firebase unavailable - returning mock today analytics',
        todayOrders: 5,
        todaySales: 1250.00,
        pendingOrders: 2
      });
    }

    // Get today's date range
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayEnd = new Date(todayStart);
    todayEnd.setDate(todayEnd.getDate() + 1); // Tomorrow start = today end

    console.log('📅 Fetching analytics for today:', todayStart.toISOString(), 'to', todayEnd.toISOString());

    // Query orders for today
    const todayOrdersSnapshot = await db.collection('orders')
      .where('createdAt', '>=', todayStart)
      .where('createdAt', '<', todayEnd)
      .get();

    let todayOrders = 0;
    let todaySales = 0.0;
    let pendingOrders = 0;

    todayOrdersSnapshot.docs.forEach(doc => {
      const order = doc.data();
      todayOrders++;
      todaySales += order.totalPrice || 0;
      
      // Count pending orders (pending or preparing)
      if (order.orderStatus === 'pending' || order.orderStatus === 'preparing') {
        pendingOrders++;
      }
    });

    console.log('📊 Today\'s Analytics Calculated:', {
      todayOrders,
      todaySales,
      pendingOrders
    });

    res.json({
      success: true,
      todayOrders,
      todaySales,
      pendingOrders,
      date: todayStart.toISOString().split('T')[0] // YYYY-MM-DD format
    });

  } catch (error) {
    console.error('Error fetching today\'s analytics:', error);
    res.status(500).json({ error: 'Failed to fetch today\'s analytics' });
  }
});

// Helper function to update analytics with new purchase
function updateAnalyticsWithPurchase(analytics, items, totalAmount) {
  const updatedFrequency = { ...analytics.itemPurchaseFrequency };
  const updatedCategoryPreferences = { ...analytics.categoryPreferences };
  
  // Update item frequencies
  items.forEach(item => {
    updatedFrequency[item.id] = (updatedFrequency[item.id] || 0) + 1;
    
    // Update category preferences
    const currentPreference = updatedCategoryPreferences[item.categoryId] || 0.0;
    updatedCategoryPreferences[item.categoryId] = currentPreference + 0.1;
  });
  
  // Calculate new average order value
  const newTotalOrders = (analytics.totalOrders || 0) + 1;
  const oldTotal = (analytics.averageOrderValue || 0) * (analytics.totalOrders || 0);
  const newAverageOrderValue = (oldTotal + totalAmount) / newTotalOrders;
  
  // Update frequent items (top 5 most purchased)
  const sortedItems = Object.entries(updatedFrequency)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 5)
    .map(([itemId]) => itemId);
  
  return {
    customerId: analytics.customerId,
    itemPurchaseFrequency: updatedFrequency,
    purchaseHistory: [
      ...(analytics.purchaseHistory || []),
      {
        orderId: Date.now().toString(),
        itemIds: items.map(item => item.id),
        timestamp: new Date().toISOString(),
        totalAmount: totalAmount,
        categories: [...new Set(items.map(item => item.categoryId))],
      }
    ],
    categoryPreferences: updatedCategoryPreferences,
    lastPurchase: new Date().toISOString(),
    averageOrderValue: newAverageOrderValue,
    totalOrders: newTotalOrders,
    frequentItems: sortedItems,
    associationRules: analytics.associationRules || {},
  };
}

// Helper function to calculate global association rules
async function calculateGlobalAssociationRules() {
  try {
    if (!db) {
      // Return mock association rules when Firebase is unavailable
      return [
        { antecedent: 'Coffee', consequent: 'Sugar', confidence: 0.78, support: 0.45, lift: 2.1 },
        { antecedent: 'Coffee', consequent: 'Milk', confidence: 0.65, support: 0.38, lift: 1.8 },
        { antecedent: 'Burger', consequent: 'Fries', confidence: 0.82, support: 0.52, lift: 2.3 },
        { antecedent: 'Tea', consequent: 'Honey', confidence: 0.71, support: 0.33, lift: 1.9 }
      ];
    }

    const ordersSnapshot = await db.collection('orders').get();
    const orderItemsSnapshot = await db.collection('orderItems').get();
    
    // Build transaction database
    let transactions = {};
    let itemNames = {}; // itemId -> itemName
    
    ordersSnapshot.docs.forEach(orderDoc => {
      transactions[orderDoc.id] = [];
    });
    
    orderItemsSnapshot.docs.forEach(orderItemDoc => {
      const data = orderItemDoc.data();
      const orderId = data.orderId;
      const itemId = data.itemId;
      const itemName = data.itemName;
      
      if (transactions[orderId]) {
        transactions[orderId].push(itemId);
        itemNames[itemId] = itemName;
      }
    });
    
    // Calculate association rules
    const rules = [];
    const itemIds = Object.keys(itemNames);
    
    for (let i = 0; i < itemIds.length && rules.length < 10; i++) {
      for (let j = i + 1; j < itemIds.length && rules.length < 10; j++) {
        const item1 = itemIds[i];
        const item2 = itemIds[j];
        
        const confidence = calculateConfidence([item1], item2, transactions);
        const support = calculateSupport([item1, item2], transactions);
        const lift = calculateLift([item1], item2, transactions);
        
        if (confidence > 0.1 && support > 0.05) { // Minimum thresholds
          rules.push({
            antecedent: itemNames[item1] || 'Unknown',
            consequent: itemNames[item2] || 'Unknown',
            confidence: confidence,
            support: support,
            lift: lift,
          });
        }
      }
    }
    
    // Sort by confidence descending
    rules.sort((a, b) => b.confidence - a.confidence);
    
    return rules.slice(0, 5);
  } catch (error) {
    console.error('Error calculating association rules:', error);
    return [];
  }
}

// Helper functions for association rule calculations
function calculateConfidence(antecedent, consequent, transactions) {
  let antecedentCount = 0;
  let bothCount = 0;

  Object.values(transactions).forEach(transaction => {
    const hasAntecedent = antecedent.every(item => transaction.includes(item));
    if (hasAntecedent) {
      antecedentCount++;
      if (transaction.includes(consequent)) {
        bothCount++;
      }
    }
  });

  return antecedentCount > 0 ? bothCount / antecedentCount : 0.0;
}

function calculateSupport(itemset, transactions) {
  let count = 0;
  const totalTransactions = Object.keys(transactions).length;
  
  Object.values(transactions).forEach(transaction => {
    if (itemset.every(item => transaction.includes(item))) {
      count++;
    }
  });
  
  return totalTransactions > 0 ? count / totalTransactions : 0.0;
}

function calculateLift(antecedent, consequent, transactions) {
  const confidence = calculateConfidence(antecedent, consequent, transactions);
  const consequentSupport = calculateSupport([consequent], transactions);
  return consequentSupport > 0 ? confidence / consequentSupport : 0.0;
}

module.exports = router; 