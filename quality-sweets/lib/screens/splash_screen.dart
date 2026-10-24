import 'package:flutter/material.dart';

import '../theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.error});

  final String? error;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SizedBox.expand(
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/brand/shop_badge.png',
              width: 280,
              height: 280,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 36),
            if (error == null)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: QsColors.maroon,
                  strokeWidth: 3,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: QsColors.maroon, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
