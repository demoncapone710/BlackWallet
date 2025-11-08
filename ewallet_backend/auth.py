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
