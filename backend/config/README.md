# 🔧 Backend Configuration Guide

## 🔑 **Required Environment Variables**

### **For Local Development:**
Create a `.env` file in the `/backend` folder with these values:

```env
# PayMongo API Keys (Get from https://dashboard.paymongo.com/developers)
PAYMONGO_PUBLIC_KEY=pk_test_your_actual_public_key
PAYMONGO_SECRET_KEY=sk_test_your_actual_secret_key
PAYMONGO_WEBHOOK_SECRET=your_webhook_secret

# Firebase Configuration (Get from serviceAccountKey.json)
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY_ID=your-private-key-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nyour-private-key-here\n-----END PRIVATE KEY-----"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
FIREBASE_CLIENT_ID=your-client-id
FIREBASE_CLIENT_CERT_URL=https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com

# Application Configuration
NODE_ENV=development
PORT=3000
```

### **For Production Deployment:**
Set these environment variables in your hosting platform (Railway, Render, etc.):

- `NODE_ENV=production`
- `PAYMONGO_PUBLIC_KEY=pk_test_your_actual_public_key`
- `PAYMONGO_SECRET_KEY=sk_test_your_actual_secret_key`
- All Firebase variables from above

## 📄 **Firebase Service Account Key**

For local development, you can still use the `serviceAccountKey.json` file:
1. Download from Firebase Console → Project Settings → Service Accounts
2. Save as `backend/config/serviceAccountKey.json`
3. The file is already in `.gitignore` for security

## 🔒 **Security Notes**

- ✅ **Never commit** actual API keys to Git
- ✅ **Use environment variables** for production
- ✅ **Keep serviceAccountKey.json** in .gitignore
- ✅ **Use placeholder values** in documentation

## 🎯 **For Thesis Testing**

The actual PayMongo test keys for this project are available from the instructor or can be obtained from:
- PayMongo Dashboard: https://dashboard.paymongo.com/developers
- Create free test account to get your own keys 