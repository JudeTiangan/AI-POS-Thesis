const axios = require('axios');

// Test the complete PayPal integration flow
async function testPayPalCompleteFlow() {
    console.log('🧪 Testing Complete PayPal Integration Flow');
    console.log('==========================================');
    
    const baseUrl = process.env.BACKEND_URL || 'http://localhost:3000';
    const apiUrl = `${baseUrl}/api/orders`;
    
    console.log('🔗 Testing against:', apiUrl);
    
    // Test order data
    const testOrder = {
        userId: 'test_user_123',
        items: [
            {
                id: 'item_1',
                name: 'Test Item 1',
                price: 150.00,
                quantity: 2,
                totalPrice: 300.00
            },
            {
                id: 'item_2', 
                name: 'Test Item 2',
                price: 200.00,
                quantity: 1,
                totalPrice: 200.00
            }
        ],
        totalPrice: 500.00,
        orderType: 'pickup',
        paymentMethod: 'paypal',
        customerName: 'John Doe',
        customerEmail: 'john.doe@example.com',
        customerPhone: '+639123456789'
    };
    
    try {
        console.log('\n📋 Creating PayPal order...');
        console.log('💰 Total Amount: ₱' + testOrder.totalPrice);
        console.log('🎭 Payment Method: PayPal (Demo)');
        
        const response = await axios.post(apiUrl, testOrder, {
            headers: {
                'Content-Type': 'application/json'
            },
            timeout: 10000
        });
        
        console.log('\n✅ Order created successfully!');
        console.log('📊 Response Status:', response.status);
        
        const responseData = response.data;
        console.log('\n📋 Response Data:');
        console.log('- Success:', responseData.success);
        console.log('- Message:', responseData.message);
        console.log('- Order ID:', responseData.order?.id);
        console.log('- Payment URL:', responseData.paymentUrl);
        console.log('- Payment Source ID:', responseData.paymentSourceId);
        
        // Validate response structure
        console.log('\n🔍 Validating Response Structure:');
        
        if (responseData.success) {
            console.log('✅ Success flag is true');
        } else {
            console.log('❌ Success flag is false');
        }
        
        if (responseData.order && responseData.order.id) {
            console.log('✅ Order object with ID present');
        } else {
            console.log('❌ Order object or ID missing');
        }
        
        if (responseData.paymentUrl) {
            console.log('✅ Payment URL present:', responseData.paymentUrl);
            
            // Test if the PayPal demo page is accessible
            try {
                console.log('\n🔗 Testing PayPal demo page accessibility...');
                const demoResponse = await axios.get(responseData.paymentUrl, {
                    timeout: 5000
                });
                console.log('✅ PayPal demo page is accessible (Status:', demoResponse.status + ')');
            } catch (demoError) {
                console.log('⚠️  PayPal demo page test failed:', demoError.message);
            }
        } else {
            console.log('❌ Payment URL missing');
        }
        
        if (responseData.paymentSourceId) {
            console.log('✅ Payment Source ID present:', responseData.paymentSourceId);
        } else {
            console.log('❌ Payment Source ID missing');
        }
        
        console.log('\n🎯 PayPal Integration Test Summary:');
        console.log('==================================');
        
        const hasOrder = responseData.order && responseData.order.id;
        const hasPaymentUrl = responseData.paymentUrl;
        const hasPaymentSourceId = responseData.paymentSourceId;
        
        if (hasOrder && hasPaymentUrl && hasPaymentSourceId) {
            console.log('✅ COMPLETE SUCCESS: PayPal integration is working correctly!');
            console.log('🎭 Ready for thesis demonstration');
        } else {
            console.log('❌ PARTIAL SUCCESS: Some components are missing');
            console.log('- Order:', hasOrder ? '✅' : '❌');
            console.log('- Payment URL:', hasPaymentUrl ? '✅' : '❌');
            console.log('- Payment Source ID:', hasPaymentSourceId ? '✅' : '❌');
        }
        
    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        
        if (error.response) {
            console.error('📊 Response Status:', error.response.status);
            console.error('📋 Response Data:', error.response.data);
        }
    }
}

// Run the test
testPayPalCompleteFlow().then(() => {
    console.log('\n🏁 Test completed');
    process.exit(0);
}).catch((error) => {
    console.error('\n💥 Test crashed:', error);
    process.exit(1);
}); 