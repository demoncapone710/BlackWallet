"""
Production Configuration for BlackWallet Backend
Handles environment-specific settings, security, and performance tuning
"""
import os
from typing import Optional
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings with environment variable support"""
    
    # Application
    APP_NAME: str = "BlackWallet API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    ENVIRONMENT: str = "production"  # development, staging, production
    
    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    WORKERS: int = 4
    
    # Database
    DATABASE_URL: str = "sqlite:///./ewallet.db"  # Default for development
    DATABASE_POOL_SIZE: int = 20
    DATABASE_MAX_OVERFLOW: int = 40
    DATABASE_POOL_TIMEOUT: int = 30
    DATABASE_POOL_RECYCLE: int = 3600
    
    # Security
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_PER_MINUTE: int = 60
    RATE_LIMIT_AUTH_PER_MINUTE: int = 5  # Stricter for auth endpoints
    
    # CORS
    CORS_ORIGINS: list = ["*"]  # Restrict in production
    CORS_ALLOW_CREDENTIALS: bool = True
    
    # Redis (for caching and rate limiting)
    REDIS_URL: str = "redis://localhost:6379/0"
    REDIS_ENABLED: bool = False  # Enable in production
    
    # Logging
    LOG_LEVEL: str = "INFO"  # DEBUG, INFO, WARNING, ERROR, CRITICAL
    LOG_FORMAT: str = "json"  # json or text
    LOG_FILE: str = "logs/blackwallet.log"
    
    # Monitoring
    SENTRY_DSN: Optional[str] = None
    PROMETHEUS_ENABLED: bool = True
    
    # Backup
    BACKUP_ENABLED: bool = True
    BACKUP_INTERVAL_HOURS: int = 6
    BACKUP_RETENTION_DAYS: int = 30
    BACKUP_DIRECTORY: str = "backups"
    
    # SSL/TLS
    SSL_ENABLED: bool = False
    SSL_CERT_PATH: Optional[str] = None
    SSL_KEY_PATH: Optional[str] = None
    
    # Email (for notifications)
    SMTP_HOST: Optional[str] = None
    SMTP_PORT: int = 587
    SMTP_USER: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    SMTP_FROM_EMAIL: str = "noreply@blackwallet.com"
    SMTP_SERVER: Optional[str] = None
    SMTP_USERNAME: Optional[str] = None
    
    # Twilio (for SMS notifications)
    TWILIO_ACCOUNT_SID: Optional[str] = None
    TWILIO_AUTH_TOKEN: Optional[str] = None
    TWILIO_PHONE_NUMBER: Optional[str] = None
    
    # Stripe - Test Mode Keys
    STRIPE_SECRET_KEY: Optional[str] = None
    STRIPE_PUBLISHABLE_KEY: Optional[str] = None
    STRIPE_WEBHOOK_SECRET: Optional[str] = None
    
    # Stripe - Live Mode Keys
    STRIPE_LIVE_SECRET_KEY: Optional[str] = None
    STRIPE_LIVE_PUBLISHABLE_KEY: Optional[str] = None
    STRIPE_LIVE_WEBHOOK_SECRET: Optional[str] = None
    
    # Stripe - Mode Selector (test or live)
    STRIPE_MODE: str = "test"
    
    # Security Headers
    HSTS_MAX_AGE: int = 31536000  # 1 year
    HSTS_INCLUDE_SUBDOMAINS: bool = True
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance"""
    return Settings()


# Convenience exports
settings = get_settings()
