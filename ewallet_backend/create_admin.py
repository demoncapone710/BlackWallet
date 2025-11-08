"""
Create Permanent Admin Account
Run this script once to create the admin account with full privileges
"""
from database import SessionLocal
from models import User
from utils.security import hash_password

def create_admin():
    db = SessionLocal()
    
    # Check if admin already exists
    existing_admin = db.query(User).filter_by(username="admin").first()
    if existing_admin:
        print("❌ Admin account already exists!")
        print(f"   Username: {existing_admin.username}")
        print(f"   Email: {existing_admin.email}")
        print(f"   Admin: {existing_admin.is_admin}")
        
        # Ask if we should update it
        update = input("\nUpdate existing admin account? (yes/no): ").lower()
        if update == "yes":
            existing_admin.is_admin = True
            existing_admin.password = hash_password("Admin@2025")  # Set secure default password
            db.commit()
            print("\n✅ Admin account updated!")
            print("   Username: admin")
            print("   Password: Admin@2025")
            print("   ⚠️  IMPORTANT: Change this password immediately after first login!")
        db.close()
        return
    
    # Create new admin account
    admin_user = User(
        username="admin",
        password=hash_password("Admin@2025"),  # Secure default password
        email="admin@blackwallet.app",
        phone="+1234567890",
        full_name="System Administrator",
        balance=0.0,
        is_admin=True
    )
    
    db.add(admin_user)
    db.commit()
    db.refresh(admin_user)
    
    print("\n" + "="*60)
    print("✅ ADMIN ACCOUNT CREATED SUCCESSFULLY")
    print("="*60)
    print(f"   Username: {admin_user.username}")
    print(f"   Password: Admin@2025")
    print(f"   Email: {admin_user.email}")
    print(f"   Admin Privileges: {admin_user.is_admin}")
    print("="*60)
    print("\n⚠️  IMPORTANT SECURITY NOTICE:")
    print("   1. Change the default password immediately")
    print("   2. Update the email address")
    print("   3. Keep admin credentials secure")
    print("\n📝 Admin Capabilities:")
    print("   • View all users and accounts")
    print("   • Edit user accounts and balances")
    print("   • Monitor app performance and statistics")
    print("   • Switch between test/live Stripe modes")
    print("   • View system logs")
    print("   • Manage transactions")
    print("\n🔗 Admin Endpoints:")
    print("   • GET  /api/admin/users - List all users")
    print("   • GET  /api/admin/users/{id} - User details")
    print("   • PUT  /api/admin/users/{id} - Update user")
    print("   • PUT  /api/admin/users/{id}/balance - Edit balance")
    print("   • GET  /api/admin/stats/overview - System stats")
    print("   • GET  /api/admin/stats/transactions - Transaction stats")
    print("   • GET  /api/admin/config/stripe-mode - Get Stripe mode")
    print("   • POST /api/admin/config/stripe-mode - Set Stripe mode")
    print("\n" + "="*60)
    
    db.close()

if __name__ == "__main__":
    print("\n🔧 BlackWallet Admin Account Creator")
    print("="*60)
    create_admin()
