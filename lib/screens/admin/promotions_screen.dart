import 'package:flutter/material.dart';

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions Management'),
      ),
      body: const Center(
        child: Text('Coming Soon: Create and manage promo codes'),
      ),
    );
  }
}
