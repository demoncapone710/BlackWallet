import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/biometric_auth_screen.dart';
import 'screens/wallet_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Stripe with publishable key
  Stripe.publishableKey = "pk_test_51QQ6K8JJdkCIg3KlaB7TrKZfI2qIPhNCNdSrxXHV9nQbdqLUz3TJ5hR8xgPfZJ2w1KcCWP3pqIhFPQVCFjsomVtT00CJ2bLBvY";
  
  // Initialize notifications
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();
  
  runApp(BlackWalletApp());
}

class AppInitializer extends StatefulWidget {
  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFDC143C),
          ),
        ),
      );
    }

    if (_isLoggedIn) {
      // If logged in, show biometric auth before wallet screen
      return BiometricAuthScreen(
        destinationScreen: WalletScreen(),
      );
    } else {
      // If not logged in, show login screen
      return LoginScreen();
    }
  }
}

class BlackWalletApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlackWallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        primaryColor: const Color(0xFFDC143C),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        brightness: Brightness.dark,
        
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(color: Color(0xFFCCCCCC), fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
          bodyMedium: TextStyle(color: Colors.white, fontSize: 14),
          bodySmall: TextStyle(color: Color(0xFF888888)),
          labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFF0A0A0A),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1A1A),
          elevation: 8,
          shadowColor: Colors.red.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC143C),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.red.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        
        // White input fields with BLACK text
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white, // White background
          hintStyle: const TextStyle(color: Color(0xFF666666)), // Dark grey hint
          labelStyle: const TextStyle(color: Color(0xFF333333)), // Dark label
          floatingLabelStyle: const TextStyle(color: Color(0xFFDC143C)), // Red when focused
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDC143C), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIconColor: const Color(0xFFDC143C),
          suffixIconColor: const Color(0xFF666666),
        ),
        
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFFDC143C),
          selectionColor: Color(0x33DC143C),
          selectionHandleColor: Color(0xFFDC143C),
        ),
        
        iconTheme: const IconThemeData(
          color: Color(0xFFDC143C),
        ),
      ),
      home: AppInitializer(),
    );
  }
}

