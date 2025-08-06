const axios = require('axios');

// Test PayPal Integration Debug Script
async function testPayPalIntegration() {
    console.log('🔍 Testing PayPal Integration...\n');
    
    const baseUrl = process.env.BACKEND_URL || 'https://ai-pos-backend.onrender.com';
    console.log('🌐 Backend URL:', baseUrl);
    
    // Test data
    const testOrder = {
        userId: 'test_user_123',
        items: [
            {
                itemId: 'item_1',
                itemName: 'Test Item',
                price: 100.00,
                quantity: 1,
                itemImageUrl: null
            }
        ],
        totalPrice: 100.00,
        orderType: 'pickup',
        paymentMethod: 'paypal',
        customerName: 'Test Customer',
        customerEmail: 'test@example.com',
        customerPhone: '1234567890'
    };
    
    try {
        console.log('📤 Creating PayPal order...');
        console.log('📋 Order data:', JSON.stringify(testOrder, null, 2));
        
        const response = await axios.post(`${baseUrl}/api/orders`, testOrder, {
            headers: {
                'Content-Type': 'application/json'
            },
            timeout: 30000
        });
        
        console.log('\n✅ Order creation response:');
        console.log('📊 Status:', response.status);
        console.log('📄 Response data:', JSON.stringify(response.data, null, 2));
        
        // Analyze the response
        const data = response.data;
        
        console.log('\n🔍 Response Analysis:');
        console.log('✅ Success:', data.success);
        console.log('📝 Message:', data.message);
        console.log('🆔 Order ID:', data.order?.id);
        console.log('🔗 Payment URL:', data.paymentUrl);
        console.log('🆔 Payment Source ID:', data.paymentSourceId);
        console.log('💰 Order Payment Source ID:', data.order?.paymentSourceId);
        
        // Check for issues
        if (!data.paymentUrl) {
            console.log('\n❌ ISSUE: No payment URL returned');
        } else {
            console.log('\n✅ Payment URL found:', data.paymentUrl);
            
            // Test if the URL is accessible
            try {
                console.log('\n🔗 Testing payment URL accessibility...');
                const urlResponse = await axios.get(data.paymentUrl, {
                    timeout: 10000,
                    validateStatus: () => true // Don't throw on any status
                });
                console.log('📊 URL Status:', urlResponse.status);
                console.log('📄 URL Content Type:', urlResponse.headers['content-type']);
                console.log('📏 Content Length:', urlResponse.data?.length || 'Unknown');
            } catch (urlError) {
                console.log('❌ URL Test Error:', urlError.message);
            }
        }
        
        if (!data.paymentSourceId) {
            console.log('\n❌ ISSUE: No paymentSourceId at top level');
        }
        
        if (!data.order?.paymentSourceId) {
            console.log('\n❌ ISSUE: No paymentSourceId in order object');
        }
        
        // Test PayPal demo API directly
        console.log('\n🧪 Testing PayPal Demo API directly...');
        const { paypalDemoAPI } = require('./config/paypal-demo');
        
        const demoResult = await paypalDemoAPI.createPayPalOrder({
            amount: 100.00,
            currency: 'PHP',
            description: 'Test Order',
            metadata: { orderId: 'test_123' },
            returnUrl: 'https://example.com/success',
            cancelUrl: 'https://example.com/cancel'
        });
        
        console.log('🎭 Demo API Result:', JSON.stringify(demoResult, null, 2));
        
    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        if (error.response) {
            console.error('📊 Status:', error.response.status);
            console.error('📄 Error data:', JSON.stringify(error.response.data, null, 2));
        }
    }
}

// Run the test
testPayPalIntegration().then(() => {
    console.log('\n🏁 Test completed');
    process.exit(0);
}).catch(error => {
    console.error('\n💥 Test failed:', error);
    process.exit(1);
}); 