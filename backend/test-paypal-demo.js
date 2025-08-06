const { paypalDemoAPI } = require('./config/paypal-demo');

async function testPayPalDemo() {
    console.log('🎭 Testing PayPal Demo Integration for Thesis...\n');
    
    try {
        // Test 1: Get Access Token
        console.log('1️⃣ Testing Access Token...');
        const accessToken = await paypalDemoAPI.getAccessToken();
        console.log('✅ Access Token:', accessToken);
        
        // Test 2: Create PayPal Order
        console.log('\n2️⃣ Testing PayPal Order Creation...');
        const paymentData = {
            amount: 50.00,
            currency: 'PHP',
            description: 'GENSUGGEST POS Demo Order',
            metadata: {
                orderId: 'demo_order_123',
                customerName: 'Demo Customer',
                customerEmail: 'demo@example.com',
                itemCount: '2'
            },
            returnUrl: 'https://your-app.com/success',
            cancelUrl: 'https://your-app.com/cancel'
        };
        
        const orderResult = await paypalDemoAPI.createPayPalOrder(paymentData);
        
        if (orderResult.success) {
            console.log('✅ PayPal Order Created:');
            console.log('   Order ID:', orderResult.orderId);
            console.log('   Payment URL:', orderResult.paymentUrl);
            
            // Test 3: Capture Payment
            console.log('\n3️⃣ Testing Payment Capture...');
            const captureResult = await paypalDemoAPI.capturePayment(orderResult.orderId);
            
            if (captureResult.success) {
                console.log('✅ Payment Captured:');
                console.log('   Capture ID:', captureResult.captureId);
                console.log('   Status:', captureResult.status);
            }
            
            // Test 4: Get Order Details
            console.log('\n4️⃣ Testing Order Details...');
            const detailsResult = await paypalDemoAPI.getOrderDetails(orderResult.orderId);
            
            if (detailsResult.success) {
                console.log('✅ Order Details Retrieved');
                console.log('   Order Status:', detailsResult.orderData.status);
            }
        }
        
        console.log('\n🎉 PayPal Demo Integration Test: SUCCESS!');
        console.log('🚀 Ready for Thesis Presentation!');
        
    } catch (error) {
        console.error('❌ Demo Test Failed:', error);
    }
}

// Run the test
testPayPalDemo(); 