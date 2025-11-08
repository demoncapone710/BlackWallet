"""
Database migration script to add admin communication features.
Creates tables for: notifications, advertisements, promotions, customer messages, promotion usage.
"""

from sqlalchemy import create_engine, text
from config import settings
from models import (
    Base, User, Transaction, PaymentMethod,
    Notification, Advertisement, Promotion, 
    CustomerMessage, PromotionUsage
)
from logger import get_logger

logger = get_logger(__name__)

def migrate_admin_features():
    """Create tables for new admin features"""
    logger.info("=" * 60)
    logger.info("ADMIN FEATURES MIGRATION")
    logger.info("=" * 60)
    
    # Create engine
    engine = create_engine(settings.DATABASE_URL, echo=True)
    
    try:
        # Create all tables (will skip existing ones)
        logger.info("Creating new tables...")
        Base.metadata.create_all(engine)
        
        # Verify tables were created
        with engine.connect() as conn:
            # Check for new tables
            tables_to_check = [
                'notifications',
                'advertisements', 
                'promotions',
                'customer_messages',
                'promotion_usage'
            ]
            
            for table_name in tables_to_check:
                result = conn.execute(text(
                    f"SELECT name FROM sqlite_master WHERE type='table' AND name='{table_name}'"
                ))
                if result.fetchone():
                    logger.info(f"✓ Table '{table_name}' created successfully")
                else:
                    logger.error(f"✗ Table '{table_name}' was NOT created")
        
        logger.info("=" * 60)
        logger.info("MIGRATION COMPLETE!")
        logger.info("=" * 60)
        logger.info("New features available:")
        logger.info("  - Send push notifications to users")
        logger.info("  - Create and manage advertisements")
        logger.info("  - Create promotional codes")
        logger.info("  - Direct customer messaging")
        logger.info("=" * 60)
        
        return True
        
    except Exception as e:
        logger.error(f"Migration failed: {e}")
        return False

if __name__ == "__main__":
    success = migrate_admin_features()
    if success:
        print("\n✅ Admin features migration completed successfully!")
        print("You can now use all admin communication endpoints.")
    else:
        print("\n❌ Migration failed. Check the logs above.")
