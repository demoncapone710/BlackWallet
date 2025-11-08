"""
Background scheduler for money invite auto-refunds
Checks for expired invites every 5 minutes and processes refunds
"""
import schedule
import time
from datetime import datetime
from sqlalchemy.orm import Session
from database import SessionLocal
from models import MoneyInvite, Transaction, User, Notification
from logger import get_logger

logger = get_logger(__name__)


def process_expired_invites():
    """
    Check for expired invites and refund the sender
    Runs every 5 minutes
    """
    db = SessionLocal()
    try:
        # Find all pending/delivered/opened invites that have expired
        now = datetime.utcnow()
        expired_invites = db.query(MoneyInvite).filter(
            MoneyInvite.status.in_(["pending", "delivered", "opened"]),
            MoneyInvite.expires_at <= now
        ).all()
        
        if not expired_invites:
            logger.debug("No expired invites to process")
            return
        
        logger.info(f"Processing {len(expired_invites)} expired invites")
        
        for invite in expired_invites:
            try:
                # Get sender
                sender = db.query(User).filter(User.id == invite.sender_id).first()
                if not sender:
                    logger.error(f"Sender not found for invite {invite.id}")
                    continue
                
                # Refund sender
                sender.balance += invite.amount
                
                # Create refund transaction
                refund_transaction = Transaction(
                    sender="system",
                    receiver=sender.username,
                    amount=invite.amount,
                    transaction_type="money_invite",
                    status="completed",
                    processed_at=datetime.utcnow(),
                    extra_data={
                        "reason": "invite_expired",
                        "original_invite_id": invite.id
                    }
                )
                db.add(refund_transaction)
                db.flush()
                
                # Update invite
                invite.status = "expired"
                invite.refunded_at = datetime.utcnow()
                invite.refund_transaction_id = refund_transaction.id
                
                # Update original transaction
                original_transaction = db.query(Transaction).filter(
                    Transaction.id == invite.transaction_id
                ).first()
                if original_transaction:
                    original_transaction.status = "refunded"
                
                # Notify sender
                notification = Notification(
                    user_id=sender.id,
                    title="⏰ Invite Expired",
                    message=f"Your ${invite.amount:.2f} invite to {invite.recipient_contact} expired. Funds refunded.",
                    notification_type="transaction",
                    extra_data={
                        "invite_id": invite.id,
                        "refund_transaction_id": refund_transaction.id
                    }
                )
                db.add(notification)
                
                db.commit()
                
                logger.info(
                    f"Expired invite {invite.id} refunded: "
                    f"${invite.amount} returned to {sender.username}"
                )
                
            except Exception as e:
                logger.error(f"Error processing expired invite {invite.id}: {e}")
                db.rollback()
                continue
        
        logger.info(f"Completed processing {len(expired_invites)} expired invites")
        
    except Exception as e:
        logger.error(f"Error in process_expired_invites: {e}")
    finally:
        db.close()


def start_scheduler():
    """Start the background scheduler"""
    logger.info("Starting invite expiry scheduler...")
    
    # Run immediately on startup
    process_expired_invites()
    
    # Schedule to run every 5 minutes
    schedule.every(5).minutes.do(process_expired_invites)
    
    logger.info("Invite expiry scheduler started (runs every 5 minutes)")
    
    while True:
        try:
            schedule.run_pending()
            time.sleep(60)  # Check every minute
        except KeyboardInterrupt:
            logger.info("Scheduler stopped by user")
            break
        except Exception as e:
            logger.error(f"Scheduler error: {e}")
            time.sleep(60)


if __name__ == "__main__":
    start_scheduler()
