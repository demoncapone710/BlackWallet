from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
import re

class UserCreate(BaseModel):
    username: str
    password: str
    email: EmailStr
    phone: str
    full_name: str

    @field_validator('phone')
    @classmethod
    def validate_phone(cls, v):
        # Remove all non-digit characters
        phone = re.sub(r'\D', '', v)
        # Check if it's a valid length (10-15 digits)
        if len(phone) < 10 or len(phone) > 15:
            raise ValueError('Phone number must be 10-15 digits')
        return phone
    
    @field_validator('full_name')
    @classmethod
    def validate_full_name(cls, v):
        if len(v.strip()) < 2:
            raise ValueError('Full name must be at least 2 characters')
        return v.strip()
    
    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 6:
            raise ValueError('Password must be at least 6 characters')
        return v

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

class ForgotPasswordRequest(BaseModel):
    identifier: str  # Can be email or phone

class VerifyResetCode(BaseModel):
    identifier: str  # email or phone
    code: str

class ResetPassword(BaseModel):
    identifier: str  # email or phone
    code: str
    new_password: str
    
    @field_validator('new_password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 6:
            raise ValueError('Password must be at least 6 characters')
        return v

class SendMoneyByContact(BaseModel):
    contact: str  # phone or email
    amount: float
    contact_type: str  # 'phone' or 'email'
