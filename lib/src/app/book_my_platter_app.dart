import 'package:bookmyplatter/src/app/router.dart';
import 'package:bookmyplatter/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class BookMyPlatterApp extends StatelessWidget {
  const BookMyPlatterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BookMyPlatter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
