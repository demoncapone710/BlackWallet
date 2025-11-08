import stripe
import os
from dotenv import load_dotenv

load_dotenv()

stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
if not stripe.api_key:
    raise ValueError("STRIPE_SECRET_KEY environment variable is required")

class StripeService:
    """Service for handling Stripe operations"""
    
    @staticmethod
    async def create_customer(username: str, email: str = None):
        """Create a Stripe customer for a user"""
        try:
            customer = stripe.Customer.create(
                name=username,
                email=email,
                metadata={"username": username}
            )
            return customer.id
        except Exception as e:
            print(f"Error creating Stripe customer: {e}")
            return None
    
    @staticmethod
    async def attach_payment_method(customer_id: str, payment_method_id: str):
        """Attach a payment method to a customer"""
        try:
            payment_method = stripe.PaymentMethod.attach(
                payment_method_id,
                customer=customer_id,
            )
            return payment_method
        except Exception as e:
            print(f"Error attaching payment method: {e}")
            return None
    
    @staticmethod
    async def create_payment_intent(amount: int, customer_id: str, payment_method_id: str):
        """Create a payment intent for depositing money
        
        Args:
            amount: Amount in cents (e.g., 1000 = $10.00)
            customer_id: Stripe customer ID
            payment_method_id: Stripe payment method ID
        """
        try:
            payment_intent = stripe.PaymentIntent.create(
                amount=amount,
                currency="usd",
                customer=customer_id,
                payment_method=payment_method_id,
                confirm=True,
                automatic_payment_methods={
                    'enabled': True,
                    'allow_redirects': 'never'
                },
                metadata={
                    "transaction_type": "deposit",
                }
            )
            return payment_intent
        except Exception as e:
            print(f"Error creating payment intent: {e}")
            return None
    
    @staticmethod
    async def create_bank_account_token(account_number: str, routing_number: str):
        """Create a bank account token for ACH transfers"""
        try:
            token = stripe.Token.create(
                bank_account={
                    "country": "US",
                    "currency": "usd",
                    "account_holder_name": "Account Holder",
                    "account_holder_type": "individual",
                    "routing_number": routing_number,
                    "account_number": account_number,
                }
            )
            return token.id
        except Exception as e:
            print(f"Error creating bank account token: {e}")
            return None
    
    @staticmethod
    async def create_payout(amount: int, bank_account_id: str):
        """Create a payout to a bank account (withdrawal)
        
        Args:
            amount: Amount in cents (e.g., 1000 = $10.00)
            bank_account_id: Stripe bank account ID
        """
        try:
            # For ACH transfers, use Transfers API
            transfer = stripe.Transfer.create(
                amount=amount,
                currency="usd",
                destination=bank_account_id,
                metadata={
                    "transaction_type": "withdrawal"
                }
            )
            return transfer
        except Exception as e:
            print(f"Error creating payout: {e}")
            return None
    
    @staticmethod
    async def get_payment_methods(customer_id: str):
        """Get all payment methods for a customer"""
        try:
            payment_methods = stripe.PaymentMethod.list(
                customer=customer_id,
                type="card"
            )
            return payment_methods.data
        except Exception as e:
            print(f"Error getting payment methods: {e}")
            return []
    
    @staticmethod
    async def detach_payment_method(payment_method_id: str):
        """Remove a payment method"""
        try:
            payment_method = stripe.PaymentMethod.detach(payment_method_id)
            return payment_method
        except Exception as e:
            print(f"Error detaching payment method: {e}")
            return None
    
    @staticmethod
    async def verify_bank_account(bank_account_id: str, amounts: list):
        """Verify a bank account with micro-deposits"""
        try:
            bank_account = stripe.Customer.verify_source(
                bank_account_id,
                amounts=amounts,
            )
            return bank_account
        except Exception as e:
            print(f"Error verifying bank account: {e}")
            return None
