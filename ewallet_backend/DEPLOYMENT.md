# Production Deployment Guide

## BlackWallet Backend - Production Setup

This guide covers deploying the BlackWallet backend to a production environment with all security and performance features enabled.

## Prerequisites

- **Operating System**: Ubuntu 22.04 LTS or similar Linux distribution
- **Python**: 3.10 or higher
- **Database**: PostgreSQL 14+ (recommended for production)
- **Redis**: 7.0+ (for caching and rate limiting)
- **SSL Certificate**: Let's Encrypt or commercial SSL certificate
- **Domain**: Configured DNS pointing to your server

## Step 1: Server Preparation

### Update system packages
```bash
sudo apt update
sudo apt upgrade -y
```

### Install required packages
```bash
sudo apt install -y python3-pip python3-venv python3-dev \
    postgresql postgresql-contrib \
    redis-server \
    nginx \
    certbot python3-certbot-nginx \
    git supervisor
```

## Step 2: Database Setup (PostgreSQL)

### Create database and user
```bash
sudo -u postgres psql

CREATE DATABASE blackwallet;
CREATE USER blackwallet_user WITH PASSWORD 'your_secure_password_here';
GRANT ALL PRIVILEGES ON DATABASE blackwallet TO blackwallet_user;
\q
```

### Configure PostgreSQL for production
Edit `/etc/postgresql/14/main/postgresql.conf`:
```
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 2621kB
min_wal_size = 1GB
max_wal_size = 4GB
```

Restart PostgreSQL:
```bash
sudo systemctl restart postgresql
```

## Step 3: Redis Setup

### Configure Redis
Edit `/etc/redis/redis.conf`:
```
bind 127.0.0.1
port 6379
maxmemory 256mb
maxmemory-policy allkeys-lru
```

Enable and start Redis:
```bash
sudo systemctl enable redis-server
sudo systemctl start redis-server
```

## Step 4: Application Setup

### Create application user
```bash
sudo useradd -m -s /bin/bash blackwallet
sudo usermod -aG sudo blackwallet
```

### Clone and setup application
```bash
sudo -u blackwallet mkdir -p /opt/blackwallet
cd /opt/blackwallet
sudo -u blackwallet git clone <your-repo-url> .

# Create virtual environment
sudo -u blackwallet python3 -m venv venv
sudo -u blackwallet venv/bin/pip install --upgrade pip
sudo -u blackwallet venv/bin/pip install -r ewallet_backend/requirements.txt
```

### Configure environment variables
```bash
sudo -u blackwallet nano /opt/blackwallet/ewallet_backend/.env
```

Add production configuration:
```env
# Application
APP_NAME=BlackWallet API
APP_VERSION=1.0.0
DEBUG=False
ENVIRONMENT=production

# Server
HOST=0.0.0.0
PORT=8000
WORKERS=4

# Database (PostgreSQL)
DATABASE_URL=postgresql://blackwallet_user:your_secure_password_here@localhost/blackwallet
DATABASE_POOL_SIZE=20
DATABASE_MAX_OVERFLOW=40
DATABASE_POOL_TIMEOUT=30
DATABASE_POOL_RECYCLE=3600

# Security
SECRET_KEY=your-super-secret-key-generate-a-strong-one-here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# Rate Limiting
RATE_LIMIT_ENABLED=True
RATE_LIMIT_PER_MINUTE=60
RATE_LIMIT_AUTH_PER_MINUTE=5

# CORS (restrict to your domain)
CORS_ORIGINS=["https://yourdomain.com"]
CORS_ALLOW_CREDENTIALS=True

# Redis
REDIS_URL=redis://localhost:6379/0
REDIS_ENABLED=True

# Logging
LOG_LEVEL=INFO
LOG_FORMAT=json
LOG_FILE=/opt/blackwallet/logs/blackwallet.log

# Monitoring
SENTRY_DSN=your-sentry-dsn-here  # Optional
PROMETHEUS_ENABLED=True

# Backup
BACKUP_ENABLED=True
BACKUP_INTERVAL_HOURS=6
BACKUP_RETENTION_DAYS=30
BACKUP_DIRECTORY=/opt/blackwallet/backups

# SSL/TLS
SSL_ENABLED=True

# Email (configure your SMTP)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM_EMAIL=noreply@blackwallet.com

# Stripe
STRIPE_SECRET_KEY=sk_live_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

### Create required directories
```bash
sudo -u blackwallet mkdir -p /opt/blackwallet/logs
sudo -u blackwallet mkdir -p /opt/blackwallet/backups
```

### Initialize database
```bash
cd /opt/blackwallet/ewallet_backend
sudo -u blackwallet ../venv/bin/python init_db.py
```

## Step 5: Systemd Service Setup

### Create systemd service file
```bash
sudo nano /etc/systemd/system/blackwallet.service
```

Add the following content:
```ini
[Unit]
Description=BlackWallet API Service
After=network.target postgresql.service redis-server.service
Requires=postgresql.service redis-server.service

[Service]
Type=notify
User=blackwallet
Group=blackwallet
WorkingDirectory=/opt/blackwallet/ewallet_backend
Environment="PATH=/opt/blackwallet/venv/bin"
ExecStart=/opt/blackwallet/venv/bin/gunicorn main:app \
    --workers 4 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:8000 \
    --timeout 120 \
    --access-logfile /opt/blackwallet/logs/access.log \
    --error-logfile /opt/blackwallet/logs/error.log \
    --log-level info

Restart=always
RestartSec=10
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

### Enable and start service
```bash
sudo systemctl daemon-reload
sudo systemctl enable blackwallet
sudo systemctl start blackwallet
sudo systemctl status blackwallet
```

## Step 6: Nginx Reverse Proxy Setup

### Create Nginx configuration
```bash
sudo nano /etc/nginx/sites-available/blackwallet
```

Add the following:
```nginx
# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=1r/s;

# Upstream backend
upstream blackwallet_backend {
    server 127.0.0.1:8000 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name api.blackwallet.com;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.blackwallet.com;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/api.blackwallet.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.blackwallet.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS Header
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Security Headers
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Logging
    access_log /var/log/nginx/blackwallet_access.log;
    error_log /var/log/nginx/blackwallet_error.log;
    
    # Client upload size
    client_max_body_size 10M;
    
    # Proxy settings
    location / {
        limit_req zone=api_limit burst=20 nodelay;
        
        proxy_pass http://blackwallet_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Stricter rate limiting for auth endpoints
    location ~ ^/(login|signup|token) {
        limit_req zone=auth_limit burst=5 nodelay;
        
        proxy_pass http://blackwallet_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://blackwallet_backend;
        access_log off;
    }
}
```

### Enable site and obtain SSL certificate
```bash
sudo ln -s /etc/nginx/sites-available/blackwallet /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Obtain SSL certificate
sudo certbot --nginx -d api.blackwallet.com
```

## Step 7: Firewall Configuration

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

## Step 8: Monitoring and Maintenance

### Setup log rotation
```bash
sudo nano /etc/logrotate.d/blackwallet
```

Add:
```
/opt/blackwallet/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    missingok
    create 0640 blackwallet blackwallet
    sharedscripts
    postrotate
        sudo systemctl reload blackwallet
    endscript
}
```

### Setup automated backups with cron
```bash
sudo -u blackwallet crontab -e
```

Add:
```
# Database backup every 6 hours
0 */6 * * * /opt/blackwallet/venv/bin/python /opt/blackwallet/ewallet_backend/backup.py

# Backup to remote storage daily at 2 AM
0 2 * * * rsync -avz /opt/blackwallet/backups/ backup-server:/backups/blackwallet/
```

## Step 9: Testing

### Test the API
```bash
curl https://api.blackwallet.com/health
curl https://api.blackwallet.com/
```

### Monitor logs
```bash
sudo journalctl -u blackwallet -f
tail -f /opt/blackwallet/logs/blackwallet.log
tail -f /var/log/nginx/blackwallet_access.log
```

## Step 10: Performance Tuning

### Optimize Linux kernel parameters
Edit `/etc/sysctl.conf`:
```
# Network performance
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1

# File descriptors
fs.file-max = 2097152
```

Apply changes:
```bash
sudo sysctl -p
```

## Security Checklist

- [ ] Strong passwords for database and application
- [ ] SSL/TLS certificates configured and auto-renewing
- [ ] Firewall enabled with minimal open ports
- [ ] Regular security updates scheduled
- [ ] Rate limiting configured
- [ ] CORS restricted to specific domains
- [ ] Error tracking configured (Sentry)
- [ ] Automated backups running
- [ ] Log rotation configured
- [ ] Monitoring alerts setup
- [ ] Secrets stored in environment variables (not in code)
- [ ] Regular penetration testing scheduled

## Troubleshooting

### View service logs
```bash
sudo journalctl -u blackwallet -n 100 --no-pager
```

### Restart services
```bash
sudo systemctl restart blackwallet
sudo systemctl restart nginx
sudo systemctl restart postgresql
sudo systemctl restart redis-server
```

### Check service status
```bash
sudo systemctl status blackwallet
sudo systemctl status nginx
sudo systemctl status postgresql
sudo systemctl status redis-server
```

### Database connection test
```bash
cd /opt/blackwallet/ewallet_backend
sudo -u blackwallet ../venv/bin/python -c "from database import engine; engine.connect(); print('Database connected successfully')"
```

## Maintenance

### Daily
- Monitor logs for errors
- Check disk space
- Review metrics

### Weekly
- Review backup status
- Check security alerts
- Update dependencies if needed

### Monthly
- Security audit
- Performance review
- Backup restoration test
- SSL certificate check

## Support

For issues or questions, contact: support@blackwallet.com

---

**Production Deployment Complete! 🚀**
