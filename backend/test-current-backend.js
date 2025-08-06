const axios = require('axios');

async function testCurrentBackend() {
    console.log('🧪 Testing Current Backend Behavior');
    console.log('===================================');
    
    const baseUrl = 'https://ai-pos-thesis-2.onrender.com';
    const apiUrl = `${baseUrl}/api/orders`;
    
    console.log('🔗 Testing against:', apiUrl);
    
    // Test order data (same as your frontend)
    const testOrder = {
        userId: '0936BPos2ihSY4mxATxxsUeGQzt2',
        items: [
            {
                itemId: '0NjRQlUEnOe2AzpWFrMY',
                itemName: 'Century Tuna Flakes In Oil ',
                price: 102.5,
                quantity: 1,
                itemImageUrl: 'https://firebasestorage.googleapis.com/v0/b/thesis-ai-pos.firebasestorage.app/o/products%2F0NjRQlUEnOe2AzpWFrMY.jpg?alt=media&token=3c21c4e4-2352-429a-95af-83ffa9358e59'
            }
        ],
        totalPrice: 102.5,
        orderType: 'pickup',
        paymentMethod: 'paypal',
        customerName: 'cruz',
        customerEmail: '3jude2101@gmail.com',
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
        console.log('- Payment Method:', responseData.order?.paymentMethod);
        
        if (responseData.paymentUrl) {
            console.log('\n🔗 Testing PayPal URL accessibility...');
            try {
                const urlResponse = await axios.get(responseData.paymentUrl, {
                    timeout: 10000
                });
                console.log('✅ PayPal URL is accessible (Status:', urlResponse.status + ')');
            } catch (urlError) {
                console.log('❌ PayPal URL test failed:', urlError.message);
            }
        }
        
    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        
        if (error.response) {
            console.error('📊 Response Status:', error.response.status);
            console.error('📋 Response Data:', error.response.data);
        }
    }
}

testCurrentBackend().then(() => {
    console.log('\n🏁 Test completed');
    process.exit(0);
}).catch((error) => {
    console.error('\n💥 Test crashed:', error);
    process.exit(1);
}); 