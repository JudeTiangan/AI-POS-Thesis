const { paypalAPI } = require('./config/paypal');

async function testPayPalIntegration() {
    console.log('🧪 Testing PayPal Integration...\n');

    try {
        // Test 1: Get Access Token
        console.log('1️⃣ Testing PayPal Access Token...');
        const accessToken = await paypalAPI.getAccessToken();
        console.log('✅ Access Token obtained:', accessToken.substring(0, 20) + '...');
        console.log('');

        // Test 2: Create PayPal Order
        console.log('2️⃣ Testing PayPal Order Creation...');
        const orderData = {
            amount: 100.00,
            currency: 'PHP',
            description: 'Test Order #12345',
            metadata: {
                orderId: '12345',
                customerName: 'Test Customer',
                customerEmail: 'test@example.com',
                itemCount: '2'
            },
            returnUrl: 'http://localhost:3000/public/payment-success.html',
            cancelUrl: 'http://localhost:3000/public/payment-cancel.html'
        };

        const orderResult = await paypalAPI.createPayPalOrder(orderData);
        
        if (orderResult.success) {
            console.log('✅ PayPal Order created successfully!');
            console.log('📋 Order ID:', orderResult.orderId);
            console.log('🔗 Payment URL:', orderResult.paymentUrl);
            console.log('');

            // Test 3: Get Order Details
            console.log('3️⃣ Testing PayPal Order Details...');
            const detailsResult = await paypalAPI.getOrderDetails(orderResult.orderId);
            
            if (detailsResult.success) {
                console.log('✅ Order details retrieved successfully!');
                console.log('📊 Order Status:', detailsResult.orderData.status);
                console.log('💰 Amount:', detailsResult.orderData.purchase_units[0].amount.value, detailsResult.orderData.purchase_units[0].amount.currency_code);
                console.log('');

                // Test 4: Capture Payment (Note: This would normally be done after customer approval)
                console.log('4️⃣ Testing PayPal Payment Capture...');
                console.log('⚠️  Note: Payment capture requires customer approval first');
                console.log('📋 Order ID for capture:', orderResult.orderId);
                console.log('💡 In production, this would be called after customer completes payment');
                console.log('');

            } else {
                console.log('❌ Failed to get order details:', detailsResult.error);
            }

        } else {
            console.log('❌ Failed to create PayPal order:', orderResult.error);
        }

        console.log('🎉 PayPal Integration Test Complete!');
        console.log('');
        console.log('📝 Next Steps:');
        console.log('1. Set up your PayPal Business account');
        console.log('2. Get your Client ID and Client Secret');
        console.log('3. Configure webhooks for payment notifications');
        console.log('4. Test with PayPal Sandbox first');
        console.log('5. Deploy to production with live PayPal credentials');

    } catch (error) {
        console.error('❌ PayPal Integration Test Failed:', error.message);
        console.log('');
        console.log('🔧 Troubleshooting:');
        console.log('1. Check your PayPal credentials in .env file');
        console.log('2. Verify PayPal API endpoints are accessible');
        console.log('3. Ensure you have a valid PayPal Business account');
        console.log('4. Test with PayPal Sandbox environment first');
    }
}

// Run the test
testPayPalIntegration(); 