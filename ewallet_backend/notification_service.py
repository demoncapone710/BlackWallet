"""
Notification Service for BlackWallet
Handles SMS (via Twilio) and Email (via SMTP) notifications
"""
import os
import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional

logger = logging.getLogger(__name__)

# Twilio (optional - will gracefully handle if not configured)
try:
    from twilio.rest import Client
    TWILIO_AVAILABLE = True
except ImportError:
    TWILIO_AVAILABLE = False
    logger.warning("Twilio not installed. SMS features will be disabled.")

class NotificationService:
    """Service for sending SMS and Email notifications"""
    
    def __init__(self):
        # Twilio Configuration (for SMS)
        self.twilio_account_sid = os.getenv("TWILIO_ACCOUNT_SID")
        self.twilio_auth_token = os.getenv("TWILIO_AUTH_TOKEN")
        self.twilio_phone_number = os.getenv("TWILIO_PHONE_NUMBER")
        
        # Email Configuration (SMTP)
        self.smtp_host = os.getenv("SMTP_HOST", "smtp.gmail.com")
        self.smtp_port = int(os.getenv("SMTP_PORT", "587"))
        self.smtp_username = os.getenv("SMTP_USERNAME")
        self.smtp_password = os.getenv("SMTP_PASSWORD")
        self.smtp_from_email = os.getenv("SMTP_FROM_EMAIL", self.smtp_username)
        
        # Initialize Twilio client if available and configured
        self.twilio_client = None
        if TWILIO_AVAILABLE and self.twilio_account_sid and self.twilio_auth_token:
            try:
                self.twilio_client = Client(self.twilio_account_sid, self.twilio_auth_token)
                logger.info("Twilio client initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize Twilio client: {e}")
    
    async def send_sms(self, to_phone: str, message: str) -> bool:
        """
        Send SMS message via Twilio
        
        Args:
            to_phone: Recipient phone number (include country code, e.g., +1234567890)
            message: SMS message content
        
        Returns:
            bool: True if sent successfully, False otherwise
        """
        if not self.twilio_client:
            logger.warning("Twilio not configured. SMS cannot be sent.")
            return False
        
        try:
            # Ensure phone number has country code
            if not to_phone.startswith('+'):
                to_phone = f'+1{to_phone}'  # Default to US country code
            
            message_obj = self.twilio_client.messages.create(
                body=message,
                from_=self.twilio_phone_number,
                to=to_phone
            )
            
            logger.info(f"SMS sent successfully to {to_phone}. SID: {message_obj.sid}")
            return True
        
        except Exception as e:
            logger.error(f"Failed to send SMS to {to_phone}: {e}")
            return False
    
    async def send_email(self, to_email: str, subject: str, body: str, html: bool = False) -> bool:
        """
        Send email via SMTP
        
        Args:
            to_email: Recipient email address
            subject: Email subject
            body: Email body content
            html: If True, body is HTML; if False, body is plain text
        
        Returns:
            bool: True if sent successfully, False otherwise
        """
        if not self.smtp_username or not self.smtp_password:
            logger.warning("SMTP not configured. Email cannot be sent.")
            # For development, log the email instead
            logger.info(f"[DEV MODE] Would send email to {to_email}: {subject}\n{body}")
            return True  # Return True for development
        
        try:
            # Create message
            msg = MIMEMultipart('alternative')
            msg['Subject'] = subject
            msg['From'] = self.smtp_from_email
            msg['To'] = to_email
            
            # Attach body
            mime_type = 'html' if html else 'plain'
            msg.attach(MIMEText(body, mime_type))
            
            # Send via SMTP
            with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
                server.starttls()
                server.login(self.smtp_username, self.smtp_password)
                server.send_message(msg)
            
            logger.info(f"Email sent successfully to {to_email}")
            return True
        
        except Exception as e:
            logger.error(f"Failed to send email to {to_email}: {e}")
            return False
    
    async def send_password_reset_code(self, identifier: str, code: str, method: str) -> bool:
        """
        Send password reset code via SMS or Email
        
        Args:
            identifier: Phone number or email address
            code: 6-digit verification code
            method: 'sms' or 'email'
        
        Returns:
            bool: True if sent successfully
        """
        if method == 'sms':
            message = f"Your BlackWallet password reset code is: {code}\n\nThis code expires in 15 minutes.\n\nIf you didn't request this, please ignore this message."
            return await self.send_sms(identifier, message)
        
        elif method == 'email':
            subject = "BlackWallet Password Reset Code"
            body = f"""
            <html>
                <body style="font-family: Arial, sans-serif;">
                    <h2 style="color: #DC143C;">BlackWallet Password Reset</h2>
                    <p>Your password reset code is:</p>
                    <h1 style="background: #f0f0f0; padding: 20px; text-align: center; letter-spacing: 8px;">{code}</h1>
                    <p>This code expires in 15 minutes.</p>
                    <p>If you didn't request a password reset, please ignore this email.</p>
                    <br>
                    <p style="color: #666; font-size: 12px;">BlackWallet Team</p>
                </body>
            </html>
            """
            return await self.send_email(identifier, subject, body, html=True)
        
        return False
    
    async def send_money_notification(self, identifier: str, sender_name: str, amount: float, method: str) -> bool:
        """
        Send notification about received money
        
        Args:
            identifier: Phone number or email address
            sender_name: Name of the sender
            amount: Amount sent
            method: 'sms' or 'email'
        
        Returns:
            bool: True if sent successfully
        """
        if method == 'sms':
            message = f"{sender_name} sent you ${amount:.2f} via BlackWallet!\n\nDownload BlackWallet to claim your money: https://blackwallet.app"
            return await self.send_sms(identifier, message)
        
        elif method == 'email':
            subject = f"{sender_name} sent you ${amount:.2f}!"
            body = f"""
            <html>
                <body style="font-family: Arial, sans-serif;">
                    <h2 style="color: #DC143C;">You've Got Money! 💰</h2>
                    <p><strong>{sender_name}</strong> sent you <strong>${amount:.2f}</strong> via BlackWallet!</p>
                    <div style="background: #f0f0f0; padding: 20px; margin: 20px 0; border-left: 4px solid #DC143C;">
                        <p style="margin: 0;">Download BlackWallet to claim your money instantly:</p>
                        <a href="https://blackwallet.app" style="display: inline-block; margin-top: 10px; padding: 12px 24px; background: #DC143C; color: white; text-decoration: none; border-radius: 5px;">Download BlackWallet</a>
                    </div>
                    <p style="color: #666; font-size: 12px;">BlackWallet - Fast, Secure, Simple</p>
                </body>
            </html>
            """
            return await self.send_email(identifier, subject, body, html=True)
        
        return False

# Global instance
notification_service = NotificationService()
