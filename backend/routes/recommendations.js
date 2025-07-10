const express = require('express');
const router = express.Router();
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { db } = require('../config/firebase');

// IMPORTANT: Go to https://aistudio.google.com/app/apikey to get your API key
// Add it as an environment variable named GEMINI_API_KEY
// Temporarily hardcoded for testing - will fix .env issue later
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || 'AIzaSyCcAFUwBcrSyiN2A3EyABa5rkOtscnDyUs');

// POST for getting recommendations
router.post('/', async (req, res) => {
    try {
        const { currentCart, userHistory } = req.body;

        // Input validation
        if (!currentCart || !Array.isArray(currentCart)) {
            return res.status(400).json({ message: 'currentCart is required and must be an array.' });
        }

        // --- 1. Gemini AI Recommendation ---
        let recommendationIds = [];
        try {
            recommendationIds = await getGeminiRecommendations(currentCart, userHistory);
        } catch (e) {
            console.error("Gemini API error, falling back to local logic:", e.message);
            // Fallback to local logic if Gemini fails
        }

        // --- 2. Fallback Recommendation (if Gemini gives no results) ---
        if (recommendationIds.length === 0) {
            console.log("Gemini returned no results, using fallback.");
            recommendationIds = await getFallbackRecommendations(currentCart);
        }

        // --- 3. Fetch full item details from Firestore ---
        if (recommendationIds.length === 0) {
            return res.status(200).json([]); // Return empty if no recommendations found
        }
        
        if (!db) {
            // Return mock recommendations when Firebase is unavailable
            const mockRecommendations = [
                { id: 'mock_rec_1', name: 'Sugar', categoryId: 'sweeteners', price: 5.00, description: 'Sweet companion for your coffee' },
                { id: 'mock_rec_2', name: 'Milk', categoryId: 'dairy', price: 8.00, description: 'Fresh milk for creamy drinks' },
                { id: 'mock_rec_3', name: 'Cookie', categoryId: 'snacks', price: 3.50, description: 'Perfect snack with your beverage' }
            ];
            return res.status(200).json(mockRecommendations);
        }
        
        const recommendedItems = await Promise.all(
            recommendationIds.map(id => db.collection('items').doc(id).get())
        );

        const itemsData = recommendedItems
            .filter(doc => doc.exists)
            .map(doc => ({ id: doc.id, ...doc.data() }));

        res.status(200).json(itemsData);

    } catch (error) {
        res.status(500).json({ message: 'Error getting recommendations', error: error.message });
    }
});

async function getGeminiRecommendations(currentCart, userHistory) {
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

    // Check if Firebase is available
    if (!db) {
        console.log("Firebase unavailable, using mock items for Gemini recommendations");
        const mockItems = [
            {id: 'mock_1', name: 'Coffee', categoryId: 'beverages'},
            {id: 'mock_2', name: 'Sugar', categoryId: 'sweeteners'}, 
            {id: 'mock_3', name: 'Milk', categoryId: 'dairy'}
        ];
        // Continue with mock data
        return generateGeminiResponse(model, mockItems, currentCart, userHistory);
    }

    // TODO: Fetch full item details for the prompt
    const allItemsSnapshot = await db.collection('items').get();
    const allItems = allItemsSnapshot.docs.map(doc => ({id: doc.id, ...doc.data()}));
    
    return generateGeminiResponse(model, allItems, currentCart, userHistory);
}

async function generateGeminiResponse(model, allItems, currentCart, userHistory) {
    const prompt = `
        You are an expert AI assistant for a Point-of-Sale system in a retail store. 
        Your task is to recommend items to a customer based on their current shopping cart and purchase history.

        Here is the complete list of all available items in the store, in JSON format:
        ${JSON.stringify(allItems.map(i => ({id: i.id, name: i.name, categoryId: i.categoryId})))}

        Here is the customer's current shopping cart, as an array of item objects:
        ${JSON.stringify(currentCart)}

        Here is the customer's recent purchase history, as an array of item objects (if available):
        ${JSON.stringify(userHistory || [])}

        Based on all this information, please recommend up to 5 additional items for the customer.
        Your response MUST be a valid JSON array of strings, where each string is the ID of the recommended item. 
        Do not include any items that are already in the customer's current cart.
        Do not include any explanatory text, just the JSON array.

        Example response: ["item_id_1", "item_id_2", "item_id_3"]
    `;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();
    
    // Clean and parse the response
    try {
        // The model sometimes wraps the JSON in ```json ... ```, so we clean it
        const cleanedText = text.replace(/```json/g, '').replace(/```/g, '').trim();
        const ids = JSON.parse(cleanedText);
        return Array.isArray(ids) ? ids : [];
    } catch (e) {
        console.error("Failed to parse Gemini response:", text);
        return []; // Return empty array if parsing fails
    }
}

async function getFallbackRecommendations(currentCart) {
    // Simple fallback: Recommend the 3 most popular (most frequently purchased) items not already in the cart.
    // In a real app, this would be more complex (e.g., pre-defined associations).
    
    if (!db) {
        console.log("Firebase unavailable, using predefined fallback recommendations");
        const cartItemIds = new Set(currentCart.map(item => item.id));
        const fallbackItems = ['mock_rec_1', 'mock_rec_2', 'mock_rec_3'];
        return fallbackItems.filter(id => !cartItemIds.has(id)).slice(0, 3);
    }
    
    // This is a placeholder for order data. In a real app, you'd query your 'orders' collection.
    const allOrdersSnapshot = await db.collection('orderItems').get(); // Assuming an 'orderItems' collection
    if (allOrdersSnapshot.empty) return [];

    const itemCounts = {};
    allOrdersSnapshot.forEach(doc => {
        const { itemId } = doc.data();
        itemCounts[itemId] = (itemCounts[itemId] || 0) + 1;
    });

    const cartItemIds = new Set(currentCart.map(item => item.id));

    const sortedItems = Object.entries(itemCounts)
        .sort(([,a],[,b]) => b - a)
        .map(([id]) => id)
        .filter(id => !cartItemIds.has(id));
        
    return sortedItems.slice(0, 3);
}

module.exports = router; 