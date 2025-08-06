const { paypalDemoAPI } = require('./config/paypal-demo');

async function testURLGeneration() {
    console.log('🔗 Testing PayPal Demo URL Generation...\n');
    
    try {
        const paymentData = {
            amount: 157.50,
            currency: 'PHP',
            description: 'GENSUGGEST POS Demo Order',
            metadata: {
                orderId: 'DEMO-ORDER-123',
                customerName: 'Demo Customer',
                customerEmail: 'demo@example.com',
                itemCount: '2'
            },
            returnUrl: 'https://your-app.onrender.com/payment-success',
            cancelUrl: 'https://your-app.onrender.com/payment-failed'
        };
        
        const orderResult = await paypalDemoAPI.createPayPalOrder(paymentData);
        
        if (orderResult.success) {
            console.log('✅ PayPal Demo URL Generated Successfully!');
            console.log('   Order ID:', orderResult.orderId);
            console.log('   Payment URL:', orderResult.paymentUrl);
            console.log('\n🎯 To Test:');
            console.log('   1. Copy the Payment URL above');
            console.log('   2. Open it in your browser');
            console.log('   3. You should see a realistic PayPal checkout page');
            console.log('   4. It will auto-process after 8 seconds');
            console.log('\n🚀 For Your Thesis:');
            console.log('   - This URL will be generated when you select PayPal payment');
            console.log('   - Your professors will see a professional PayPal interface');
            console.log('   - Complete payment flow with success confirmation');
        } else {
            console.error('❌ URL generation failed:', orderResult.error);
        }
        
    } catch (error) {
        console.error('❌ Test failed:', error);
    }
}

// Run the test
testURLGeneration(); 