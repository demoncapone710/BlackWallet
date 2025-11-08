import 'package:flutter/material.dart';

class AdvertisementsScreen extends StatelessWidget {
  const AdvertisementsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advertisement Management'),
      ),
      body: const Center(
        child: Text('Coming Soon: Create and manage in-app advertisements'),
      ),
    );
  }
}
