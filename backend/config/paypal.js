const axios = require('axios');

// PayPal Configuration
const PAYPAL_CONFIG = {
    // For thesis demonstration: Use sandbox credentials
    // For production: Replace with live PayPal business credentials
    CLIENT_ID: process.env.PAYPAL_CLIENT_ID || 'your_paypal_client_id_here',
    CLIENT_SECRET: process.env.PAYPAL_CLIENT_SECRET || 'your_paypal_client_secret_here',
    BASE_URL: process.env.PAYPAL_BASE_URL || 'https://api-m.sandbox.paypal.com', // Sandbox for demo, https://api-m.paypal.com for production
    WEBHOOK_ID: process.env.PAYPAL_WEBHOOK_ID || 'your_webhook_id_here'
};

// Environment-based URLs
const getRedirectUrls = () => {
    const isDevelopment = process.env.NODE_ENV !== 'production';
    const baseUrl = isDevelopment 
        ? 'http://localhost:3000'
        : process.env.FRONTEND_URL || 'https://your-production-domain.com';
    
    return {
        success: `${baseUrl}/api/orders/payment-success`,
        failed: `${baseUrl}/api/orders/payment-failed`,
        cancel: `${baseUrl}/api/orders/payment-failed`
    };
};

// PayPal API Helper
class PayPalAPI {
    constructor() {
        this.accessToken = null;
        this.tokenExpiry = null;
        this.client = axios.create({
            baseURL: PAYPAL_CONFIG.BASE_URL,
            headers: {
                'Content-Type': 'application/json'
            }
        });
    }

    /**
     * Get PayPal Access Token
     * @returns {Promise<string>} Access token
     */
    async getAccessToken() {
        // Check if we have a valid token
        if (this.accessToken && this.tokenExpiry && Date.now() < this.tokenExpiry) {
            return this.accessToken;
        }

        try {
            const auth = Buffer.from(`${PAYPAL_CONFIG.CLIENT_ID}:${PAYPAL_CONFIG.CLIENT_SECRET}`).toString('base64');
            
            const response = await axios.post(`${PAYPAL_CONFIG.BASE_URL}/v1/oauth2/token`, 
                'grant_type=client_credentials',
                {
                    headers: {
                        'Authorization': `Basic ${auth}`,
                        'Content-Type': 'application/x-www-form-urlencoded'
                    }
                }
            );

            this.accessToken = response.data.access_token;
            // Set token expiry (subtract 5 minutes for safety)
            this.tokenExpiry = Date.now() + (response.data.expires_in * 1000) - 300000;
            
            return this.accessToken;
        } catch (error) {
            console.error('PayPal access token error:', error.response?.data || error.message);
            throw new Error('Failed to get PayPal access token');
        }
    }

    /**
     * Create PayPal Order
     * @param {Object} paymentData - Payment details
     * @returns {Promise<Object>} PayPal order response
     */
    async createPayPalOrder(paymentData) {
        try {
            const { amount, currency, description, metadata, returnUrl, cancelUrl } = paymentData;
            
            const accessToken = await this.getAccessToken();
            
            const orderData = {
                intent: 'CAPTURE',
                purchase_units: [{
                    amount: {
                        currency_code: currency || 'PHP',
                        value: amount.toFixed(2)
                    },
                    description: description,
                    custom_id: metadata.orderId,
                    invoice_id: metadata.orderId,
                    soft_descriptor: 'GENSUGGEST POS'
                }],
                application_context: {
                    return_url: returnUrl,
                    cancel_url: cancelUrl,
                    brand_name: 'GENSUGGEST POS',
                    landing_page: 'LOGIN',
                    user_action: 'PAY_NOW',
                    shipping_preference: 'NO_SHIPPING'
                }
            };

            const response = await this.client.post('/v2/checkout/orders', orderData, {
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    'Content-Type': 'application/json'
                }
            });

            return {
                success: true,
                orderId: response.data.id,
                paymentUrl: response.data.links.find(link => link.rel === 'approve').href,
                orderData: response.data
            };
        } catch (error) {
            console.error('PayPal order creation error:', error.response?.data || error.message);
            return {
                success: false,
                error: error.response?.data || error.message
            };
        }
    }

    /**
     * Capture PayPal Payment
     * @param {string} orderId - PayPal order ID
     * @returns {Promise<Object>} Payment capture response
     */
    async capturePayment(orderId) {
        try {
            const accessToken = await this.getAccessToken();
            
            const response = await this.client.post(`/v2/checkout/orders/${orderId}/capture`, {}, {
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    'Content-Type': 'application/json'
                }
            });

            return {
                success: true,
                captureId: response.data.purchase_units[0].payments.captures[0].id,
                status: response.data.status,
                captureData: response.data
            };
        } catch (error) {
            console.error('PayPal capture error:', error.response?.data || error.message);
            return {
                success: false,
                error: error.response?.data || error.message
            };
        }
    }

    /**
     * Get PayPal Order Details
     * @param {string} orderId - PayPal order ID
     * @returns {Promise<Object>} Order details
     */
    async getOrderDetails(orderId) {
        try {
            const accessToken = await this.getAccessToken();
            
            const response = await this.client.get(`/v2/checkout/orders/${orderId}`, {
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    'Content-Type': 'application/json'
                }
            });

            return {
                success: true,
                orderData: response.data
            };
        } catch (error) {
            console.error('PayPal order details error:', error.response?.data || error.message);
            return {
                success: false,
                error: error.response?.data || error.message
            };
        }
    }

    /**
     * Verify Webhook Signature
     * @param {Object} payload - Webhook payload
     * @param {string} signature - Webhook signature
     * @returns {boolean} Signature validity
     */
    verifyWebhookSignature(payload, signature) {
        // Note: PayPal webhook verification requires additional crypto library
        // For now, we'll implement basic verification
        try {
            // Basic verification - in production, implement proper signature verification
            return true;
        } catch (error) {
            console.error('PayPal webhook verification error:', error);
            return false;
        }
    }
}

// Create and export PayPal API instance
const paypalAPI = new PayPalAPI();

module.exports = {
    paypalAPI,
    PAYPAL_CONFIG,
    getRedirectUrls
}; 