"""
Migration script for Quick Win features
"""
from database import engine, Base
from models_quick_wins import (
    Favorite, ScheduledPayment, PaymentLink,
    TransactionTag, SubWallet, QRPaymentLimit
)
from models import User  # Import to ensure relationships work
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def migrate_quick_wins():
    """Create all quick win feature tables"""
    try:
        logger.info("Starting Quick Wins migration...")
        
        # Create all tables defined in models_quick_wins.py
        Base.metadata.create_all(bind=engine, checkfirst=True)
        
        logger.info("✅ Migration complete! Created tables:")
        logger.info("  - favorites")
        logger.info("  - scheduled_payments")
        logger.info("  - payment_links")
        logger.info("  - transaction_tags")
        logger.info("  - sub_wallets")
        logger.info("  - qr_payment_limits")
        
        logger.info("\nQuick Win features are now ready to use!")
        logger.info("\nNew Features:")
        logger.info("  ✅ Transaction Search & Filters")
        logger.info("  ✅ Favorites System")
        logger.info("  ✅ Scheduled/Recurring Payments")
        logger.info("  ✅ Payment Links (shareable)")
        logger.info("  ✅ Transaction Tags")
        logger.info("  ✅ Multiple Wallets (Personal/Business/Savings)")
        logger.info("  ✅ QR Payment Limits & Security")
        
    except Exception as e:
        logger.error(f"❌ Migration failed: {e}", exc_info=True)
        raise

if __name__ == "__main__":
    migrate_quick_wins()
