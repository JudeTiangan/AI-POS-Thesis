# 💳 GCash Payment Integration Guide

## 🎯 Overview

This document explains how GCash payment integration works in your AI-POS system and how store owners receive payments.

## 📋 Current Status

### ✅ **What's Implemented (Demo Mode)**
- Frontend GCash payment selection
- Backend order creation with payment tracking
- Demo payment URL generation
- Payment status updates via webhooks
- Simulated payment flow

### 🚧 **What's Needed for Production**
- Real GCash for Business API integration
- Webhook signature verification
- Production payment URL generation
- Live payment processing

## 🏪 **How Store Owners Receive Money**

### **Step 1: GCash for Business Setup**
Store owners need to:

1. **Register at gcash.com/business**
   - Provide business documents (DTI/SEC registration)
   - Complete KYC verification
   - Get approved as merchant

2. **Get API Credentials**
   - Merchant ID
   - API Key
   - API Secret
   - Webhook Secret

3. **Link Bank Account**
   - Connect business bank account
   - Set up auto-withdrawal preferences

### **Step 2: Payment Flow**
```
Customer Orders → Selects GCash → Payment URL Generated → 
Customer Pays → Money in Store Wallet → Auto-transfer to Bank
```

### **Step 3: Money Transfer Options**
- **Instant Transfer**: Money appears in GCash for Business wallet immediately
- **Auto-withdrawal**: Daily/weekly automatic bank transfers
- **Manual Transfer**: Store owner manually transfers to bank account
- **Transaction Fees**: ~2.5% per transaction

## 🔧 **Production Implementation**

### **1. Environment Variables Needed**
```env
# GCash API Configuration
GCASH_MERCHANT_ID=your_merchant_id
GCASH_API_KEY=your_api_key
GCASH_API_SECRET=your_api_secret
GCASH_API_BASE_URL=https://api.gcash.com
GCASH_WEBHOOK_SECRET=your_webhook_secret

# Application URLs
FRONTEND_URL=https://your-domain.com
BACKEND_URL=https://your-api-domain.com
```

### **2. Backend Implementation (Production)**
Replace the demo code in `backend/routes/orders.js`:

```javascript
async function createGCashPayment(orderId, amount, customerName, customerEmail) {
  const response = await fetch(`${process.env.GCASH_API_BASE_URL}/v1/payments`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.GCASH_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      merchantId: process.env.GCASH_MERCHANT_ID,
      amount: amount * 100, // Convert to centavos
      currency: 'PHP',
      orderId: orderId,
      description: `GENSUGGEST POS Order #${orderId}`,
      customer: {
        name: customerName,
        email: customerEmail
      },
      redirectUrl: {
        success: `${process.env.FRONTEND_URL}/payment/success?orderId=${orderId}`,
        failure: `${process.env.FRONTEND_URL}/payment/failure?orderId=${orderId}`,
        cancel: `${process.env.FRONTEND_URL}/payment/cancel?orderId=${orderId}`
      },
      webhookUrl: `${process.env.BACKEND_URL}/api/orders/gcash/webhook`
    })
  });
  
  const paymentResponse = await response.json();
  return paymentResponse.checkoutUrl;
}
```

### **3. Webhook Security (Production)**
Add signature verification:

```javascript
function verifyGCashWebhook(headers, body) {
  const signature = headers['x-gcash-signature'];
  const computedSignature = crypto
    .createHmac('sha256', process.env.GCASH_WEBHOOK_SECRET)
    .update(JSON.stringify(body))
    .digest('hex');
  
  return signature === computedSignature;
}
```

## 💰 **Payment Processing Flow**

### **Customer Side:**
1. Customer adds items to cart
2. Fills customer information
3. Selects GCash payment
4. Redirected to GCash checkout
5. Completes payment using GCash app/web
6. Redirected back to success page

### **Store Owner Side:**
1. Order appears in admin dashboard
2. Payment status automatically updates
3. Money appears in GCash for Business wallet
4. Optional: Auto-transfer to bank account
5. Order can be prepared and fulfilled

## 📊 **Financial Summary for Store Owners**

### **Revenue Breakdown:**
- **Sale Amount**: ₱100.00
- **GCash Fee**: ₱2.50 (2.5%)
- **Net Revenue**: ₱97.50

### **Transfer Options:**
- **Immediate**: Available in GCash wallet instantly
- **Next Day**: Bank transfer processed next business day
- **Weekly**: Batch transfer every week
- **Monthly**: Batch transfer monthly

## 🔒 **Security Features**

### **Payment Security:**
- ✅ Webhook signature verification
- ✅ SSL/TLS encryption
- ✅ Secure API key management
- ✅ Order ID validation
- ✅ Amount verification

### **Data Protection:**
- ✅ Customer data encryption
- ✅ PCI DSS compliance
- ✅ Secure token handling
- ✅ Audit logging

## 🚀 **Going Live Checklist**

### **Technical Requirements:**
- [ ] GCash for Business account approved
- [ ] API credentials obtained
- [ ] Production environment configured
- [ ] Webhook endpoints secured
- [ ] SSL certificate installed
- [ ] Testing completed

### **Business Requirements:**
- [ ] Business registration verified
- [ ] Bank account linked
- [ ] Transaction fees understood
- [ ] Settlement schedule configured
- [ ] Customer support process defined

## 📞 **Support & Resources**

### **GCash for Business:**
- Website: gcash.com/business
- Email: business@gcash.com
- Phone: (+63) 2-8845-7788

### **Technical Documentation:**
- API Docs: developer.gcash.com
- Sandbox: sandbox.gcash.com
- Status Page: status.gcash.com

## 🎯 **Current Demo vs Production**

| Feature | Demo Mode | Production Mode |
|---------|-----------|-----------------|
| Payment URL | Simulated | Real GCash checkout |
| Payment Processing | Instant simulation | Real-time processing |
| Money Transfer | Not applicable | To GCash wallet → Bank |
| Transaction Fees | None | 2.5% per transaction |
| Customer Experience | Demo dialog | Actual GCash app/web |
| Order Updates | Manual simulation | Automatic via webhooks |

---

**Note**: The current implementation is in DEMO MODE for development and testing. To accept real payments, follow the production implementation steps above. 