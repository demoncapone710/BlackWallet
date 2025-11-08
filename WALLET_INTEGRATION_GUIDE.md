# Quick Integration Guide - Deposit & Withdraw

## 🚀 Add Deposit/Withdraw to Wallet Screen

### Step 1: Import the New Screens

Add these imports to `lib/screens/wallet_screen.dart`:

```dart
import 'package:black_wallet/screens/real_deposit_screen.dart';
import 'package:black_wallet/screens/real_withdraw_screen.dart';
```

### Step 2: Add Action Buttons

Add these buttons to your wallet screen UI (after the balance display):

```dart
// Add these buttons below the balance card
Padding(
  padding: const EdgeInsets.all(16.0),
  child: Row(
    children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () async {
            // Navigate to deposit screen
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RealDepositScreen(),
              ),
            );
            
            // Refresh balance if deposit was successful
            if (result == true) {
              _refreshBalance();
            }
          },
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Add Money'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () async {
            // Navigate to withdraw screen
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RealWithdrawScreen(),
              ),
            );
            
            // Refresh balance if withdrawal was successful
            if (result == true) {
              _refreshBalance();
            }
          },
          icon: const Icon(Icons.account_balance),
          label: const Text('Cash Out'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ],
  ),
),
```

### Step 3: Add Balance Refresh Method

Add this method to your wallet screen state:

```dart
Future<void> _refreshBalance() async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Fetch updated user info
    final response = await ApiService.getUserInfo();
    
    setState(() {
      _balance = response['balance'];
      _isLoading = false;
    });
    
    // Also refresh transaction history
    _loadTransactions();
  } catch (e) {
    print('Error refreshing balance: $e');
    setState(() {
      _isLoading = false;
    });
  }
}
```

### Step 4: Alternative - Floating Action Button

If you prefer a FAB-style design:

```dart
// In your Scaffold
floatingActionButton: Column(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RealDepositScreen(),
          ),
        );
        if (result == true) _refreshBalance();
      },
      backgroundColor: Colors.green,
      icon: const Icon(Icons.add),
      label: const Text('Deposit'),
      heroTag: 'deposit',
    ),
    const SizedBox(height: 16),
    FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RealWithdrawScreen(),
          ),
        );
        if (result == true) _refreshBalance();
      },
      backgroundColor: Colors.blue,
      icon: const Icon(Icons.account_balance),
      label: const Text('Withdraw'),
      heroTag: 'withdraw',
    ),
  ],
),
```

## 🎨 Design Options

### Option A: Prominent Button Row (Recommended)
```
┌─────────────────────────┐
│  Balance: $1,234.56     │
├─────────────────────────┤
│ [+ Add Money] [Cash Out]│  ← Big, obvious buttons
├─────────────────────────┤
│  Recent Transactions    │
│  • Payment to Alice     │
│  • Received from Bob    │
└─────────────────────────┘
```

### Option B: Card-Style Actions
```
┌─────────────────────────┐
│  Balance: $1,234.56     │
├─────────────────────────┤
│ ┌─────────┐ ┌─────────┐│
│ │    +    │ │    $    ││  ← Card tiles
│ │ Deposit │ │Withdraw ││
│ └─────────┘ └─────────┘│
├─────────────────────────┤
│  Recent Transactions    │
└─────────────────────────┘
```

### Option C: Icon Grid
```
┌─────────────────────────┐
│  Balance: $1,234.56     │
├─────────────────────────┤
│ 💵 Deposit  💳 Withdraw │  ← Icon buttons
│ 📤 Send     📥 Request  │
├─────────────────────────┤
│  Recent Transactions    │
└─────────────────────────┘
```

## ✅ Testing Checklist

After integration:

- [ ] Buttons appear on wallet screen
- [ ] Deposit button navigates correctly
- [ ] Withdraw button navigates correctly
- [ ] Balance refreshes after deposit
- [ ] Balance refreshes after withdrawal
- [ ] Transaction history updates
- [ ] UI looks good on different screen sizes
- [ ] Buttons are easily tappable (min 48x48)
- [ ] Loading states work properly
- [ ] Error handling shows proper messages

## 🐛 Troubleshooting

### Issue: Balance not refreshing
**Solution:** Make sure `_refreshBalance()` is called after navigation returns

### Issue: Buttons overlap other content
**Solution:** Wrap in `Padding` or adjust layout spacing

### Issue: Import errors
**Solution:** Verify file paths match your project structure

### Issue: Navigation not working
**Solution:** Check that context is available and screens are properly imported

## 📱 Example Complete Implementation

Here's a minimal wallet screen with deposit/withdraw:

```dart
import 'package:flutter/material.dart';
import 'package:black_wallet/screens/real_deposit_screen.dart';
import 'package:black_wallet/screens/real_withdraw_screen.dart';
import 'package:black_wallet/services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getUserInfo();
      setState(() {
        _balance = response['balance'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading balance: $e');
    }
  }

  Future<void> _refreshBalance() async {
    await _loadBalance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Balance Card
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'Balance',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${_balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RealDepositScreen(),
                              ),
                            );
                            if (result == true) _refreshBalance();
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Add Money'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RealWithdrawScreen(),
                              ),
                            );
                            if (result == true) _refreshBalance();
                          },
                          icon: const Icon(Icons.account_balance),
                          label: const Text('Cash Out'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Transaction History
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Text(
                        'Recent Transactions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Add your transaction list here
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
```

## 🎯 Next Steps

1. Copy the code above into your wallet screen
2. Test deposit flow with test card: 4242 4242 4242 4242
3. Test withdrawal with connected bank account
4. Verify balance updates properly
5. Check transaction history shows new entries
6. Test error cases (insufficient balance, etc.)

## 📞 Need Help?

If you encounter issues:
1. Check that backend server is running
2. Verify Stripe account is connected
3. Check console logs for errors
4. Test API endpoints directly
5. Review REAL_MONEY_SYSTEM_COMPLETE.md for details
