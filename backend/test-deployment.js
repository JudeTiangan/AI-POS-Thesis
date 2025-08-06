const axios = require('axios');

async function testDeployment() {
    console.log('🧪 Testing PayPal Integration Deployment');
    console.log('======================================');
    
    const baseUrl = 'https://ai-pos-thesis-2.onrender.com';
    const apiUrl = `${baseUrl}/api/orders`;
    
    console.log('🔗 Testing against:', apiUrl);
    
    // Test order data
    const testOrder = {
        userId: 'test_user_123',
        items: [
            {
                itemId: 'test_item_1',
                itemName: 'Test Item',
                price: 100.00,
                quantity: 1,
                itemImageUrl: 'https://example.com/image.jpg'
            }
        ],
        totalPrice: 100.00,
        orderType: 'pickup',
        paymentMethod: 'paypal',
        customerName: 'Test User',
        customerEmail: 'test@example.com',
        customerPhone: null
    };
    
    try {
        console.log('\n📋 Creating PayPal order...');
        console.log('💰 Total Amount: ₱' + testOrder.totalPrice);
        console.log('🎭 Payment Method: PayPal');
        
        const response = await axios.post(apiUrl, testOrder, {
            headers: {
                'Content-Type': 'application/json'
            },
            timeout: 15000
        });
        
        console.log('\n✅ Order created successfully!');
        console.log('📊 Response Status:', response.status);
        
        const responseData = response.data;
        console.log('\n📋 Full Response Data:');
        console.log(JSON.stringify(responseData, null, 2));
        
        // Check for PayPal-specific fields
        console.log('\n🔍 PayPal Integration Check:');
        console.log('- Success:', responseData.success);
        console.log('- Payment URL:', responseData.paymentUrl || 'MISSING');
        console.log('- Payment Source ID:', responseData.paymentSourceId || 'MISSING');
        console.log('- Order ID:', responseData.order?.id);
        
        if (responseData.paymentUrl && responseData.paymentSourceId) {
            console.log('\n🎉 SUCCESS: PayPal integration is working!');
            console.log('🎭 Ready for thesis demonstration');
        } else {
            console.log('\n❌ PayPal integration still has issues');
        }
        
    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        
        if (error.response) {
            console.error('📊 Response Status:', error.response.status);
            console.error('📋 Response Data:', error.response.data);
        }
    }
}

testDeployment().then(() => {
    console.log('\n🏁 Test completed');
    process.exit(0);
}).catch((error) => {
    console.error('\n💥 Test crashed:', error);
    process.exit(1);
}); 