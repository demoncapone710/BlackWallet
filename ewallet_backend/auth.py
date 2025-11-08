from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer
from sqlalchemy.orm import Session
from utils.security import decode_token
from database import get_db
from models import User

security = HTTPBearer()

def get_current_user(token: str = Depends(security), db: Session = Depends(get_db)):
    try:
        payload = decode_token(token.credentials)
        user_id = payload.get("user_id")
        if not user_id:
            raise HTTPException(status_code=403, detail="Invalid token payload")
        
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        return user
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=403, detail=f"Invalid token: {str(e)}")
