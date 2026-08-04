import 'package:bookmyplatter/src/core/theme/app_theme.dart';
import 'package:bookmyplatter_website/src/router.dart';
import 'package:flutter/material.dart';

class BookMyPlatterWebsite extends StatelessWidget {
  const BookMyPlatterWebsite({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'BookMyPlatter | Premium Catering',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: websiteRouter,
      );
}
