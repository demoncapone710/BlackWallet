# Deploy BlackWallet to Railway.app (FREE Hosting)

## What You Get
- ✅ Free domain: `blackwallet-api.railway.app`
- ✅ Automatic HTTPS
- ✅ Auto-deploys from GitHub
- ✅ Free $5/month credit (enough for small projects)
- ✅ PostgreSQL database (better than SQLite)

## Step-by-Step Setup

### 1. Sign Up for Railway
1. Go to https://railway.app
2. Click "Login" → "Login with GitHub"
3. Authorize Railway to access your GitHub

### 2. Push Your Code to GitHub (If Not Already)
```powershell
# In BlackWallet folder
cd C:\Users\demon\BlackWallet

# Initialize git (if not already)
git init
git add .
git commit -m "Initial commit with Stripe integration"

# Create repo on GitHub, then:
git remote add origin https://github.com/demoncapone710/BlackWallet.git
git branch -M main
git push -u origin main
```

### 3. Deploy to Railway

#### Option A: Via Web Dashboard (Easiest)
1. Go to https://railway.app/new
2. Click "Deploy from GitHub repo"
3. Select your `BlackWallet` repository
4. Railway will detect Python and deploy automatically!
5. Click on "Settings" → Add these environment variables:
   ```
   STRIPE_SECRET_KEY=<your-stripe-secret-key-from-dashboard>
   STRIPE_PUBLISHABLE_KEY=<your-stripe-publishable-key>
   SECRET_KEY=<generate-random-secret-for-jwt>
   TWILIO_ACCOUNT_SID=<your-twilio-account-sid>
   TWILIO_AUTH_TOKEN=<your-twilio-auth-token>
   TWILIO_PHONE_NUMBER=<your-twilio-phone-number>
   ```
   
   **Note:** Get your actual keys from:
   - Stripe: https://dashboard.stripe.com/test/apikeys
   - Twilio: https://console.twilio.com
6. Click "Generate Domain" to get your URL

#### Option B: Via CLI (For Power Users)
```powershell
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Initialize project
cd ewallet_backend
railway init

# Add environment variables (replace with your actual keys)
railway variables set STRIPE_SECRET_KEY="<your-stripe-secret-key>"
railway variables set STRIPE_PUBLISHABLE_KEY="<your-stripe-publishable-key>"

# Deploy
railway up
```

### 4. Files Railway Needs

Create these files in `ewallet_backend/`:

**Procfile** (tells Railway how to run your app):
```
web: uvicorn main:app --host 0.0.0.0 --port $PORT
```

**railway.json** (optional, for configuration):
```json
{
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "pip install -r requirements.txt"
  },
  "deploy": {
    "startCommand": "uvicorn main:app --host 0.0.0.0 --port $PORT",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

**runtime.txt** (specify Python version):
```
python-3.13
```

### 5. Update Flutter App

Once deployed, update your Flutter app's API URL:

In `lib/services/api_service.dart`:
```dart
// Change from:
static const String baseUrl = 'http://10.0.0.104:8000';

// To:
static const String baseUrl = 'https://blackwallet-api.railway.app';
```

### 6. Add Webhook URL to Stripe

Once deployed:
1. Go to https://dashboard.stripe.com/test/webhooks
2. Click "Add endpoint"
3. URL: `https://blackwallet-api.railway.app/api/webhooks/stripe`
4. Select events: `payment_intent.succeeded`, `transfer.created`, `payout.paid`
5. Copy "Signing secret" and add to Railway environment variables:
   ```
   STRIPE_WEBHOOK_SECRET=whsec_xxxxx
   ```

---

## Alternative: Render.com (Also Free)

1. Go to https://render.com
2. Click "Get Started for Free"
3. Connect GitHub
4. Click "New +" → "Web Service"
5. Select your BlackWallet repo
6. Configure:
   - Name: `blackwallet-api`
   - Environment: `Python 3`
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
7. Add environment variables (same as Railway)
8. Click "Create Web Service"
9. Your domain: `blackwallet-api.onrender.com`

---

## Costs (All Options)

### Railway
- **Free tier**: $5/month credit
- Your usage: ~$2-3/month (well within free tier)
- Upgrade if needed: $5/month for 500 hours

### Render
- **Free tier**: Unlimited (but servers sleep after inactivity)
- Paid: $7/month for always-on

### Heroku
- **No longer free** (minimum $5/month)

---

## Recommendation

**For now**: ⏸️ **Skip deployment**
- Finish building features locally
- Test everything on your phone
- Deploy when you're ready to share with others

**When ready to deploy**: 🚀 **Use Railway**
- Fastest setup
- Best free tier
- Great developer experience
- Easy to upgrade later

---

## Need Help?

If you want to deploy now, let me know and I'll:
1. Create the necessary config files
2. Walk you through Railway setup
3. Help configure the domain
4. Update your Flutter app

But I recommend: **Build first, deploy later!** 🛠️
