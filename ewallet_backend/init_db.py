"""
Database initialization script for BlackWallet
Creates test users with initial balance
"""
from database import SessionLocal, engine, Base
from models import User, Transaction
from utils.security import hash_password

def init_db():
    print("Creating database tables...")
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    
    try:
        # Check if admin user exists
        admin = db.query(User).filter_by(username="admin").first()
        if not admin:
            print("Creating admin user...")
            admin = User(
                username="admin",
                password=hash_password("admin123"),
                balance=10000.0,
                is_admin=True
            )
            db.add(admin)
        
        # Check if test users exist
        test_users = [
            ("alice", "alice123", 1000.0),
            ("bob", "bob123", 500.0),
        ]
        
        for username, password, balance in test_users:
            user = db.query(User).filter_by(username=username).first()
            if not user:
                print(f"Creating test user: {username}")
                user = User(
                    username=username,
                    password=hash_password(password),
                    balance=balance,
                    is_admin=False
                )
                db.add(user)
        
        db.commit()
        print("\n✓ Database initialized successfully!")
        print("\nTest accounts created:")
        print("  Admin: admin / admin123 (Balance: $10,000)")
        print("  User: alice / alice123 (Balance: $1,000)")
        print("  User: bob / bob123 (Balance: $500)")
        print("\nYou can now start the server with: uvicorn main:app --reload")
        
    except Exception as e:
        print(f"Error: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    init_db()
