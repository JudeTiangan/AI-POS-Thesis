const { paypalDemoAPI } = require('./config/paypal-demo');

async function testPayPalDemoAPI() {
    console.log('🧪 Testing PayPal Demo API');
    console.log('==========================');
    
    try {
        // Test PayPal order creation
        const paymentData = {
            amount: 500.00,
            currency: 'PHP',
            description: 'Test Order #123',
            metadata: {
                orderId: 'TEST_123',
                customerName: 'Test Customer',
                customerEmail: 'test@example.com',
                itemCount: '2'
            },
            returnUrl: 'https://example.com/success',
            cancelUrl: 'https://example.com/cancel'
        };
        
        console.log('📋 Creating PayPal order with data:', paymentData);
        
        const result = await paypalDemoAPI.createPayPalOrder(paymentData);
        
        console.log('📊 PayPal API Result:', result);
        
        if (result.success) {
            console.log('✅ PayPal order created successfully!');
            console.log('🆔 Order ID:', result.orderId);
            console.log('🔗 Payment URL:', result.paymentUrl);
        } else {
            console.log('❌ PayPal order creation failed:', result.error);
        }
        
    } catch (error) {
        console.error('💥 Test failed:', error);
    }
}

testPayPalDemoAPI().then(() => {
    console.log('\n🏁 Test completed');
    process.exit(0);
}).catch((error) => {
    console.error('\n💥 Test crashed:', error);
    process.exit(1);
}); 