const { paypalDemoAPI } = require('./config/paypal-demo');

async function testUrlGeneration() {
    console.log('🧪 Testing URL Generation...\n');
    
    try {
        // Test with different base URLs
        const testUrls = [
            'https://ai-pos-backend.onrender.com',
            'http://localhost:3000',
            process.env.FRONTEND_URL || 'https://your-app.onrender.com',
            process.env.BACKEND_URL || 'https://ai-pos-backend.onrender.com'
        ];
        
        console.log('🔍 Environment Variables:');
        console.log('FRONTEND_URL:', process.env.FRONTEND_URL);
        console.log('BACKEND_URL:', process.env.BACKEND_URL);
        console.log('NODE_ENV:', process.env.NODE_ENV);
        
        console.log('\n📋 Testing URL generation with different base URLs:');
        
        testUrls.forEach((baseUrl, index) => {
            const demoOrderId = 'PAY-' + Math.random().toString(36).substr(2, 9).toUpperCase();
            const amount = 150.00;
            const demoPaymentUrl = `${baseUrl}/api/orders/paypal-demo.html?orderId=${demoOrderId}&amount=₱${amount}&total=₱${amount}`;
            
            console.log(`\n${index + 1}. Base URL: ${baseUrl}`);
            console.log(`   Generated URL: ${demoPaymentUrl}`);
        });
        
        // Test the actual PayPal demo API
        console.log('\n📋 Testing PayPal Demo API:');
        const paymentData = {
            amount: 150.00,
            currency: 'PHP',
            description: 'Test Order',
            metadata: { orderId: 'TEST123' },
            returnUrl: 'https://ai-pos-backend.onrender.com/api/orders/payment-success',
            cancelUrl: 'https://ai-pos-backend.onrender.com/api/orders/payment-failed'
        };
        
        const result = await paypalDemoAPI.createPayPalOrder(paymentData);
        console.log('✅ PayPal Demo API Result:', JSON.stringify(result, null, 2));
        
    } catch (error) {
        console.error('❌ Test failed:', error);
    }
}

testUrlGeneration(); 