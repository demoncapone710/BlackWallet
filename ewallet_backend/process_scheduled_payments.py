"""
Background Job Processor for Scheduled Payments
Run this as a separate process: python process_scheduled_payments.py
"""
import time
import logging
from datetime import datetime
from database import SessionLocal
from services.quick_wins_services import ScheduledPaymentService

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def process_scheduled_payments():
    """Process all pending scheduled payments"""
    db = SessionLocal()
    
    try:
        pending = ScheduledPaymentService.get_pending_payments(db)
        
        if pending:
            logger.info(f"Found {len(pending)} pending payments to process")
            
            for payment in pending:
                logger.info(f"Processing payment {payment.id}: ${payment.amount} to {payment.recipient_identifier}")
                
                result = ScheduledPaymentService.execute_payment(payment, db)
                
                if result["success"]:
                    logger.info(f"✅ Payment {payment.id} executed successfully")
                else:
                    logger.error(f"❌ Payment {payment.id} failed: {result.get('error')}")
        else:
            logger.debug("No pending payments to process")
    
    except Exception as e:
        logger.error(f"Error processing scheduled payments: {e}", exc_info=True)
    
    finally:
        db.close()


def main():
    """Main loop - check every minute"""
    logger.info("🚀 Scheduled Payment Processor started")
    logger.info("Checking for pending payments every 60 seconds...")
    
    while True:
        try:
            process_scheduled_payments()
            time.sleep(60)  # Check every minute
        except KeyboardInterrupt:
            logger.info("Shutting down...")
            break
        except Exception as e:
            logger.error(f"Unexpected error: {e}", exc_info=True)
            time.sleep(60)


if __name__ == "__main__":
    main()
