from fastapi import APIRouter, Depends, HTTPException
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

@router.get("/me")
def get_current_user_info(user=Depends(get_current_user), db: Session = Depends(get_db)):
    db_user = db.query(User).filter_by(username=user["username"]).first()
    return {"username": db_user.username, "balance": db_user.balance, "is_admin": db_user.is_admin}

@router.get("/balance")
def get_balance(user=Depends(get_current_user), db: Session = Depends(get_db)):
    db_user = db.query(User).filter_by(username=user["username"]).first()
    return {"balance": db_user.balance}

@router.post("/transfer")
def transfer(data: Transfer, user=Depends(get_current_user), db: Session = Depends(get_db)):
    # Verify the sender is the authenticated user
    if data.sender != user["username"]:
        raise HTTPException(status_code=403, detail="Cannot transfer from another user's account")
    
    sender = db.query(User).filter_by(username=data.sender).first()
    receiver = db.query(User).filter_by(username=data.receiver).first()
    
    if not sender:
        raise HTTPException(status_code=404, detail="Sender not found")
    if not receiver:
        raise HTTPException(status_code=404, detail="Receiver not found")
    if sender.username == receiver.username:
        raise HTTPException(status_code=400, detail="Cannot transfer to yourself")
    if sender.balance < data.amount:
        raise HTTPException(status_code=400, detail="Insufficient funds")
    if data.amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    
    sender.balance -= data.amount
    receiver.balance += data.amount
    db.add(Transaction(sender=data.sender, receiver=data.receiver, amount=data.amount))
    db.commit()
    return {"msg": "Transfer complete", "new_balance": sender.balance}

@router.get("/transactions")
def get_transactions(user=Depends(get_current_user), db: Session = Depends(get_db)):
    username = user["username"]
    transactions = db.query(Transaction).filter(
        (Transaction.sender == username) | (Transaction.receiver == username)
    ).order_by(Transaction.id.desc()).limit(50).all()
    
    return {
        "transactions": [
            {
                "id": t.id,
                "sender": t.sender,
                "receiver": t.receiver,
                "amount": t.amount,
                "type": "sent" if t.sender == username else "received"
            }
            for t in transactions
        ]
    }
