require('dotenv').config();
const { PayMongoAPI, PAYMONGO_CONFIG } = require('./config/paymongo');

async function testPayMongoKeys() {
    console.log('🔍 Testing PayMongo API Keys...');
    console.log('PUBLIC_KEY:', PAYMONGO_CONFIG.PUBLIC_KEY ? 'Found' : 'Missing');
    console.log('SECRET_KEY:', PAYMONGO_CONFIG.SECRET_KEY ? 'Found' : 'Missing');
    
    console.log('Using key:', PAYMONGO_CONFIG.SECRET_KEY.substring(0, 10) + '...');
    
    const payMongo = new PayMongoAPI();
    
    // Test with a valid amount for PayMongo (minimum 20 PHP)
    const testPayment = {
        amount: 100, // 100 PHP (well above minimum)
        currency: 'PHP',
        description: 'Test payment for GCash integration',
        metadata: {
            test: 'true',
            orderId: 'test-order-123'
        }
    };
    
    try {
        console.log('📡 Testing PayMongo API connection...');
        const result = await payMongo.createGCashPayment(testPayment);
        
        if (result.success) {
            console.log('✅ PayMongo API keys are working correctly!');
            console.log('Payment Source ID:', result.paymentIntent.id);
            console.log('Payment URL:', result.paymentUrl);
            console.log('Status:', result.paymentIntent.attributes.status);
        } else {
            console.log('❌ PayMongo API error:', result.error);
        }
    } catch (error) {
        console.log('❌ Connection error:', error.message);
    }
}

testPayMongoKeys(); 