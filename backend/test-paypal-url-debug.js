const { paypalDemoAPI } = require('./config/paypal-demo');

async function testPayPalURLDebug() {
    console.log('🔗 Testing PayPal Demo URL Generation (Debug Mode)...\n');
    
    try {
        // Test with different base URLs
        const testUrls = [
            'https://your-app.onrender.com',
            'https://ai-pos-backend.onrender.com',
            'http://localhost:3000'
        ];
        
        for (const baseUrl of testUrls) {
            console.log(`\n🧪 Testing with base URL: ${baseUrl}`);
            
            // Temporarily set the environment variable
            process.env.FRONTEND_URL = baseUrl;
            
            const paymentData = {
                amount: 102.50,
                currency: 'PHP',
                description: 'GENSUGGEST POS Demo Order',
                metadata: {
                    orderId: 'DEMO-ORDER-123',
                    customerName: 'Demo Customer',
                    customerEmail: 'demo@example.com',
                    itemCount: '1'
                },
                returnUrl: `${baseUrl}/payment-success`,
                cancelUrl: `${baseUrl}/payment-failed`
            };
            
            const orderResult = await paypalDemoAPI.createPayPalOrder(paymentData);
            
            if (orderResult.success) {
                console.log('✅ URL Generated Successfully!');
                console.log('   Order ID:', orderResult.orderId);
                console.log('   Payment URL:', orderResult.paymentUrl);
                console.log('   URL Valid:', orderResult.paymentUrl.startsWith('http'));
            } else {
                console.error('❌ URL generation failed:', orderResult.error);
            }
        }
        
    } catch (error) {
        console.error('❌ Test failed:', error);
    }
}

// Run the test
testPayPalURLDebug(); 