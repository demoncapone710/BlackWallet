from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from database import get_db
from models import User, Transaction, PaymentMethod
from utils.security import decode_token
from utils.stripe_service import StripeService
from pydantic import BaseModel
from datetime import datetime

router = APIRouter()

class AddCardRequest(BaseModel):
    payment_method_id: str  # From Stripe.js on frontend

class DepositRequest(BaseModel):
    payment_method_id: str
    amount: float

class AddBankAccountRequest(BaseModel):
    account_number: str
    routing_number: str

class WithdrawRequest(BaseModel):
    bank_account_id: str
    amount: float
    instant_transfer: bool = False  # Optional instant transfer (with fee)

def get_current_user(authorization: str = Header(...), db: Session = Depends(get_db)):
    """Get current user from JWT token"""
    try:
        token = authorization.replace("Bearer ", "")
        payload = decode_token(token)
        username = payload.get("username")  # Changed from "sub" to "username"
        user = db.query(User).filter(User.username == username).first()
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        return user
    except:
        raise HTTPException(status_code=401, detail="Invalid token")

@router.post("/payment-methods/card")
async def add_card(
    request: AddCardRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Add a credit/debit card to user's account"""
    try:
        # Create Stripe customer if doesn't exist
        if not current_user.stripe_customer_id:
            customer_id = await StripeService.create_customer(current_user.username)
            if not customer_id:
                raise HTTPException(status_code=400, detail="Failed to create customer")
            current_user.stripe_customer_id = customer_id
            db.commit()
        
        # Attach payment method to customer
        payment_method = await StripeService.attach_payment_method(
            current_user.stripe_customer_id,
            request.payment_method_id
        )
        
        if not payment_method:
            raise HTTPException(status_code=400, detail="Failed to attach payment method")
        
        # Save to database
        db_payment_method = PaymentMethod(
            user_id=current_user.id,
            stripe_payment_method_id=payment_method.id,
            method_type="card",
            last4=payment_method.card.last4,
            brand=payment_method.card.brand,
            is_default=False
        )
        db.add(db_payment_method)
        db.commit()
        
        return {
            "message": "Card added successfully",
            "payment_method": {
                "id": db_payment_method.id,
                "last4": db_payment_method.last4,
                "brand": db_payment_method.brand
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/deposit")
async def deposit_from_card(
    request: DepositRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Deposit money from card to BlackWallet balance"""
    try:
        if request.amount <= 0:
            raise HTTPException(status_code=400, detail="Amount must be positive")
        
        if not current_user.stripe_customer_id:
            raise HTTPException(status_code=400, detail="No payment methods found")
        
        # Convert to cents for Stripe
        amount_cents = int(request.amount * 100)
        
        # Create payment intent
        payment_intent = await StripeService.create_payment_intent(
            amount_cents,
            current_user.stripe_customer_id,
            request.payment_method_id
        )
        
        if not payment_intent or payment_intent.status != "succeeded":
            raise HTTPException(status_code=400, detail="Payment failed")
        
        # Add to user balance
        current_user.balance += request.amount
        
        # Record transaction
        transaction = Transaction(
            sender="stripe_card",
            receiver=current_user.username,
            amount=request.amount,
            transaction_type="deposit",
            external_provider="stripe",
            external_transaction_id=payment_intent.id,
            status="completed",
            created_at=datetime.utcnow()
        )
        db.add(transaction)
        db.commit()
        
        return {
            "message": "Deposit successful",
            "new_balance": current_user.balance,
            "transaction_id": transaction.id
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/payment-methods/bank")
async def add_bank_account(
    request: AddBankAccountRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Add a bank account for ACH transfers"""
    try:
        # For testing: Bypass Stripe and create payment method directly
        # In production, you'd use Stripe for tokenization and verification
        
        # Create a mock token for testing
        mock_token = f"btok_test_{request.account_number[-4:]}"
        
        # Save it as a payment method
        db_payment_method = PaymentMethod(
            user_id=current_user.id,
            stripe_payment_method_id=mock_token,
            method_type="bank_account",
            last4=request.account_number[-4:],
            brand="bank",
            is_default=False
        )
        db.add(db_payment_method)
        db.commit()
        
        return {
            "message": "Bank account added successfully (verification required)",
            "payment_method": {
                "id": db_payment_method.id,
                "last4": db_payment_method.last4,
                "type": "bank_account"
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/withdraw")
async def withdraw_to_bank(
    request: WithdrawRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Withdraw money from BlackWallet to bank account"""
    try:
        if request.amount <= 0:
            raise HTTPException(status_code=400, detail="Amount must be positive")
        
        # Calculate instant transfer fee (1.5% with $0.25 minimum)
        instant_fee = 0.0
        total_amount = request.amount
        
        if request.instant_transfer:
            instant_fee = max(request.amount * 0.015, 0.25)
            total_amount = request.amount + instant_fee
        
        if current_user.balance < total_amount:
            raise HTTPException(
                status_code=400, 
                detail=f"Insufficient balance. Need ${total_amount:.2f} (${request.amount:.2f} + ${instant_fee:.2f} fee)"
            )
        
        # Convert to cents
        amount_cents = int(request.amount * 100)
        
        # Create payout (in production, this requires connected account setup)
        # For now, we'll simulate the withdrawal
        
        # Deduct from balance (including fee for instant transfer)
        current_user.balance -= total_amount
        
        # Record transaction
        status = "completed" if request.instant_transfer else "pending"
        transaction = Transaction(
            sender=current_user.username,
            receiver="bank_account",
            amount=request.amount,
            transaction_type="withdrawal",
            external_provider="stripe",
            external_transaction_id=f"{'instant' if request.instant_transfer else 'pending'}_{datetime.utcnow().timestamp()}",
            status=status,
            created_at=datetime.utcnow(),
            extra_data={
                "bank_account_id": request.bank_account_id,
                "instant_transfer": request.instant_transfer,
                "instant_fee": instant_fee
            }
        )
        db.add(transaction)
        
        # Record fee transaction if instant transfer
        if request.instant_transfer and instant_fee > 0:
            fee_transaction = Transaction(
                sender=current_user.username,
                receiver="system_fees",
                amount=instant_fee,
                transaction_type="fee",
                external_provider="internal",
                status="completed",
                created_at=datetime.utcnow(),
                extra_data={"fee_type": "instant_transfer"}
            )
            db.add(fee_transaction)
        
        db.commit()
        
        transfer_time = "Instant (within minutes)" if request.instant_transfer else "1-3 business days"
        
        return {
            "message": f"Withdrawal initiated ({transfer_time})",
            "new_balance": current_user.balance,
            "transaction_id": transaction.id,
            "status": status,
            "instant_transfer": request.instant_transfer,
            "instant_fee": instant_fee,
            "total_deducted": total_amount
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/payment-methods")
async def get_payment_methods(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all payment methods for current user"""
    payment_methods = db.query(PaymentMethod).filter(
        PaymentMethod.user_id == current_user.id
    ).all()
    
    return {
        "payment_methods": [
            {
                "id": pm.id,
                "type": pm.method_type,
                "last4": pm.last4,
                "brand": pm.brand,
                "is_default": pm.is_default
            }
            for pm in payment_methods
        ]
    }

@router.delete("/payment-methods/{payment_method_id}")
async def remove_payment_method(
    payment_method_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Remove a payment method"""
    payment_method = db.query(PaymentMethod).filter(
        PaymentMethod.id == payment_method_id,
        PaymentMethod.user_id == current_user.id
    ).first()
    
    if not payment_method:
        raise HTTPException(status_code=404, detail="Payment method not found")
    
    # Detach from Stripe
    await StripeService.detach_payment_method(payment_method.stripe_payment_method_id)
    
    # Delete from database
    db.delete(payment_method)
    db.commit()
    
    return {"message": "Payment method removed successfully"}
