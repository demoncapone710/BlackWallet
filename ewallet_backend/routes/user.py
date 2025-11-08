from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import SessionLocal
from models import User
from schemas import UserCreate, UserLogin
from utils.security import hash_password, verify_password, create_token

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/signup")
def signup(user: UserCreate, db: Session = Depends(get_db)):
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
    
    return {
        "msg": "User created successfully",
        "username": user.username,
        "email": user.email,
        "full_name": user.full_name
    }

@router.post("/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(User).filter_by(username=user.username).first()
    if not db_user or not verify_password(user.password, db_user.password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = create_token({"username": db_user.username, "is_admin": db_user.is_admin})
    return {"token": token}
