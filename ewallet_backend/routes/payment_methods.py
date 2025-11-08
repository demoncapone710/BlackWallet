from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import SessionLocal
from models import User, PaymentMethod
from auth import get_current_user
import stripe
import os

router = APIRouter()

# Set Stripe API key
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
if not stripe.api_key:
    raise ValueError("STRIPE_SECRET_KEY environment variable is required")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/setup-intent")
def create_setup_intent(user=Depends(get_current_user), db: Session = Depends(get_db)):
    """Create a Stripe SetupIntent for adding payment methods"""
    db_user = db.query(User).filter_by(username=user["username"]).first()
    
    # Create or get Stripe customer
    if not db_user.stripe_customer_id:
        customer = stripe.Customer.create(
            name=db_user.username,
            metadata={"user_id": db_user.id}
        )
        db_user.stripe_customer_id = customer.id
        db.commit()
    
    # Create SetupIntent
    setup_intent = stripe.SetupIntent.create(
        customer=db_user.stripe_customer_id,
        payment_method_types=["card", "us_bank_account"],
    )
    
    return {
        "client_secret": setup_intent.client_secret,
        "customer_id": db_user.stripe_customer_id
    }

@router.get("/list")
def list_payment_methods(user=Depends(get_current_user), db: Session = Depends(get_db)):
    """List all payment methods for the current user"""
    db_user = db.query(User).filter_by(username=user["username"]).first()
    
    if not db_user.stripe_customer_id:
        return {"payment_methods": []}
    
    # Get from Stripe
    payment_methods = stripe.PaymentMethod.list(
        customer=db_user.stripe_customer_id,
        type="card"
    )
    
    bank_accounts = stripe.PaymentMethod.list(
        customer=db_user.stripe_customer_id,
        type="us_bank_account"
    )
    
    # Get from local database
    local_methods = db.query(PaymentMethod).filter_by(user_id=db_user.id).all()
    
    result = []
    
    # Add cards
    for pm in payment_methods.data:
        result.append({
            "id": pm.id,
            "type": "card",
            "brand": pm.card.brand,
            "last4": pm.card.last4,
            "exp_month": pm.card.exp_month,
            "exp_year": pm.card.exp_year,
            "is_default": any(m.stripe_payment_method_id == pm.id and m.is_default for m in local_methods)
        })
    
    # Add bank accounts
    for pm in bank_accounts.data:
        result.append({
            "id": pm.id,
            "type": "bank_account",
            "bank_name": pm.us_bank_account.bank_name,
            "last4": pm.us_bank_account.last4,
            "account_type": pm.us_bank_account.account_type,
            "is_default": any(m.stripe_payment_method_id == pm.id and m.is_default for m in local_methods)
        })
    
    return {"payment_methods": result}

@router.post("/attach")
def attach_payment_method(
    payment_method_id: str,
    user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Attach a payment method to the user's account"""
    db_user = db.query(User).filter_by(username=user["username"]).first()
    
    if not db_user.stripe_customer_id:
        raise HTTPException(status_code=400, detail="No Stripe customer found")
    
    # Attach payment method to customer in Stripe
    payment_method = stripe.PaymentMethod.attach(
        payment_method_id,
        customer=db_user.stripe_customer_id,
    )
    
    # Save to local database
    is_first = db.query(PaymentMethod).filter_by(user_id=db_user.id).count() == 0
    
    if payment_method.type == "card":
        new_method = PaymentMethod(
            user_id=db_user.id,
            stripe_payment_method_id=payment_method.id,
            method_type="card",
            last4=payment_method.card.last4,
            brand=payment_method.card.brand,
            is_default=is_first
        )
    elif payment_method.type == "us_bank_account":
        new_method = PaymentMethod(
            user_id=db_user.id,
            stripe_payment_method_id=payment_method.id,
            method_type="bank_account",
            last4=payment_method.us_bank_account.last4,
            brand=payment_method.us_bank_account.bank_name,
            is_default=is_first
        )
    else:
        raise HTTPException(status_code=400, detail="Unsupported payment method type")
    
    db.add(new_method)
    db.commit()
    
    return {"msg": "Payment method attached", "payment_method_id": payment_method.id}

@router.post("/set-default/{payment_method_id}")
def set_default_payment_method(
    payment_method_id: str,
    user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Set a payment method as default"""
    db_user = db.query(User).filter_by(username=user["username"]).first()
    
    # Clear all defaults
    db.query(PaymentMethod).filter_by(user_id=db_user.id).update({"is_default": False})
    
    # Set new default
    payment_method = db.query(PaymentMethod).filter_by(
        user_id=db_user.id,
        stripe_payment_method_id=payment_method_id
    ).first()
    
    if not payment_method:
        raise HTTPException(status_code=404, detail="Payment method not found")
    
    payment_method.is_default = True
    db.commit()
    
    return {"msg": "Default payment method updated"}

@router.delete("/remove/{payment_method_id}")
def remove_payment_method(
    payment_method_id: str,
    user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Remove a payment method"""
    db_user = db.query(User).filter_by(username=user["username"]).first()
    
    # Detach from Stripe
    try:
        stripe.PaymentMethod.detach(payment_method_id)
    except stripe.error.InvalidRequestError:
        pass  # Already detached
    
    # Remove from local database
    payment_method = db.query(PaymentMethod).filter_by(
        user_id=db_user.id,
        stripe_payment_method_id=payment_method_id
    ).first()
    
    if payment_method:
        db.delete(payment_method)
        db.commit()
    
    return {"msg": "Payment method removed"}

@router.post("/deposit")
def deposit_funds(
    amount: float,
    payment_method_id: str = None,
    user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Deposit funds using a payment method"""
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    
    db_user = db.query(User).filter_by(username=user["username"]).first()
    
    # Get payment method (use default if not specified)
    if not payment_method_id:
        default_method = db.query(PaymentMethod).filter_by(
            user_id=db_user.id,
            is_default=True
        ).first()
        if not default_method:
            raise HTTPException(status_code=400, detail="No default payment method set")
        payment_method_id = default_method.stripe_payment_method_id
    
    # Create a PaymentIntent
    try:
        payment_intent = stripe.PaymentIntent.create(
            amount=int(amount * 100),  # Convert to cents
            currency="usd",
            customer=db_user.stripe_customer_id,
            payment_method=payment_method_id,
            off_session=True,
            confirm=True,
        )
        
        if payment_intent.status == "succeeded":
            # Update user balance
            db_user.balance += amount
            db.commit()
            
            return {
                "msg": "Deposit successful",
                "amount": amount,
                "new_balance": db_user.balance,
                "transaction_id": payment_intent.id
            }
        else:
            raise HTTPException(status_code=400, detail=f"Payment failed: {payment_intent.status}")
    
    except stripe.error.CardError as e:
        raise HTTPException(status_code=400, detail=str(e.user_message))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/withdraw")
def withdraw_funds(
    amount: float,
    payment_method_id: str = None,
    user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Withdraw funds to a bank account"""
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    
    db_user = db.query(User).filter_by(username=user["username"]).first()
    
    if db_user.balance < amount:
        raise HTTPException(status_code=400, detail="Insufficient funds")
    
    # Get payment method (use default if not specified)
    if not payment_method_id:
        default_method = db.query(PaymentMethod).filter_by(
            user_id=db_user.id,
            is_default=True,
            method_type="bank_account"
        ).first()
        if not default_method:
            raise HTTPException(status_code=400, detail="No default bank account set")
        payment_method_id = default_method.stripe_payment_method_id
    
    # For now, simulate withdrawal (in production, use Stripe Payouts)
    db_user.balance -= amount
    db.commit()
    
    return {
        "msg": "Withdrawal initiated",
        "amount": amount,
        "new_balance": db_user.balance,
        "note": "Funds will arrive in 1-3 business days"
    }
