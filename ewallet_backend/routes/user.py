from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import SessionLocal
from models import User
from schemas import UserCreate, UserLogin
from utils.security import hash_password, verify_password, create_token
from services.stripe_service import StripePaymentService
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/signup")
async def signup(user: UserCreate, db: Session = Depends(get_db)):
    # Check if username exists
    if db.query(User).filter_by(username=user.username).first():
        raise HTTPException(status_code=400, detail="Username already exists")
    
    # Check if email exists
    if user.email and db.query(User).filter_by(email=user.email).first():
        raise HTTPException(status_code=400, detail="Email already exists")
    
    # Check if phone exists
    if user.phone and db.query(User).filter_by(phone=user.phone).first():
        raise HTTPException(status_code=400, detail="Phone number already exists")
    
    # Create new user with all fields
    new_user = User(
        username=user.username,
        password=hash_password(user.password),
        email=user.email,
        phone=user.phone,
        full_name=user.full_name
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Automatically create Stripe Connect account for real money transfers
    stripe_account_id = None
    try:
        stripe_result = await StripePaymentService.create_connected_account(
            user_id=new_user.id,
            email=new_user.email,
            country="US"
        )
        stripe_account_id = stripe_result["stripe_account_id"]
        new_user.stripe_account_id = stripe_account_id
        db.commit()
        logger.info(f"Created Stripe account for new user {new_user.id}: {stripe_account_id}")
    except Exception as e:
        logger.error(f"Failed to create Stripe account for user {new_user.id}: {e}")
        # Don't fail signup if Stripe creation fails - user can set up later
    
    return {
        "msg": "User created successfully",
        "username": user.username,
        "email": user.email,
        "full_name": user.full_name,
        "stripe_account_created": stripe_account_id is not None,
        "stripe_onboarding_required": stripe_account_id is not None
    }

@router.post("/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(User).filter_by(username=user.username).first()
    if not db_user or not verify_password(user.password, db_user.password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = create_token({
        "user_id": db_user.id,
        "username": db_user.username,
        "is_admin": db_user.is_admin
    })
    return {
        "token": token,
        "is_admin": db_user.is_admin,
        "username": db_user.username
    }
