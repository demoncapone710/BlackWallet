"""
Database configuration helper
Automatically switches between SQLite (development) and PostgreSQL (production)
"""
from config import settings
import os


def get_database_url() -> str:
    """
    Get the appropriate database URL based on environment
    Priority:
    1. DATABASE_URL environment variable (Railway/Render provides this)
    2. Settings DATABASE_URL
    3. Default SQLite for development
    """
    # Check for Railway/Render DATABASE_URL
    database_url = os.getenv('DATABASE_URL')
    
    if database_url:
        # Railway/Render provide postgres:// but SQLAlchemy needs postgresql://
        if database_url.startswith('postgres://'):
            database_url = database_url.replace('postgres://', 'postgresql://', 1)
        return database_url
    
    # Use settings DATABASE_URL
    if settings.DATABASE_URL:
        return settings.DATABASE_URL
    
    # Default to SQLite for development
    return "sqlite:///./ewallet.db"


def get_engine_config() -> dict:
    """
    Get SQLAlchemy engine configuration based on database type
    """
    database_url = get_database_url()
    
    if database_url.startswith('postgresql://'):
        # PostgreSQL configuration (production)
        return {
            'pool_size': settings.DATABASE_POOL_SIZE,
            'max_overflow': settings.DATABASE_MAX_OVERFLOW,
            'pool_timeout': settings.DATABASE_POOL_TIMEOUT,
            'pool_recycle': settings.DATABASE_POOL_RECYCLE,
            'pool_pre_ping': True,  # Verify connections before using
            'echo': settings.DEBUG,
        }
    else:
        # SQLite configuration (development)
        return {
            'connect_args': {"check_same_thread": False},
            'echo': settings.DEBUG,
        }


def is_postgresql() -> bool:
    """Check if using PostgreSQL"""
    return get_database_url().startswith('postgresql://')


def is_sqlite() -> bool:
    """Check if using SQLite"""
    return get_database_url().startswith('sqlite:///')
