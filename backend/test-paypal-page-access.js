const http = require('http');
const https = require('https');

async function testPayPalPageAccess() {
    console.log('🔗 Testing PayPal Demo Page Access...\n');
    
    const testUrls = [
        'https://your-app.onrender.com/api/orders/paypal-demo.html',
        'https://ai-pos-backend.onrender.com/api/orders/paypal-demo.html',
        'http://localhost:3000/api/orders/paypal-demo.html'
    ];
    
    for (const url of testUrls) {
        console.log(`\n🧪 Testing URL: ${url}`);
        
        try {
            const urlObj = new URL(url);
            const options = {
                hostname: urlObj.hostname,
                port: urlObj.port || (urlObj.protocol === 'https:' ? 443 : 80),
                path: urlObj.pathname + urlObj.search,
                method: 'GET',
                timeout: 10000
            };
            
            const client = urlObj.protocol === 'https:' ? https : http;
            
            const req = client.request(options, (res) => {
                console.log(`   Status: ${res.statusCode}`);
                console.log(`   Headers: ${JSON.stringify(res.headers)}`);
                
                let data = '';
                res.on('data', (chunk) => {
                    data += chunk;
                });
                
                res.on('end', () => {
                    console.log(`   Content Length: ${data.length} characters`);
                    console.log(`   Content Preview: ${data.substring(0, 200)}...`);
                    
                    if (res.statusCode === 200) {
                        console.log('   ✅ Page accessible!');
                    } else {
                        console.log('   ❌ Page not accessible');
                    }
                });
            });
            
            req.on('error', (err) => {
                console.log(`   ❌ Error: ${err.message}`);
            });
            
            req.on('timeout', () => {
                console.log('   ❌ Timeout');
                req.destroy();
            });
            
            req.end();
            
        } catch (error) {
            console.log(`   ❌ Error testing URL: ${error.message}`);
        }
    }
}

// Run the test
testPayPalPageAccess(); 