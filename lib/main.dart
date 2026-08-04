import 'dart:async';

import 'package:bookmyplatter/src/app/book_my_platter_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('BookMyPlatter Flutter error: ${details.exceptionAsString()}');
    };
    ErrorWidget.builder = (details) => _StartupErrorFallback(
          message: details.exceptionAsString(),
        );
    runApp(const ProviderScope(child: BookMyPlatterApp()));
  }, (error, stackTrace) {
    debugPrint('BookMyPlatter startup error: $error');
    debugPrintStack(stackTrace: stackTrace);
  });
}

class _StartupErrorFallback extends StatelessWidget {
  const _StartupErrorFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.white,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'BookMyPlatter could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
