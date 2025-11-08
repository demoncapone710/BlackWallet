"""
Webhook handlers for external services
Handles Stripe, payment processors, and other third-party webhooks
"""
from fastapi import APIRouter, Request, HTTPException, Header
from sqlalchemy.orm import Session
from fastapi import Depends
import stripe
import hmac
import hashlib
import json
from datetime import datetime
from typing import Optional

from database import get_db
from models import User, Transaction, PaymentMethod, Notification
from config import settings
from logger import get_logger

logger = get_logger(__name__)
router = APIRouter()


def get_webhook_secret():
    """Get the appropriate webhook secret based on Stripe mode"""
    if settings.STRIPE_MODE == "live":
        return settings.STRIPE_LIVE_WEBHOOK_SECRET
    else:
        return settings.STRIPE_WEBHOOK_SECRET


# ============= STRIPE WEBHOOKS =============

@router.post("/webhooks/stripe")
async def stripe_webhook(
    request: Request,
    stripe_signature: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """
    Handle Stripe webhooks for payment events
    Used for: payment confirmations, disputes, refunds, account updates
    """
    payload = await request.body()
    
    # Get the appropriate webhook secret based on mode
    webhook_secret = get_webhook_secret()
    
    if not webhook_secret:
        logger.warning("Stripe webhook secret not configured")
        # In development, you might want to process anyway
        if settings.ENVIRONMENT == "development":
            event = json.loads(payload)
        else:
            raise HTTPException(status_code=400, detail="Webhook secret not configured")
    else:
        # Verify webhook signature
        try:
            event = stripe.Webhook.construct_event(
                payload, stripe_signature, webhook_secret
            )
        except ValueError as e:
            logger.error(f"Invalid payload: {e}")
            raise HTTPException(status_code=400, detail="Invalid payload")
        except stripe.error.SignatureVerificationError as e:
            logger.error(f"Invalid signature: {e}")
            raise HTTPException(status_code=400, detail="Invalid signature")
    
    event_type = event['type']
    event_data = event['data']['object']
    
    logger.info(f"Received Stripe webhook: {event_type}", extra={
        "event_id": event['id'],
        "event_type": event_type
    })
    
    try:
        # Handle different event types
        if event_type == 'payment_intent.succeeded':
            await handle_payment_intent_succeeded(event_data, db)
        
        elif event_type == 'payment_intent.payment_failed':
            await handle_payment_intent_failed(event_data, db)
        
        elif event_type == 'charge.succeeded':
            await handle_charge_succeeded(event_data, db)
        
        elif event_type == 'charge.failed':
            await handle_charge_failed(event_data, db)
        
        elif event_type == 'charge.refunded':
            await handle_charge_refunded(event_data, db)
        
        elif event_type == 'charge.dispute.created':
            await handle_dispute_created(event_data, db)
        
        elif event_type == 'customer.created':
            await handle_customer_created(event_data, db)
        
        elif event_type == 'customer.updated':
            await handle_customer_updated(event_data, db)
        
        elif event_type == 'customer.deleted':
            await handle_customer_deleted(event_data, db)
        
        elif event_type == 'payment_method.attached':
            await handle_payment_method_attached(event_data, db)
        
        elif event_type == 'payment_method.detached':
            await handle_payment_method_detached(event_data, db)
        
        elif event_type == 'account.updated':
            await handle_account_updated(event_data, db)
        
        elif event_type == 'payout.paid':
            await handle_payout_paid(event_data, db)
        
        elif event_type == 'payout.failed':
            await handle_payout_failed(event_data, db)
        
        elif event_type == 'transfer.created':
            await handle_transfer_created(event_data, db)
        
        else:
            logger.info(f"Unhandled webhook event type: {event_type}")
    
    except Exception as e:
        logger.error(f"Error processing webhook {event_type}: {e}", exc_info=True)
        # Return 200 to acknowledge receipt, but log the error
        # Stripe will retry failed webhooks automatically
    
    return {"status": "success", "event_type": event_type}


# ============= STRIPE EVENT HANDLERS =============

async def handle_payment_intent_succeeded(event_data: dict, db: Session):
    """Handle successful payment intent"""
    payment_intent_id = event_data['id']
    amount = event_data['amount'] / 100  # Convert from cents
    currency = event_data['currency']
    metadata = event_data.get('metadata', {})
    
    logger.info(f"Payment intent succeeded: {payment_intent_id}, Amount: {amount} {currency}")
    
    # Get user from metadata
    user_id = metadata.get('user_id')
    transaction_id = metadata.get('transaction_id')
    
    if user_id and transaction_id:
        # Update transaction status
        transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
        if transaction:
            transaction.status = "completed"
            transaction.stripe_payment_intent_id = payment_intent_id
            db.commit()
            
            # Create notification
            notification = Notification(
                user_id=int(user_id),
                title="Payment Successful",
                message=f"Your payment of ${amount:.2f} was successful",
                type="payment_success"
            )
            db.add(notification)
            db.commit()
            
            logger.info(f"Updated transaction {transaction_id} to completed")
    
    return True


async def handle_payment_intent_failed(event_data: dict, db: Session):
    """Handle failed payment intent"""
    payment_intent_id = event_data['id']
    amount = event_data['amount'] / 100
    metadata = event_data.get('metadata', {})
    error = event_data.get('last_payment_error', {})
    
    logger.warning(f"Payment intent failed: {payment_intent_id}, Error: {error.get('message')}")
    
    user_id = metadata.get('user_id')
    transaction_id = metadata.get('transaction_id')
    
    if user_id and transaction_id:
        transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
        if transaction:
            transaction.status = "failed"
            transaction.stripe_payment_intent_id = payment_intent_id
            db.commit()
            
            # Create notification
            notification = Notification(
                user_id=int(user_id),
                title="Payment Failed",
                message=f"Your payment of ${amount:.2f} failed: {error.get('message', 'Unknown error')}",
                type="payment_failed"
            )
            db.add(notification)
            db.commit()
    
    return True


async def handle_charge_succeeded(event_data: dict, db: Session):
    """Handle successful charge"""
    charge_id = event_data['id']
    amount = event_data['amount'] / 100
    customer_id = event_data.get('customer')
    
    logger.info(f"Charge succeeded: {charge_id}, Amount: ${amount}")
    
    # Update user balance if this is a deposit
    metadata = event_data.get('metadata', {})
    user_id = metadata.get('user_id')
    
    if user_id:
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            user.balance += amount
            db.commit()
            logger.info(f"Added ${amount} to user {user_id} balance")
    
    return True


async def handle_charge_failed(event_data: dict, db: Session):
    """Handle failed charge"""
    charge_id = event_data['id']
    failure_message = event_data.get('failure_message', 'Unknown error')
    
    logger.warning(f"Charge failed: {charge_id}, Reason: {failure_message}")
    
    metadata = event_data.get('metadata', {})
    user_id = metadata.get('user_id')
    
    if user_id:
        notification = Notification(
            user_id=int(user_id),
            title="Charge Failed",
            message=f"Payment charge failed: {failure_message}",
            type="payment_failed"
        )
        db.add(notification)
        db.commit()
    
    return True


async def handle_charge_refunded(event_data: dict, db: Session):
    """Handle charge refund"""
    charge_id = event_data['id']
    amount_refunded = event_data['amount_refunded'] / 100
    
    logger.info(f"Charge refunded: {charge_id}, Amount: ${amount_refunded}")
    
    metadata = event_data.get('metadata', {})
    user_id = metadata.get('user_id')
    transaction_id = metadata.get('transaction_id')
    
    if user_id:
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            user.balance += amount_refunded
            db.commit()
        
        if transaction_id:
            transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
            if transaction:
                transaction.status = "refunded"
                db.commit()
        
        notification = Notification(
            user_id=int(user_id),
            title="Refund Processed",
            message=f"${amount_refunded:.2f} has been refunded to your account",
            type="refund"
        )
        db.add(notification)
        db.commit()
    
    return True


async def handle_dispute_created(event_data: dict, db: Session):
    """Handle payment dispute"""
    dispute_id = event_data['id']
    amount = event_data['amount'] / 100
    reason = event_data.get('reason', 'unknown')
    
    logger.warning(f"Dispute created: {dispute_id}, Amount: ${amount}, Reason: {reason}")
    
    # Notify admin
    admin_users = db.query(User).filter(User.is_admin == True).all()
    for admin in admin_users:
        notification = Notification(
            user_id=admin.id,
            title="Payment Dispute",
            message=f"Dispute created: ${amount:.2f} - Reason: {reason}",
            type="dispute"
        )
        db.add(notification)
    db.commit()
    
    return True


async def handle_customer_created(event_data: dict, db: Session):
    """Handle Stripe customer creation"""
    customer_id = event_data['id']
    email = event_data.get('email')
    
    logger.info(f"Stripe customer created: {customer_id}, Email: {email}")
    
    # Update user with customer_id
    if email:
        user = db.query(User).filter(User.email == email).first()
        if user:
            user.stripe_customer_id = customer_id
            db.commit()
    
    return True


async def handle_customer_updated(event_data: dict, db: Session):
    """Handle Stripe customer update"""
    customer_id = event_data['id']
    logger.info(f"Stripe customer updated: {customer_id}")
    return True


async def handle_customer_deleted(event_data: dict, db: Session):
    """Handle Stripe customer deletion"""
    customer_id = event_data['id']
    logger.info(f"Stripe customer deleted: {customer_id}")
    
    # Remove customer_id from user
    user = db.query(User).filter(User.stripe_customer_id == customer_id).first()
    if user:
        user.stripe_customer_id = None
        db.commit()
    
    return True


async def handle_payment_method_attached(event_data: dict, db: Session):
    """Handle payment method attached to customer"""
    payment_method_id = event_data['id']
    customer_id = event_data.get('customer')
    
    logger.info(f"Payment method attached: {payment_method_id} to customer {customer_id}")
    
    # Update payment method record if exists
    payment_method = db.query(PaymentMethod).filter(PaymentMethod.stripe_payment_method_id == payment_method_id).first()
    if payment_method:
        payment_method.is_active = True
        db.commit()
    
    return True


async def handle_payment_method_detached(event_data: dict, db: Session):
    """Handle payment method detached from customer"""
    payment_method_id = event_data['id']
    
    logger.info(f"Payment method detached: {payment_method_id}")
    
    # Update payment method record
    payment_method = db.query(PaymentMethod).filter(PaymentMethod.stripe_payment_method_id == payment_method_id).first()
    if payment_method:
        payment_method.is_active = False
        db.commit()
    
    return True


async def handle_account_updated(event_data: dict, db: Session):
    """Handle Stripe Connect account update"""
    account_id = event_data['id']
    charges_enabled = event_data.get('charges_enabled', False)
    payouts_enabled = event_data.get('payouts_enabled', False)
    
    logger.info(f"Stripe account updated: {account_id}, Charges: {charges_enabled}, Payouts: {payouts_enabled}")
    
    # Update user with account status
    user = db.query(User).filter(User.stripe_account_id == account_id).first()
    if user:
        user.stripe_charges_enabled = charges_enabled
        user.stripe_payouts_enabled = payouts_enabled
        db.commit()
    
    return True


async def handle_payout_paid(event_data: dict, db: Session):
    """Handle successful payout"""
    payout_id = event_data['id']
    amount = event_data['amount'] / 100
    
    logger.info(f"Payout paid: {payout_id}, Amount: ${amount}")
    
    # Create transaction record
    metadata = event_data.get('metadata', {})
    user_id = metadata.get('user_id')
    
    if user_id:
        notification = Notification(
            user_id=int(user_id),
            title="Payout Complete",
            message=f"${amount:.2f} has been transferred to your bank account",
            type="payout_success"
        )
        db.add(notification)
        db.commit()
    
    return True


async def handle_payout_failed(event_data: dict, db: Session):
    """Handle failed payout"""
    payout_id = event_data['id']
    amount = event_data['amount'] / 100
    failure_message = event_data.get('failure_message', 'Unknown error')
    
    logger.warning(f"Payout failed: {payout_id}, Amount: ${amount}, Reason: {failure_message}")
    
    metadata = event_data.get('metadata', {})
    user_id = metadata.get('user_id')
    
    if user_id:
        notification = Notification(
            user_id=int(user_id),
            title="Payout Failed",
            message=f"Payout of ${amount:.2f} failed: {failure_message}",
            type="payout_failed"
        )
        db.add(notification)
        db.commit()
    
    return True


async def handle_transfer_created(event_data: dict, db: Session):
    """Handle transfer creation"""
    transfer_id = event_data['id']
    amount = event_data['amount'] / 100
    
    logger.info(f"Transfer created: {transfer_id}, Amount: ${amount}")
    return True


# ============= GENERIC WEBHOOK VERIFICATION =============

@router.post("/webhooks/generic/{service}")
async def generic_webhook(
    service: str,
    request: Request,
    signature: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """
    Generic webhook handler for other services
    Can be extended for Plaid, Dwolla, or other payment processors
    """
    payload = await request.body()
    
    logger.info(f"Received webhook from {service}")
    
    # Verify signature based on service
    if service == "plaid":
        # Implement Plaid webhook verification
        pass
    elif service == "dwolla":
        # Implement Dwolla webhook verification
        pass
    else:
        logger.warning(f"Unknown webhook service: {service}")
        raise HTTPException(status_code=400, detail="Unknown service")
    
    return {"status": "success", "service": service}


# ============= WEBHOOK HEALTH CHECK =============

@router.get("/webhooks/health")
async def webhook_health():
    """Health check endpoint for webhook monitoring"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "webhooks_enabled": True,
        "stripe_configured": bool(settings.STRIPE_SECRET_KEY)
    }
