"""
Database reset script for BlackWallet
Deletes all existing users and creates new test accounts with all required fields
"""
import os
from database import SessionLocal, engine, Base
from models import User, Transaction
from utils.security import hash_password

def reset_database():
    print("=" * 60)
    print("BlackWallet Database Reset")
    print("=" * 60)
    
    # Drop all tables
    print("\n[1/3] Dropping all existing tables...")
    Base.metadata.drop_all(bind=engine)
    print("✓ All tables dropped")
    
    # Create fresh tables
    print("\n[2/3] Creating fresh database tables...")
    Base.metadata.create_all(bind=engine)
    print("✓ Tables created with new schema")
    
    # Create new test accounts
    print("\n[3/3] Creating new test accounts...")
    db = SessionLocal()
    
    try:
        # Test Account 1: Admin with full details
        print("  → Creating admin account...")
        admin = User(
            username="admin",
            password=hash_password("admin123"),
            full_name="System Administrator",
            email="admin@blackwallet.com",
            phone="5551234567",
            balance=10000.0,
            is_admin=True
        )
        db.add(admin)
        
        # Test Account 2: Alice
        print("  → Creating test user: alice...")
        alice = User(
            username="alice",
            password=hash_password("alice123"),
            full_name="Alice Johnson",
            email="alice@example.com",
            phone="5551111111",
            balance=1000.0,
            is_admin=False
        )
        db.add(alice)
        
        # Test Account 3: Bob
        print("  → Creating test user: bob...")
        bob = User(
            username="bob",
            password=hash_password("bob123"),
            full_name="Bob Smith",
            email="bob@example.com",
            phone="5552222222",
            balance=500.0,
            is_admin=False
        )
        db.add(bob)
        
        # Test Account 4: Charlie (for testing)
        print("  → Creating test user: charlie...")
        charlie = User(
            username="charlie",
            password=hash_password("charlie123"),
            full_name="Charlie Brown",
            email="charlie@example.com",
            phone="5553333333",
            balance=250.0,
            is_admin=False
        )
        db.add(charlie)
        
        # Real Account: Your actual account (you can customize this)
        print("  → Creating real account: demo...")
        demo = User(
            username="demo",
            password=hash_password("Demo@123"),
            full_name="Demo User",
            email="demo@blackwallet.com",
            phone="12065303749",
            balance=5000.0,
            is_admin=False
        )
        db.add(demo)
        
        db.commit()
        
        print("\n" + "=" * 60)
        print("✓ Database reset completed successfully!")
        print("=" * 60)
        print("\n📋 Account Summary:")
        print("-" * 60)
        print("  1. ADMIN ACCOUNT:")
        print("     Username: admin")
        print("     Password: admin123")
        print("     Email: admin@blackwallet.com")
        print("     Phone: 555-123-4567")
        print("     Balance: $10,000.00")
        print()
        print("  2. TEST ACCOUNT - Alice:")
        print("     Username: alice")
        print("     Password: alice123")
        print("     Email: alice@example.com")
        print("     Phone: 555-111-1111")
        print("     Balance: $1,000.00")
        print()
        print("  3. TEST ACCOUNT - Bob:")
        print("     Username: bob")
        print("     Password: bob123")
        print("     Email: bob@example.com")
        print("     Phone: 555-222-2222")
        print("     Balance: $500.00")
        print()
        print("  4. TEST ACCOUNT - Charlie:")
        print("     Username: charlie")
        print("     Password: charlie123")
        print("     Email: charlie@example.com")
        print("     Phone: 555-333-3333")
        print("     Balance: $250.00")
        print()
        print("  5. REAL ACCOUNT - Demo:")
        print("     Username: demo")
        print("     Password: Demo@123")
        print("     Email: demo@blackwallet.com")
        print("     Phone: +1 (206) 530-3749")
        print("     Balance: $5,000.00")
        print("-" * 60)
        print("\n💡 All accounts have complete profiles with:")
        print("   ✓ Full name")
        print("   ✓ Email address")
        print("   ✓ Phone number")
        print("   ✓ Username & password")
        print()
        print("🚀 You can now login with any of these accounts!")
        print("   The backend server will auto-reload with the new database.")
        print()
        
    except Exception as e:
        print(f"\n❌ Error creating accounts: {e}")
        db.rollback()
        raise
    finally:
        db.close()

if __name__ == "__main__":
    reset_database()
