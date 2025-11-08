"""
Real Payment API Routes
Handles actual money transfers via Stripe Connect
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from typing import Optional
import logging

from database import get_db
from models import User, Transaction
from auth import get_current_user
from services.stripe_service import StripePaymentService
from datetime import datetime

router = APIRouter()
logger = logging.getLogger(__name__)


# Request/Response Models
class ConnectAccountRequest(BaseModel):
    country: str = Field(default="US", description="User's country code")


class BankAccountRequest(BaseModel):
    bank_token: str = Field(..., description="Stripe bank account token from frontend")


class TopUpRequest(BaseModel):
    amount: float = Field(..., gt=0, description="Amount to add to wallet")
    payment_method_id: str = Field(..., description="Stripe payment method ID")


class SendMoneyRequest(BaseModel):
    recipient_username: str
    amount: float = Field(..., gt=0)
    note: Optional[str] = None


class WithdrawRequest(BaseModel):
    amount: float = Field(..., gt=0, description="Amount to withdraw to bank")


# Routes
@router.post("/connect/create")
async def create_stripe_account(
    request: ConnectAccountRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Step 1: Create Stripe Connect account for user
    User needs this to receive real money
    """
    if current_user.stripe_account_id:
        raise HTTPException(400, "Stripe account already exists")
    
    try:
        result = await StripePaymentService.create_connected_account(
            user_id=current_user.id,
            email=current_user.email,
            country=request.country
        )
        
        # Save Stripe account ID to user
        current_user.stripe_account_id = result["stripe_account_id"]
        db.commit()
        
        return {
            "message": "Stripe account created",
            "stripe_account_id": result["stripe_account_id"],
            "next_step": "Complete onboarding via /connect/onboarding"
        }
    except Exception as e:
        logger.error(f"Stripe account creation error: {e}")
        raise HTTPException(500, str(e))


@router.get("/connect/onboarding")
async def get_onboarding_link(
    current_user: User = Depends(get_current_user)
):
    """
    Step 2: Get onboarding link for user to complete Stripe setup
    User will provide ID, bank account, tax info, etc.
    """
    if not current_user.stripe_account_id:
        raise HTTPException(400, "No Stripe account found. Create one first.")
    
    try:
        # These URLs should be your actual app URLs
        refresh_url = "https://yourapp.com/connect/refresh"
        return_url = "https://yourapp.com/connect/complete"
        
        onboarding_url = await StripePaymentService.create_account_link(
            stripe_account_id=current_user.stripe_account_id,
            refresh_url=refresh_url,
            return_url=return_url
        )
        
        return {
            "onboarding_url": onboarding_url,
            "message": "Complete setup in browser"
        }
    except Exception as e:
        logger.error(f"Onboarding link error: {e}")
        raise HTTPException(500, str(e))


@router.post("/connect/bank")
async def add_bank_account(
    request: BankAccountRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Step 3: Add bank account for withdrawals
    bank_token comes from Stripe.js on frontend
    """
    if not current_user.stripe_account_id:
        raise HTTPException(400, "Complete Stripe setup first")
    
    try:
        result = await StripePaymentService.add_bank_account(
            user_id=current_user.id,
            stripe_account_id=current_user.stripe_account_id,
            bank_token=request.bank_token
        )
        
        return {
            "message": "Bank account added",
            "bank_last4": result["last4"],
            "bank_name": result["bank_name"],
            "status": result["status"]
        }
    except Exception as e:
        logger.error(f"Bank account error: {e}")
        raise HTTPException(500, str(e))


@router.get("/connect/status")
async def check_account_status(
    current_user: User = Depends(get_current_user)
):
    """
    Check if user can send/receive real money
    """
    if not current_user.stripe_account_id:
        return {
            "setup_complete": False,
            "can_receive_payments": False,
            "can_withdraw": False,
            "message": "Stripe account not created"
        }
    
    try:
        status = await StripePaymentService.verify_account_status(
            current_user.stripe_account_id
        )
        
        return {
            "setup_complete": status["details_submitted"],
            "can_receive_payments": status["charges_enabled"],
            "can_withdraw": status["payouts_enabled"],
            "pending_requirements": status["requirements"]
        }
    except Exception as e:
        logger.error(f"Status check error: {e}")
        raise HTTPException(500, str(e))


@router.post("/topup")
async def add_money_to_wallet(
    request: TopUpRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Add real money to wallet by charging user's card/bank
    This takes money from user and adds to your platform
    """
    try:
        # Create payment intent with Stripe
        result = await StripePaymentService.create_payment_intent(
            user_id=current_user.id,
            amount=request.amount,
            payment_method=request.payment_method_id
        )
        
        if result["status"] == "succeeded":
            # Add to user's wallet balance
            current_user.balance += request.amount
            
            # Record transaction
            transaction = Transaction(
                sender_id=None,  # Platform top-up
                recipient_id=current_user.id,
                amount=request.amount,
                transaction_type="topup",
                status="completed",
                stripe_payment_id=result["intent_id"],
                note="Wallet top-up"
            )
            db.add(transaction)
            db.commit()
            
            return {
                "message": "Money added to wallet",
                "new_balance": current_user.balance,
                "amount": request.amount,
                "transaction_id": transaction.id
            }
        else:
            raise HTTPException(400, f"Payment {result['status']}")
            
    except Exception as e:
        logger.error(f"Top-up error: {e}")
        raise HTTPException(500, str(e))


@router.post("/send")
async def send_real_money(
    request: SendMoneyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Send REAL money to another user
    Money flows: sender's Stripe balance -> recipient's Stripe balance
    """
    # Find recipient
    recipient = db.query(User).filter_by(username=request.recipient_username).first()
    if not recipient:
        raise HTTPException(404, "Recipient not found")
    
    if not recipient.stripe_account_id:
        raise HTTPException(400, "Recipient hasn't set up payment account")
    
    # Check sender has enough balance
    if current_user.balance < request.amount:
        raise HTTPException(400, "Insufficient balance")
    
    try:
        # Create Stripe transfer to recipient
        transfer_result = await StripePaymentService.create_transfer(
            sender_id=current_user.id,
            recipient_stripe_account=recipient.stripe_account_id,
            amount=request.amount,
            description=f"Payment from {current_user.username}"
        )
        
        # Update balances
        current_user.balance -= request.amount
        recipient.balance += request.amount
        
        # Record transaction
        transaction = Transaction(
            sender_id=current_user.id,
            recipient_id=recipient.id,
            amount=request.amount,
            transaction_type="transfer",
            status="completed",
            stripe_transfer_id=transfer_result["transfer_id"],
            note=request.note
        )
        db.add(transaction)
        db.commit()
        
        return {
            "message": "Money sent successfully",
            "recipient": recipient.username,
            "amount": request.amount,
            "new_balance": current_user.balance,
            "transaction_id": transaction.id,
            "stripe_transfer_id": transfer_result["transfer_id"]
        }
        
    except Exception as e:
        db.rollback()
        logger.error(f"Real transfer error: {e}")
        raise HTTPException(500, str(e))


@router.post("/withdraw")
async def withdraw_to_bank(
    request: WithdrawRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Withdraw money from wallet to user's bank account
    Money goes: platform -> user's bank via Stripe payout
    """
    if not current_user.stripe_account_id:
        raise HTTPException(400, "Complete Stripe setup first")
    
    if current_user.balance < request.amount:
        raise HTTPException(400, "Insufficient balance")
    
    try:
        # Create payout to user's bank
        payout_result = await StripePaymentService.create_payout(
            stripe_account_id=current_user.stripe_account_id,
            amount=request.amount
        )
        
        # Deduct from wallet
        current_user.balance -= request.amount
        
        # Record transaction
        transaction = Transaction(
            sender_id=current_user.id,
            recipient_id=None,  # Bank withdrawal
            amount=request.amount,
            transaction_type="withdrawal",
            status="pending",
            stripe_payout_id=payout_result["payout_id"],
            note="Withdrawal to bank"
        )
        db.add(transaction)
        db.commit()
        
        return {
            "message": "Withdrawal initiated",
            "amount": request.amount,
            "new_balance": current_user.balance,
            "arrival_date": payout_result["arrival_date"],
            "status": payout_result["status"]
        }
        
    except Exception as e:
        db.rollback()
        logger.error(f"Withdrawal error: {e}")
        raise HTTPException(500, str(e))


@router.get("/balance/stripe")
async def get_stripe_balance(
    current_user: User = Depends(get_current_user)
):
    """
    Get user's balance in Stripe (separate from app balance)
    """
    if not current_user.stripe_account_id:
        raise HTTPException(400, "No Stripe account")
    
    try:
        balance = await StripePaymentService.get_balance(
            current_user.stripe_account_id
        )
        
        return {
            "app_balance": current_user.balance,
            "stripe_available": balance["available"],
            "stripe_pending": balance["pending"],
            "currency": balance["currency"]
        }
    except Exception as e:
        logger.error(f"Balance check error: {e}")
        raise HTTPException(500, str(e))
