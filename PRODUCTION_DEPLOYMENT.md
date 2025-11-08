# Production Deployment Guide - Moving from Localhost

Complete guide to deploying BlackWallet to production with webhooks enabled.

## Table of Contents
1. [Deployment Options](#deployment-options)
2. [Environment Configuration](#environment-configuration)
3. [Webhook Setup](#webhook-setup)
4. [Domain & SSL](#domain--ssl)
5. [Database Migration](#database-migration)
6. [Security Checklist](#security-checklist)
7. [Testing](#testing)

---

## Deployment Options

### Option 1: Railway (Recommended - Easiest)
**Pros:** Free tier, automatic HTTPS, easy deployment, built-in PostgreSQL
**Cons:** Limited free hours

### Option 2: Render
**Pros:** Free tier, PostgreSQL included, good documentation
**Cons:** Spins down on inactivity

### Option 3: DigitalOcean App Platform
**Pros:** Professional hosting, scalable, good performance
**Cost:** ~$5-12/month

### Option 4: AWS (EC2 + RDS)
**Pros:** Full control, highly scalable
**Cons:** More complex setup, higher cost

### Option 5: Heroku
**Pros:** Easy deployment, many add-ons
**Cost:** $7/month minimum (no free tier)

---

## Quick Start: Railway Deployment (Recommended)

### Step 1: Prepare Your Code

1. **Create `.gitignore`** (if not exists):
```gitignore
__pycache__/
*.pyc
*.pyo
*.db
*.sqlite3
.env
.env.local
venv/
env/
.vscode/
logs/
backups/
ewallet.db
*.log
```

2. **Create `railway.json`**:
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "cd ewallet_backend && uvicorn main:app --host 0.0.0.0 --port $PORT",
    "healthcheckPath": "/",
    "healthcheckTimeout": 100
  }
}
```

3. **Create `Procfile`** (in root directory):
```
web: cd ewallet_backend && uvicorn main:app --host 0.0.0.0 --port $PORT
```

4. **Update `requirements.txt`** (in ewallet_backend/):
```txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
pydantic==2.5.0
pydantic-settings==2.1.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
stripe==7.8.0
twilio==8.10.0
requests==2.31.0
schedule==1.2.2
python-json-logger==2.0.7
email-validator==2.1.0
psycopg2-binary==2.9.9
gunicorn==21.2.0
```

### Step 2: Deploy to Railway

1. **Sign up at [Railway.app](https://railway.app)**

2. **Create New Project**:
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Connect your GitHub account
   - Select your BlackWallet repository

3. **Add PostgreSQL Database**:
   - In your project, click "+ New"
   - Select "Database" → "Add PostgreSQL"
   - Railway will provision a database automatically

4. **Configure Environment Variables**:
   Click on your service → Variables → Add all these:

```bash
# Application
ENVIRONMENT=production
DEBUG=False

# Database (Railway provides this automatically as DATABASE_URL)
# DATABASE_URL will be injected automatically

# Security - GENERATE NEW SECURE KEYS!
SECRET_KEY=your-super-secret-key-min-32-chars-change-this
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Stripe - Get from Stripe Dashboard
STRIPE_MODE=live
STRIPE_LIVE_SECRET_KEY=sk_live_your_key_here
STRIPE_LIVE_PUBLISHABLE_KEY=pk_live_your_key_here
STRIPE_LIVE_WEBHOOK_SECRET=whsec_your_webhook_secret_here

# Rate Limiting
RATE_LIMIT_ENABLED=True
RATE_LIMIT_PER_MINUTE=60

# CORS - Set to your Flutter app domain
CORS_ORIGINS=["https://yourapp.com","https://www.yourapp.com"]

# Logging
LOG_LEVEL=INFO
LOG_FORMAT=json

# Email (Optional - for notifications)
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASSWORD=your_sendgrid_api_key
SMTP_FROM_EMAIL=noreply@yourapp.com

# Twilio (Optional - for SMS)
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1234567890
```

5. **Generate Secure Secret Key**:
```python
# Run this in Python to generate a secure key
import secrets
print(secrets.token_urlsafe(32))
```

6. **Deploy**:
   - Railway will automatically deploy when you push to GitHub
   - Or click "Deploy" button in Railway dashboard

7. **Get Your URL**:
   - Railway provides: `https://your-app-name.up.railway.app`
   - Go to Settings → Domains to see your URL

### Step 3: Configure Stripe Webhooks

1. **Go to Stripe Dashboard** → Developers → Webhooks

2. **Add Endpoint**:
   - Endpoint URL: `https://your-app-name.up.railway.app/api/webhooks/stripe`
   - Description: "BlackWallet Production Webhook"

3. **Select Events to Listen To**:
   ```
   ✓ payment_intent.succeeded
   ✓ payment_intent.payment_failed
   ✓ charge.succeeded
   ✓ charge.failed
   ✓ charge.refunded
   ✓ charge.dispute.created
   ✓ customer.created
   ✓ customer.updated
   ✓ customer.deleted
   ✓ payment_method.attached
   ✓ payment_method.detached
   ✓ account.updated
   ✓ payout.paid
   ✓ payout.failed
   ✓ transfer.created
   ```

4. **Get Webhook Secret**:
   - After creating endpoint, click on it
   - Click "Reveal" under "Signing secret"
   - Copy the `whsec_...` value
   - Add to Railway environment variables as `STRIPE_LIVE_WEBHOOK_SECRET`

5. **Test Webhook**:
   - In Stripe dashboard, send test webhook
   - Check Railway logs to confirm receipt

---

## Alternative: Render Deployment

### Step 1: Create `render.yaml`

```yaml
services:
  - type: web
    name: blackwallet-api
    env: python
    region: oregon
    buildCommand: cd ewallet_backend && pip install -r requirements.txt
    startCommand: cd ewallet_backend && uvicorn main:app --host 0.0.0.0 --port $PORT
    envVars:
      - key: ENVIRONMENT
        value: production
      - key: SECRET_KEY
        generateValue: true
      - key: STRIPE_MODE
        value: live
      - key: DATABASE_URL
        fromDatabase:
          name: blackwallet-db
          property: connectionString

databases:
  - name: blackwallet-db
    databaseName: blackwallet
    user: blackwallet
```

### Step 2: Deploy to Render

1. Go to [Render.com](https://render.com)
2. New → Web Service
3. Connect GitHub repository
4. Render will auto-detect settings from `render.yaml`
5. Add environment variables
6. Deploy

---

## Environment Configuration

### Production Environment Variables

Create `.env.production` file (DO NOT COMMIT):

```bash
# Application Settings
APP_NAME=BlackWallet API
APP_VERSION=1.0.0
ENVIRONMENT=production
DEBUG=False
HOST=0.0.0.0
PORT=8000

# Database - Use PostgreSQL in production
DATABASE_URL=postgresql://user:password@host:5432/dbname

# Security
SECRET_KEY=your-super-secret-key-change-this
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# Rate Limiting
RATE_LIMIT_ENABLED=True
RATE_LIMIT_PER_MINUTE=60
RATE_LIMIT_AUTH_PER_MINUTE=5

# CORS - Replace with your actual domains
CORS_ORIGINS=["https://yourapp.com","https://api.yourapp.com"]
CORS_ALLOW_CREDENTIALS=True

# Stripe Live Mode
STRIPE_MODE=live
STRIPE_LIVE_SECRET_KEY=sk_live_...
STRIPE_LIVE_PUBLISHABLE_KEY=pk_live_...
STRIPE_LIVE_WEBHOOK_SECRET=whsec_...

# Email
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASSWORD=SG.your_api_key
SMTP_FROM_EMAIL=noreply@yourapp.com

# Twilio
TWILIO_ACCOUNT_SID=ACxxxxx
TWILIO_AUTH_TOKEN=your_token
TWILIO_PHONE_NUMBER=+1234567890

# Logging
LOG_LEVEL=INFO
LOG_FORMAT=json
LOG_FILE=/var/log/blackwallet/app.log

# Monitoring
SENTRY_DSN=https://your-sentry-dsn

# SSL
SSL_ENABLED=True
```

---

## Database Migration (SQLite → PostgreSQL)

### Option 1: Using pgloader (Easiest)

1. **Install pgloader**:
```bash
# On Ubuntu/Debian
sudo apt-get install pgloader

# On macOS
brew install pgloader
```

2. **Create migration script** `migrate_to_postgres.load`:
```
LOAD DATABASE
     FROM sqlite://ewallet.db
     INTO postgresql://user:password@host:5432/dbname
     
WITH include drop, create tables, create indexes, reset sequences
     
SET work_mem to '16MB', maintenance_work_mem to '512 MB';
```

3. **Run migration**:
```bash
pgloader migrate_to_postgres.load
```

### Option 2: Manual Export/Import

1. **Export SQLite data**:
```python
# export_data.py
import sqlite3
import json

conn = sqlite3.connect('ewallet.db')
cursor = conn.cursor()

# Get all tables
cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = cursor.fetchall()

data = {}
for table in tables:
    table_name = table[0]
    cursor.execute(f"SELECT * FROM {table_name}")
    data[table_name] = cursor.fetchall()
    
with open('backup_data.json', 'w') as f:
    json.dump(data, f)
    
conn.close()
```

2. **Import to PostgreSQL**:
```python
# import_data.py
import psycopg2
import json

# Connect to PostgreSQL
conn = psycopg2.connect(DATABASE_URL)
cursor = conn.cursor()

with open('backup_data.json', 'r') as f:
    data = json.load(f)

# Import data for each table
# (You'll need to create INSERT statements based on your schema)

conn.commit()
conn.close()
```

---

## Domain & SSL Configuration

### Option 1: Using Railway Custom Domain

1. **Add Custom Domain in Railway**:
   - Go to your service → Settings → Domains
   - Click "Add Custom Domain"
   - Enter your domain: `api.yourapp.com`

2. **Configure DNS**:
   - Add CNAME record in your DNS provider:
     ```
     Type: CNAME
     Name: api
     Value: your-app.up.railway.app
     TTL: 3600
     ```

3. **SSL Certificate**:
   - Railway automatically provisions SSL via Let's Encrypt
   - Wait 5-10 minutes for DNS propagation

### Option 2: Cloudflare (Recommended)

1. **Add Domain to Cloudflare**:
   - Sign up at [Cloudflare.com](https://cloudflare.com)
   - Add your domain
   - Update nameservers at your domain registrar

2. **Configure DNS**:
   ```
   Type: CNAME
   Name: api
   Value: your-app.up.railway.app
   Proxy status: Proxied (orange cloud)
   ```

3. **Enable SSL**:
   - SSL/TLS → Overview → Full (strict)
   - Edge Certificates → Always Use HTTPS: On
   - Minimum TLS Version: 1.2

4. **Add Firewall Rules** (Optional):
   - Security → WAF
   - Add rules to block suspicious traffic

---

## Security Checklist

### Pre-Deployment

- [ ] Generate new SECRET_KEY (32+ random characters)
- [ ] Change all default passwords
- [ ] Use PostgreSQL (not SQLite) in production
- [ ] Enable HTTPS/SSL
- [ ] Set CORS_ORIGINS to specific domains
- [ ] Set DEBUG=False
- [ ] Remove or protect /docs endpoint
- [ ] Enable rate limiting
- [ ] Set up Sentry for error tracking
- [ ] Configure firewall rules
- [ ] Use environment variables (never commit secrets)

### Stripe Security

- [ ] Use live mode keys (never commit them)
- [ ] Verify webhook signatures
- [ ] Set up webhook secret
- [ ] Test all webhook events
- [ ] Monitor Stripe dashboard for unusual activity
- [ ] Enable 2FA on Stripe account

### Database Security

- [ ] Use strong database password
- [ ] Enable SSL for database connections
- [ ] Restrict database access to application IP only
- [ ] Set up automated backups
- [ ] Test backup restoration
- [ ] Enable connection pooling

### API Security

- [ ] Implement rate limiting (already done)
- [ ] Add request ID tracking (already done)
- [ ] Log all authentication attempts
- [ ] Implement IP-based blocking for repeated failures
- [ ] Use HTTPS only (no HTTP)
- [ ] Add security headers (already configured)
- [ ] Sanitize all user inputs

---

## Update Flutter App Configuration

### Update API Base URL

**File:** `lib/services/api_service.dart`

```dart
class ApiService {
  // Change from localhost to production URL
  static const String baseUrl = 'https://api.yourapp.com';
  
  // Or use environment-based config
  static String get baseUrl {
    const environment = String.fromEnvironment('ENV', defaultValue: 'dev');
    switch (environment) {
      case 'production':
        return 'https://api.yourapp.com';
      case 'staging':
        return 'https://staging-api.yourapp.com';
      default:
        return 'http://localhost:8000';
    }
  }
}
```

### Build for Production

```bash
# Android
flutter build apk --release --dart-define=ENV=production

# iOS
flutter build ios --release --dart-define=ENV=production
```

---

## Testing Webhooks

### Local Testing with ngrok (Before Deployment)

1. **Install ngrok**:
```bash
# Download from https://ngrok.com/download
```

2. **Run your local server**:
```bash
cd ewallet_backend
python run_server.py
```

3. **Start ngrok**:
```bash
ngrok http 8000
```

4. **Configure Stripe webhook** with ngrok URL:
```
https://abc123.ngrok.io/api/webhooks/stripe
```

5. **Test webhook**:
   - Stripe Dashboard → Webhooks → Send test webhook
   - Check your terminal for logs

### Production Testing

1. **Test webhook endpoint**:
```bash
curl https://api.yourapp.com/api/webhooks/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2025-11-08T13:30:00",
  "webhooks_enabled": true,
  "stripe_configured": true
}
```

2. **Test Stripe webhook**:
   - Stripe Dashboard → Webhooks → Your endpoint
   - Click "Send test webhook"
   - Select event type: `payment_intent.succeeded`
   - Click "Send test webhook"

3. **Check logs**:
```bash
# Railway
railway logs

# Or in Railway dashboard
Project → Service → Logs
```

4. **Monitor webhook delivery**:
   - Stripe Dashboard → Webhooks → Your endpoint
   - Check "Recent deliveries" tab
   - Should show 2xx responses

---

## Monitoring & Maintenance

### Setup Error Tracking (Sentry)

1. **Sign up at [Sentry.io](https://sentry.io)**

2. **Create new project** → Python/FastAPI

3. **Add to Railway env variables**:
```bash
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id
```

4. **Test error tracking**:
```bash
curl https://api.yourapp.com/api/test-error
```

### Log Monitoring

**Railway**: Built-in logs viewer

**External options**:
- Papertrail (free tier)
- Logtail
- DataDog

### Uptime Monitoring

Free services:
- UptimeRobot (50 monitors free)
- StatusCake
- Pingdom (free trial)

Monitor these endpoints:
- `https://api.yourapp.com/` (health check)
- `https://api.yourapp.com/api/webhooks/health`

---

## Rollback Plan

If deployment fails:

1. **Railway**: Click "Rollback" on previous deployment

2. **Keep old server running** until new one is verified

3. **Database backup**:
```bash
# PostgreSQL backup
pg_dump DATABASE_URL > backup_$(date +%Y%m%d).sql

# Restore if needed
psql DATABASE_URL < backup_20251108.sql
```

4. **DNS switch**: Change CNAME back to old server

---

## Common Issues & Solutions

### Issue: Webhooks not receiving events

**Solution:**
- Check webhook URL is correct
- Verify SSL certificate is valid
- Check firewall isn't blocking Stripe IPs
- Review Stripe webhook logs for errors

### Issue: Database connection errors

**Solution:**
- Verify DATABASE_URL format: `postgresql://user:pass@host:port/db`
- Check database is running
- Verify IP whitelist includes your app IP
- Check connection pool settings

### Issue: CORS errors in Flutter app

**Solution:**
- Add your domain to CORS_ORIGINS
- Verify domain includes protocol (https://)
- Clear browser cache
- Check for typos in domain name

### Issue: High latency

**Solution:**
- Enable database connection pooling
- Add Redis for caching
- Use CDN for static assets
- Optimize database queries
- Scale to multiple workers

---

## Post-Deployment Checklist

- [ ] Verify main API endpoint responds
- [ ] Test user registration
- [ ] Test user login
- [ ] Test payment flow
- [ ] Send test Stripe webhook
- [ ] Verify webhook logs show receipt
- [ ] Test money invite system
- [ ] Check all Flutter app features work
- [ ] Monitor error rates in Sentry
- [ ] Verify backup system is running
- [ ] Test auto-refund scheduler
- [ ] Setup uptime monitoring
- [ ] Document production URLs
- [ ] Update README with prod info
- [ ] Notify team of deployment

---

## Support Resources

- **Railway Docs**: https://docs.railway.app
- **Stripe Webhooks**: https://stripe.com/docs/webhooks
- **FastAPI Deployment**: https://fastapi.tiangolo.com/deployment/
- **PostgreSQL on Railway**: https://docs.railway.app/databases/postgresql

---

## Next Steps After Deployment

1. **Monitor for 24-48 hours** - Watch logs, errors, webhook delivery
2. **Load testing** - Use Locust or Artillery to test under load
3. **Setup alerts** - Email/SMS notifications for errors
4. **Documentation** - Update API docs with production URL
5. **User testing** - Beta test with real users
6. **Scale planning** - Monitor resource usage, plan scaling
7. **Backup verification** - Test database restore procedure
8. **Security audit** - Run vulnerability scans
9. **Performance optimization** - Identify and fix bottlenecks
10. **Marketing prep** - Prepare for launch! 🚀

---

**Congratulations! Your BlackWallet API is now production-ready! 🎉**
