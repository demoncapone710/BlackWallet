"""
Migration: Add enhanced user profile fields and offline support
Adds address, DOB, SSN, business info, and offline transaction fields
"""
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine, text
from config import settings
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def migrate():
    """Add new columns to users and transactions tables"""
    engine = create_engine(settings.DATABASE_URL, connect_args={"check_same_thread": False})
    
    with engine.connect() as conn:
        try:
            # Add new User fields
            user_columns = [
                "ALTER TABLE users ADD COLUMN address_line1 VARCHAR",
                "ALTER TABLE users ADD COLUMN address_line2 VARCHAR",
                "ALTER TABLE users ADD COLUMN city VARCHAR",
                "ALTER TABLE users ADD COLUMN state VARCHAR",
                "ALTER TABLE users ADD COLUMN postal_code VARCHAR",
                "ALTER TABLE users ADD COLUMN country VARCHAR DEFAULT 'US'",
                "ALTER TABLE users ADD COLUMN date_of_birth VARCHAR",
                "ALTER TABLE users ADD COLUMN ssn_last_4 VARCHAR",
                "ALTER TABLE users ADD COLUMN business_name VARCHAR",
                "ALTER TABLE users ADD COLUMN business_type VARCHAR DEFAULT 'individual'",
                "ALTER TABLE users ADD COLUMN business_tax_id VARCHAR",
                "ALTER TABLE users ADD COLUMN profile_complete BOOLEAN DEFAULT 0",
                "ALTER TABLE users ADD COLUMN kyc_verified BOOLEAN DEFAULT 0",
                "ALTER TABLE users ADD COLUMN account_created_at DATETIME",
                "ALTER TABLE users ADD COLUMN last_login_at DATETIME",
                "ALTER TABLE users ADD COLUMN offline_mode_enabled BOOLEAN DEFAULT 1",
                "ALTER TABLE users ADD COLUMN last_sync_at DATETIME",
            ]
            
            # Add new Transaction fields
            transaction_columns = [
                "ALTER TABLE transactions ADD COLUMN processed_at DATETIME",
                "ALTER TABLE transactions ADD COLUMN is_offline BOOLEAN DEFAULT 0",
                "ALTER TABLE transactions ADD COLUMN device_id VARCHAR",
            ]
            
            # Execute user migrations
            for sql in user_columns:
                try:
                    conn.execute(text(sql))
                    logger.info(f"✓ {sql}")
                except Exception as e:
                    if "duplicate column name" in str(e).lower():
                        logger.info(f"⊘ Column already exists: {sql}")
                    else:
                        logger.error(f"✗ Error: {e}")
            
            # Execute transaction migrations
            for sql in transaction_columns:
                try:
                    conn.execute(text(sql))
                    logger.info(f"✓ {sql}")
                except Exception as e:
                    if "duplicate column name" in str(e).lower():
                        logger.info(f"⊘ Column already exists: {sql}")
                    else:
                        logger.error(f"✗ Error: {e}")
            
            conn.commit()
            logger.info("✅ Migration completed successfully!")
            
        except Exception as e:
            logger.error(f"❌ Migration failed: {e}")
            conn.rollback()
            raise

if __name__ == "__main__":
    migrate()
