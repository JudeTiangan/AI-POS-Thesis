const axios = require('axios');
const crypto = require('crypto');

// PayMongo Configuration
const PAYMONGO_CONFIG = {
    // Replace these with your actual PayMongo keys from https://dashboard.paymongo.com/developers
    PUBLIC_KEY: process.env.PAYMONGO_PUBLIC_KEY || 'pk_test_your_public_key_here',
    SECRET_KEY: process.env.PAYMONGO_SECRET_KEY || 'sk_test_your_secret_key_here',
    BASE_URL: 'https://api.paymongo.com/v1',
    WEBHOOK_SECRET: process.env.PAYMONGO_WEBHOOK_SECRET || 'your_webhook_secret_here'
};

// Environment-based URLs
const getRedirectUrls = () => {
    const isDevelopment = process.env.NODE_ENV !== 'production';
    const baseUrl = isDevelopment 
        ? 'http://localhost:3000'
        : process.env.FRONTEND_URL || 'https://your-production-domain.com';
    
    return {
        success: `${baseUrl}/public/payment-success.html`,
        failed: `${baseUrl}/public/payment-failure.html`
    };
};

// PayMongo API Helper
class PayMongoAPI {
    constructor() {
        this.client = axios.create({
            baseURL: PAYMONGO_CONFIG.BASE_URL,
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Basic ${Buffer.from(PAYMONGO_CONFIG.SECRET_KEY + ':').toString('base64')}`
            }
        });
    }

    /**
     * Create GCash Payment using Sources API (Recommended)
     * @param {Object} paymentData - Payment details
     * @returns {Promise<Object>} Payment source response
     */
    async createGCashPayment(paymentData) {
        try {
            const { amount, currency, description, metadata } = paymentData;
            
            // PayMongo minimum amount validation (2000 centavos = 20 PHP)
            const amountInCentavos = Math.round(amount * 100);
            if (amountInCentavos < 2000) {
                return {
                    success: false,
                    error: `Minimum amount for GCash payments is 20 PHP. Current amount: ${amount} PHP`
                };
            }
            
            // Get environment-appropriate redirect URLs
            const redirectUrls = getRedirectUrls();
            
            // Create GCash source using Sources API
            const response = await this.client.post('/sources', {
                data: {
                    attributes: {
                        amount: amountInCentavos, // Convert to centavos
                        currency: currency || 'PHP',
                        type: 'gcash',
                        redirect: {
                            success: metadata.successUrl || redirectUrls.success,
                            failed: metadata.failedUrl || redirectUrls.failed
                        },
                        description: description,
                        metadata: metadata
                    }
                }
            });

            return {
                success: true,
                paymentIntent: response.data.data,
                paymentUrl: response.data.data.attributes.redirect.checkout_url
            };
        } catch (error) {
            console.error('PayMongo GCash creation error:', error.response?.data || error.message);
            return {
                success: false,
                error: error.response?.data?.errors || error.message
            };
        }
    }



    /**
     * Get Payment Source Status
     * @param {string} paymentSourceId - Payment source ID
     * @returns {Promise<Object>} Payment status
     */
    async getPaymentStatus(paymentSourceId) {
        try {
            const response = await this.client.get(`/sources/${paymentSourceId}`);
            return {
                success: true,
                paymentIntent: response.data.data
            };
        } catch (error) {
            console.error('PayMongo status check error:', error.response?.data || error.message);
            return {
                success: false,
                error: error.response?.data?.errors || error.message
            };
        }
    }

    /**
     * Verify webhook signature
     * @param {string} payload - Raw webhook payload
     * @param {string} signature - Webhook signature
     * @returns {boolean} Is signature valid
     */
    verifyWebhookSignature(payload, signature) {
        try {
            const computedSignature = crypto
                .createHmac('sha256', PAYMONGO_CONFIG.WEBHOOK_SECRET)
                .update(payload, 'utf8')
                .digest('hex');
            
            return computedSignature === signature;
        } catch (error) {
            console.error('Webhook signature verification error:', error);
            return false;
        }
    }
}

module.exports = {
    PayMongoAPI,
    PAYMONGO_CONFIG
}; 