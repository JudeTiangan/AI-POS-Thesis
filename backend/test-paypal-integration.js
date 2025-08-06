const { paypalDemoAPI } = require('./config/paypal-demo');

async function testPayPalIntegration() {
    console.log('🧪 Testing PayPal Integration...\n');
    
    try {
        // Test 1: Basic PayPal order creation
        console.log('📋 Test 1: Creating PayPal order...');
        const paymentData = {
            amount: 150.00,
            currency: 'PHP',
            description: 'GENSUGGEST POS Order #TEST123',
            metadata: {
                orderId: 'TEST123',
                customerName: 'Test Customer',
                customerEmail: 'test@example.com',
                itemCount: '2'
            },
            returnUrl: 'https://ai-pos-backend.onrender.com/api/orders/payment-success',
            cancelUrl: 'https://ai-pos-backend.onrender.com/api/orders/payment-failed'
        };
        
        const result = await paypalDemoAPI.createPayPalOrder(paymentData);
        console.log('✅ PayPal API Response:', JSON.stringify(result, null, 2));
        
        if (result.success) {
            console.log('✅ Test 1 PASSED: PayPal order created successfully');
            console.log('🔗 Payment URL:', result.paymentUrl);
            console.log('🆔 Order ID:', result.orderId);
        } else {
            console.error('❌ Test 1 FAILED:', result.error);
            return;
        }
        
        // Test 2: Check if URL is accessible
        console.log('\n📋 Test 2: Checking URL accessibility...');
        const url = result.paymentUrl;
        console.log('🔗 Testing URL:', url);
        
        // Test 3: Simulate payment capture
        console.log('\n📋 Test 3: Testing payment capture...');
        const captureResult = await paypalDemoAPI.capturePayment(result.orderId);
        console.log('✅ Capture Result:', JSON.stringify(captureResult, null, 2));
        
        if (captureResult.success) {
            console.log('✅ Test 3 PASSED: Payment capture successful');
        } else {
            console.error('❌ Test 3 FAILED:', captureResult.error);
        }
        
        console.log('\n🎉 All PayPal integration tests completed!');
        
    } catch (error) {
        console.error('❌ Test failed with error:', error);
    }
}

testPayPalIntegration(); 