# Docker Deployment Guide

## BlackWallet Backend - Docker Container Deployment

This guide covers deploying the BlackWallet backend using Docker and Docker Compose.

## Prerequisites

- Docker 20.10+ installed
- Docker Compose 2.0+ installed
- Git (for cloning repository)

## Quick Start

### 1. Clone the repository
```bash
git clone <your-repo-url>
cd BlackWallet/ewallet_backend
```

### 2. Configure environment
```bash
cp .env.example .env
nano .env  # Edit with your configuration
```

### 3. Start services
```bash
# Production deployment
docker-compose up -d

# Or for development with hot reload
docker-compose -f docker-compose.dev.yml up
```

### 4. Initialize database
```bash
docker-compose exec api python init_db.py
```

### 5. Check health
```bash
curl http://localhost/health
```

## Architecture

The Docker setup includes:

- **API Service**: FastAPI application with Gunicorn workers
- **PostgreSQL**: Production database
- **Redis**: Caching and rate limiting
- **Nginx**: Reverse proxy with rate limiting
- **Prometheus** (optional): Metrics collection
- **Grafana** (optional): Metrics visualization

## Docker Compose Commands

### Start all services
```bash
docker-compose up -d
```

### Start with monitoring stack
```bash
docker-compose --profile monitoring up -d
```

### View logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api
docker-compose logs -f postgres
docker-compose logs -f nginx
```

### Stop services
```bash
docker-compose down
```

### Stop and remove volumes (WARNING: deletes data)
```bash
docker-compose down -v
```

### Restart a service
```bash
docker-compose restart api
```

### Execute commands in container
```bash
# Access API container shell
docker-compose exec api bash

# Run Python script
docker-compose exec api python init_db.py

# Check API logs
docker-compose exec api tail -f /app/logs/blackwallet.log
```

## Development Mode

Use `docker-compose.dev.yml` for local development:

```bash
# Start dev environment
docker-compose -f docker-compose.dev.yml up

# Features:
# - Hot reload enabled
# - Debug mode on
# - Source code mounted as volume
# - Simpler configuration
# - Rate limiting disabled
```

## Production Deployment

### 1. Update environment variables

Edit `.env` with production values:
```env
DEBUG=False
ENVIRONMENT=production
SECRET_KEY=<generate-strong-secret>
DATABASE_URL=postgresql://user:pass@postgres:5432/blackwallet
STRIPE_SECRET_KEY=sk_live_...
```

### 2. Configure SSL certificates

Place SSL certificates in `ssl/` directory:
```bash
mkdir ssl
cp /path/to/fullchain.pem ssl/
cp /path/to/privkey.pem ssl/
```

Update `nginx.conf` to enable HTTPS server block.

### 3. Deploy
```bash
docker-compose up -d
```

## Building Custom Image

### Build image manually
```bash
docker build -t blackwallet-api:latest .
```

### Push to registry
```bash
docker tag blackwallet-api:latest your-registry/blackwallet-api:latest
docker push your-registry/blackwallet-api:latest
```

### Use custom image in docker-compose
Update `docker-compose.yml`:
```yaml
services:
  api:
    image: your-registry/blackwallet-api:latest
    # Remove 'build' section
```

## Monitoring

### Enable Prometheus and Grafana
```bash
docker-compose --profile monitoring up -d
```

Access:
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)

### Configure Grafana Dashboard

1. Add Prometheus data source: `http://prometheus:9090`
2. Import dashboard or create custom panels
3. Monitor:
   - Request rate
   - Response time
   - Error rate
   - Database connections
   - System resources

## Database Management

### Backup database
```bash
# Using Docker
docker-compose exec postgres pg_dump -U blackwallet_user blackwallet > backup.sql

# Using API endpoint
curl -X POST http://localhost:8000/backup/create
```

### Restore database
```bash
# Stop API service
docker-compose stop api

# Restore from backup
docker-compose exec -T postgres psql -U blackwallet_user blackwallet < backup.sql

# Start API service
docker-compose start api
```

### Access database
```bash
docker-compose exec postgres psql -U blackwallet_user -d blackwallet
```

## Scaling

### Scale API workers
```bash
docker-compose up -d --scale api=3
```

Update `nginx.conf` upstream block:
```nginx
upstream blackwallet_backend {
    least_conn;
    server api:8000 max_fails=3 fail_timeout=30s;
    # Add more backend servers if needed
}
```

## Troubleshooting

### Container won't start
```bash
# Check logs
docker-compose logs api

# Check health
docker-compose ps
```

### Database connection issues
```bash
# Test database connectivity
docker-compose exec api python -c "from database import engine; engine.connect(); print('Connected')"

# Check PostgreSQL logs
docker-compose logs postgres
```

### High memory usage
```bash
# Check container stats
docker stats

# Reduce workers in docker-compose.yml
command: ["gunicorn", "main:app", "--workers", "2", ...]
```

### Nginx rate limiting
```bash
# Check Nginx logs
docker-compose logs nginx

# Adjust rate limits in nginx.conf
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=20r/s;
```

## Security Best Practices

1. **Change default passwords** in `.env` and docker-compose.yml
2. **Use secrets management** for production (Docker Swarm secrets, Kubernetes secrets)
3. **Enable SSL/TLS** with valid certificates
4. **Restrict CORS origins** in `.env`
5. **Run as non-root user** (already configured in Dockerfile)
6. **Keep images updated** regularly
7. **Use private registry** for production images
8. **Enable firewall rules** on host machine
9. **Monitor container logs** for security events
10. **Regular security scans** with tools like Trivy

## Performance Tuning

### Optimize PostgreSQL
```yaml
postgres:
  command:
    - postgres
    - -c
    - max_connections=100
    - -c
    - shared_buffers=256MB
    - -c
    - effective_cache_size=1GB
```

### Optimize Redis
```yaml
redis:
  command: redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru
```

### Adjust worker processes
```yaml
api:
  command: [
    "gunicorn", "main:app",
    "--workers", "8",  # Adjust based on CPU cores
    "--worker-class", "uvicorn.workers.UvicornWorker"
  ]
```

## Maintenance

### Update containers
```bash
docker-compose pull
docker-compose up -d
```

### Clean up
```bash
# Remove unused containers
docker container prune

# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune
```

## CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Build and push image
        run: |
          docker build -t registry/blackwallet:latest .
          docker push registry/blackwallet:latest
      
      - name: Deploy to server
        run: |
          ssh user@server "cd /opt/blackwallet && docker-compose pull && docker-compose up -d"
```

## Support

For issues or questions, contact: support@blackwallet.com

---

**Docker deployment ready! 🐳**
