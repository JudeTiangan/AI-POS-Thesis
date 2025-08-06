const axios = require('axios');

// Demo PayPal Configuration for Thesis Presentation
const PAYPAL_DEMO_CONFIG = {
    CLIENT_ID: 'demo_client_id_for_thesis',
    CLIENT_SECRET: 'demo_client_secret_for_thesis',
    BASE_URL: 'https://api-m.sandbox.paypal.com',
    IS_DEMO_MODE: true
};

// Demo PayPal API Helper
class PayPalDemoAPI {
    constructor() {
        this.isDemoMode = true;
        console.log('🎭 PayPal Demo Mode: Active for Thesis Presentation');
    }

    /**
     * Simulate PayPal Access Token
     */
    async getAccessToken() {
        console.log('🎭 Demo: Getting PayPal access token...');
        return 'demo_access_token_' + Date.now();
    }

    /**
     * Create Demo PayPal Order with Real PayPal URL
     */
    async createPayPalOrder(paymentData) {
        try {
            const { amount, currency, description, metadata, returnUrl, cancelUrl } = paymentData;
            
            console.log('🎭 Demo: Creating PayPal order...');
            console.log('💰 Amount:', amount, currency);
            console.log('📝 Description:', description);
            
            // Simulate API delay
            await new Promise(resolve => setTimeout(resolve, 1000));
            
            // Generate demo PayPal order ID
            const demoOrderId = 'PAY-' + Math.random().toString(36).substr(2, 9).toUpperCase();
            
            // Create custom PayPal demo checkout URL
            // This will open our realistic PayPal demo page
            const baseUrl = process.env.BACKEND_URL || process.env.FRONTEND_URL || 'https://ai-pos-backend.onrender.com';
            const demoPaymentUrl = `${baseUrl}/api/orders/paypal-demo.html?orderId=${demoOrderId}&amount=₱${amount}&total=₱${amount}`;
            
            console.log('🎭 Demo PayPal URL generated:', demoPaymentUrl);
            console.log('🎭 Base URL used:', baseUrl);
            
            console.log('✅ Demo: PayPal order created successfully');
            console.log('🔗 Demo Payment URL:', demoPaymentUrl);
            
            return {
                success: true,
                orderId: demoOrderId,
                paymentUrl: demoPaymentUrl,
                orderData: {
                    id: demoOrderId,
                    status: 'CREATED',
                    intent: 'CAPTURE',
                    links: [
                        {
                            rel: 'approve',
                            href: demoPaymentUrl
                        }
                    ]
                }
            };
        } catch (error) {
            console.error('❌ Demo PayPal error:', error);
            return {
                success: false,
                error: 'Demo PayPal payment creation failed'
            };
        }
    }

    /**
     * Simulate PayPal Payment Capture
     */
    async capturePayment(orderId) {
        console.log('🎭 Demo: Capturing PayPal payment for order:', orderId);
        
        // Simulate API delay
        await new Promise(resolve => setTimeout(resolve, 1500));
        
        const demoCaptureId = 'CAPTURE-' + Math.random().toString(36).substr(2, 9).toUpperCase();
        
        console.log('✅ Demo: PayPal payment captured successfully');
        
        return {
            success: true,
            captureId: demoCaptureId,
            status: 'COMPLETED',
            captureData: {
                id: demoCaptureId,
                status: 'COMPLETED'
            }
        };
    }

    /**
     * Get Demo PayPal Order Details
     */
    async getOrderDetails(orderId) {
        console.log('🎭 Demo: Getting PayPal order details for:', orderId);
        
        return {
            success: true,
            orderData: {
                id: orderId,
                status: 'COMPLETED',
                intent: 'CAPTURE'
            }
        };
    }

    /**
     * Demo Webhook Verification
     */
    verifyWebhookSignature(payload, signature) {
        console.log('🎭 Demo: Verifying PayPal webhook signature...');
        return true; // Always return true in demo mode
    }
}

// Create and export demo PayPal API instance
const paypalDemoAPI = new PayPalDemoAPI();

module.exports = {
    paypalDemoAPI,
    PAYPAL_DEMO_CONFIG
}; 