"""
Migration script to add card-related tables
"""
from database import engine, Base
from models_cards import (
    VirtualCard, 
    CardTransaction, 
    ATMTransaction, 
    POSTerminal, 
    GiftCardVoucher,
    InteracWalletConnection,
    WalletInteroperability
)
from models import User  # Import to ensure relationships work
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def migrate_card_tables():
    """Create all card-related tables"""
    try:
        logger.info("Starting card tables migration...")
        
        # Create all tables defined in models_cards.py
        Base.metadata.create_all(bind=engine, checkfirst=True)
        
        logger.info("✅ Migration complete! Created tables:")
        logger.info("  - virtual_cards")
        logger.info("  - card_transactions")
        logger.info("  - atm_transactions")
        logger.info("  - pos_terminals")
        logger.info("  - gift_card_vouchers")
        logger.info("  - interac_wallet_connections")
        logger.info("  - wallet_interoperability")
        
        logger.info("\nCard system is now ready to use!")
        
    except Exception as e:
        logger.error(f"❌ Migration failed: {e}", exc_info=True)
        raise

if __name__ == "__main__":
    migrate_card_tables()
