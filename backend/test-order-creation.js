const axios = require('axios');

async function testOrderCreation() {
    console.log('🧪 Testing Order Creation with PayPal...\n');
    
    try {
        const orderData = {
            userId: 'test_user_123',
            items: [
                {
                    itemId: 'item1',
                    itemName: 'Test Item 1',
                    price: 75.00,
                    quantity: 2,
                    itemImageUrl: 'https://example.com/image1.jpg'
                }
            ],
            totalPrice: 150.00,
            orderType: 'pickup',
            paymentMethod: 'paypal',
            customerName: 'Test Customer',
            customerEmail: 'test@example.com',
            customerPhone: '09123456789'
        };
        
        console.log('📋 Creating order with data:', JSON.stringify(orderData, null, 2));
        
        const response = await axios.post('https://ai-pos-backend.onrender.com/api/orders', orderData, {
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        console.log('✅ Order Creation Response:');
        console.log('Status:', response.status);
        console.log('Data:', JSON.stringify(response.data, null, 2));
        
        if (response.data.success) {
            console.log('✅ Order created successfully!');
            console.log('🔗 Payment URL:', response.data.paymentUrl);
            console.log('🆔 Payment Source ID:', response.data.order.paymentSourceId);
            console.log('🆔 Order ID:', response.data.order.id);
        } else {
            console.error('❌ Order creation failed:', response.data.message);
        }
        
    } catch (error) {
        console.error('❌ Test failed with error:', error.response?.data || error.message);
    }
}

testOrderCreation(); 