# Set root path
$root = "C:\Users\demon\BlackWallet\lib"

# Create folders
$folders = @("screens", "services", "models")
foreach ($folder in $folders) {
    New-Item -ItemType Directory -Path "$root\$folder" -Force
}

# Create and populate files
$files = @{
    "$root\main.dart" = @"
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() => runApp(BlackWalletApp());

class BlackWalletApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlackWallet',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: LoginScreen(),
    );
  }
}
"@

    "$root\screens\login_screen.dart" = @"
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'wallet_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  void login() async {
    final token = await ApiService.login(usernameController.text, passwordController.text);
    if (token != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WalletScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: usernameController, decoration: InputDecoration(labelText: "Username")),
          TextField(controller: passwordController, decoration: InputDecoration(labelText: "Password"), obscureText: true),
          ElevatedButton(onPressed: login, child: Text("Login")),
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SignupScreen())), child: Text("Sign up"))
        ]),
      ),
    );
  }
}
"@

    "$root\screens\signup_screen.dart" = @"
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  void signup() async {
    final success = await ApiService.signup(usernameController.text, passwordController.text);
    if (success) Navigator.pop(context);
    else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Signup failed")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Sign Up")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: usernameController, decoration: InputDecoration(labelText: "Username")),
          TextField(controller: passwordController, decoration: InputDecoration(labelText: "Password"), obscureText: true),
          ElevatedButton(onPressed: signup, child: Text("Create Account"))
        ]),
      ),
    );
  }
}
"@

    "$root\screens\wallet_screen.dart" = @"
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'transfer_screen.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double balance = 0.0;

  void fetchBalance() async {
    final b = await ApiService.getBalance();
    setState(() => balance = b ?? 0.0);
  }

  @override
  void initState() {
    super.initState();
    fetchBalance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Wallet")),
      body: Center(child: Text("Balance: \$${balance.toStringAsFixed(2)}", style: TextStyle(fontSize: 24))),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.send),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransferScreen())),
      ),
    );
  }
}
"@

    "$root\screens\transfer_screen.dart" = @"
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TransferScreen extends StatefulWidget {
  @override
  _TransferScreenState createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final receiverController = TextEditingController();
  final amountController = TextEditingController();

  void transfer() async {
    final success = await ApiService.transfer(receiverController.text, double.parse(amountController.text));
    if (success) Navigator.pop(context);
    else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Transfer failed")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Transfer")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: receiverController, decoration: InputDecoration(labelText: "Receiver")),
          TextField(controller: amountController, decoration: InputDecoration(labelText: "Amount"), keyboardType: TextInputType.number),
          ElevatedButton(onPressed: transfer, child: Text("Send"))
        ]),
      ),
    );
  }
}
"@

    "$root\services\api_service.dart" = @"
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const baseUrl = "http://127.0.0.1:8000";

  static Future<String?> login(String username, String password) async {
    final res = await http.post(Uri.parse("\$baseUrl/login"), body: jsonEncode({"username": username, "password": password}), headers: {"Content-Type": "application/json"});
    if (res.statusCode == 200) return jsonDecode(res.body)["token"];
    return null;
  }

  static Future<bool> signup(String username, String password) async {
    final res = await http.post(Uri.parse("\$baseUrl/signup"), body: jsonEncode({"username": username, "password": password}), headers: {"Content-Type": "application/json"});
    return res.statusCode == 200;
  }

  static Future<double?> getBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    final res = await http.get(Uri.parse("\$baseUrl/balance"), headers: {"Authorization": "Bearer \$token"});
    if (res.statusCode == 200) return jsonDecode(res.body)["balance"];
    return null;
  }

  static Future<bool> transfer(String receiver, double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    final res = await http.post(Uri.parse("\$baseUrl/transfer"), body: jsonEncode({"sender": "me", "receiver": receiver, "amount": amount}), headers: {"Authorization": "Bearer \$token", "Content-Type": "application/json"});
    return res.statusCode == 200;
  }
}
"@
}

# Write files
foreach ($path in $files.Keys) {
    $content = $files[$path]
    $dir = Split-Path $path
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
    Set-Content -Path $path -Value $content
}

Write-Host "✅ Flutter Android wallet app scaffolded at C:\Users\demon\BlackWallet\lib"