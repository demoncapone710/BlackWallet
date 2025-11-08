from sqlalchemy import create_engine, event, pool
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.engine import Engine
import logging
import os

from config import settings

logger = logging.getLogger(__name__)

# Get database URL (Railway/Render provide DATABASE_URL env var)
DATABASE_URL = os.getenv('DATABASE_URL') or settings.DATABASE_URL

# Fix postgres:// to postgresql:// for SQLAlchemy compatibility
if DATABASE_URL and DATABASE_URL.startswith('postgres://'):
    DATABASE_URL = DATABASE_URL.replace('postgres://', 'postgresql://', 1)

# Database engine with production-ready configuration
if DATABASE_URL.startswith("sqlite"):
    # SQLite configuration (development)
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
        echo=settings.DEBUG,
        pool_pre_ping=True,  # Verify connections before using
    )
    logger.info("Using SQLite database (development mode)")
    
else:
    # PostgreSQL configuration (production)
    engine = create_engine(
        DATABASE_URL,
        pool_size=settings.DATABASE_POOL_SIZE,
        max_overflow=settings.DATABASE_MAX_OVERFLOW,
        pool_timeout=settings.DATABASE_POOL_TIMEOUT,
        pool_recycle=settings.DATABASE_POOL_RECYCLE,
        pool_pre_ping=True,  # Verify connections before using
        echo=settings.DEBUG,
        poolclass=pool.QueuePool,
    )
    logger.info(
        f"Using PostgreSQL database with pool size {settings.DATABASE_POOL_SIZE}"
    )


# Enable foreign key constraints for SQLite
@event.listens_for(Engine, "connect")
def set_sqlite_pragma(dbapi_conn, connection_record):
    if DATABASE_URL.startswith("sqlite"):
        cursor = dbapi_conn.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.execute("PRAGMA journal_mode=WAL")  # Write-Ahead Logging
        cursor.close()


# Session factory
SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False
)

# Base class for models
Base = declarative_base()


def get_db():
    """
    Dependency for database sessions
    Ensures proper cleanup and connection pooling
    """
    db = SessionLocal()
    try:
        yield db
        db.commit()  # Commit if no exceptions
    except Exception as e:
        db.rollback()  # Rollback on error
        logger.error(f"Database transaction error: {e}", exc_info=True)
        raise
    finally:
        db.close()


def get_db_stats():
    """Get database connection pool statistics"""
    if hasattr(engine.pool, 'size'):
        return {
            "pool_size": engine.pool.size(),
            "checked_in": engine.pool.checkedin(),
            "checked_out": engine.pool.checkedout(),
            "overflow": engine.pool.overflow(),
            "total_connections": engine.pool.size() + engine.pool.overflow(),
        }
    return {"message": "Pool statistics not available for SQLite"}
