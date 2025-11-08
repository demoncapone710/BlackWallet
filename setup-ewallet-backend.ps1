# Define root folder
$root = "ewallet_backend"
New-Item -ItemType Directory -Path $root -Force

# Create subfolders
$folders = @("routes", "utils")
foreach ($folder in $folders) {
    New-Item -ItemType Directory -Path "$root\$folder" -Force
}

# Create and populate files
$files = @{
    "main.py" = @"
from fastapi import FastAPI
from routes import user, wallet, admin
from database import Base, engine

Base.metadata.create_all(bind=engine)

app = FastAPI()
app.include_router(user.router)
app.include_router(wallet.router)
app.include_router(admin.router)
"@

    "database.py" = @"
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = "sqlite:///./ewallet.db"

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
Base = declarative_base()
"@

    "models.py" = @"
from sqlalchemy import Column, Integer, String, Float, Boolean
from database import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True)
    password = Column(String)
    balance = Column(Float, default=0.0)
    is_admin = Column(Boolean, default=False)

class Transaction(Base):
    __tablename__ = "transactions"
    id = Column(Integer, primary_key=True)
    sender = Column(String)
    receiver = Column(String)
    amount = Column(Float)
"@

    "schemas.py" = @"
from pydantic import BaseModel

class UserCreate(BaseModel):
    username: str
    password: str

class UserLogin(BaseModel):
    username: str
    password: str

class BalanceUpdate(BaseModel):
    username: str
    amount: float

class Transfer(BaseModel):
    sender: str
    receiver: str
    amount: float
"@

    "auth.py" = @"
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer
from utils.security import decode_token

security = HTTPBearer()

def get_current_user(token: str = Depends(security)):
    try:
        payload = decode_token(token.credentials)
        return payload
    except:
        raise HTTPException(status_code=403, detail="Invalid token")
"@

    "utils/security.py" = @"
from passlib.context import CryptContext
import jwt

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
SECRET_KEY = "your-secret-key"

def hash_password(password: str):
    return pwd_context.hash(password)

def verify_password(plain, hashed):
    return pwd_context.verify(plain, hashed)

def create_token(data: dict):
    return jwt.encode(data, SECRET_KEY, algorithm="HS256")

def decode_token(token: str):
    return jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
"@

    "routes/user.py" = @"
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
    if db.query(User).filter_by(username=user.username).first():
        raise HTTPException(status_code=400, detail="User exists")
    new_user = User(username=user.username, password=hash_password(user.password))
    db.add(new_user)
    db.commit()
    return {"msg": "User created"}

@router.post("/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(User).filter_by(username=user.username).first()
    if not db_user or not verify_password(user.password, db_user.password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = create_token({"username": db_user.username, "is_admin": db_user.is_admin})
    return {"token": token}
"@

    "routes/wallet.py" = @"
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import SessionLocal
from models import User, Transaction
from schemas import Transfer
from auth import get_current_user

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.get("/balance")
def get_balance(user=Depends(get_current_user), db: Session = Depends(get_db)):
    db_user = db.query(User).filter_by(username=user["username"]).first()
    return {"balance": db_user.balance}

@router.post("/transfer")
def transfer(data: Transfer, db: Session = Depends(get_db)):
    sender = db.query(User).filter_by(username=data.sender).first()
    receiver = db.query(User).filter_by(username=data.receiver).first()
    if sender.balance < data.amount:
        return {"error": "Insufficient funds"}
    sender.balance -= data.amount
    receiver.balance += data.amount
    db.add(Transaction(sender=data.sender, receiver=data.receiver, amount=data.amount))
    db.commit()
    return {"msg": "Transfer complete"}
"@

    "routes/admin.py" = @"
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import SessionLocal
from models import User
from schemas import BalanceUpdate
from auth import get_current_user

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/admin/edit_balance")
def edit_balance(data: BalanceUpdate, user=Depends(get_current_user), db: Session = Depends(get_db)):
    if not user["is_admin"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    target = db.query(User).filter_by(username=data.username).first()
    target.balance = data.amount
    db.commit()
    return {"msg": "Balance updated"}
"@
}

# Write files
foreach ($name in $files.Keys) {
    $path = if ($name -like "*/*") { "$root\$name" } else { "$root\$name" }
    $content = $files[$name]
    $dir = Split-Path $path
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
    Set-Content -Path $path -Value $content
}

Write-Host "✅ FastAPI e-wallet backend scaffolded at $root"