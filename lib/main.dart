import 'package:bookmyplatter/src/app/book_my_platter_app.dart';
import 'package:bookmyplatter/src/core/supabase/bootstrap_supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapSupabase();
  runApp(const ProviderScope(child: BookMyPlatterApp()));
}
