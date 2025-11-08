"""
Migration to add Stripe Connect support for real payments
"""
from database import SessionLocal, engine
from models import Base
from sqlalchemy import text
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def migrate_add_stripe_fields():
    """Add Stripe Connect fields to existing database"""
    db = SessionLocal()
    
    try:
        # Check and add stripe_account_id to users table
        logger.info("Adding stripe_account_id column to users table...")
        try:
            db.execute(text("ALTER TABLE users ADD COLUMN stripe_account_id TEXT"))
            logger.info("✅ Added stripe_account_id to users")
        except Exception as e:
            if "duplicate column name" in str(e).lower():
                logger.info("ℹ️  stripe_account_id already exists in users table")
            else:
                raise
        
        # Check and add Stripe tracking fields to transactions table
        logger.info("Adding Stripe tracking columns to transactions table...")
        
        try:
            db.execute(text("ALTER TABLE transactions ADD COLUMN stripe_payment_id TEXT"))
            logger.info("✅ Added stripe_payment_id to transactions")
        except Exception as e:
            if "duplicate column name" in str(e).lower():
                logger.info("ℹ️  stripe_payment_id already exists")
            else:
                raise
                
        try:
            db.execute(text("ALTER TABLE transactions ADD COLUMN stripe_transfer_id TEXT"))
            logger.info("✅ Added stripe_transfer_id to transactions")
        except Exception as e:
            if "duplicate column name" in str(e).lower():
                logger.info("ℹ️  stripe_transfer_id already exists")
            else:
                raise
                
        try:
            db.execute(text("ALTER TABLE transactions ADD COLUMN stripe_payout_id TEXT"))
            logger.info("✅ Added stripe_payout_id to transactions")
        except Exception as e:
            if "duplicate column name" in str(e).lower():
                logger.info("ℹ️  stripe_payout_id already exists")
            else:
                raise
        
        db.commit()
        logger.info("✅ Migration complete! Stripe Connect fields added")
        
    except Exception as e:
        db.rollback()
        logger.error(f"❌ Migration failed: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    logger.info("Starting Stripe Connect migration...")
    migrate_add_stripe_fields()
    logger.info("Migration complete!")
