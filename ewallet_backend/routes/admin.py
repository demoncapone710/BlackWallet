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
