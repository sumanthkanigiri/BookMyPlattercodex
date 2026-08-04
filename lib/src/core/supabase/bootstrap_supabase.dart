import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _supabaseProjectId = String.fromEnvironment('PROJECT_ID');
bool _supabaseInitialized = false;

bool get isSupabaseInitialized {
  if (_supabaseInitialized) return true;
  try {
    Supabase.instance.client;
    _supabaseInitialized = true;
    return true;
  } catch (_) {
    return false;
  }
}

final supabaseBootstrapProvider = FutureProvider<void>((ref) async {
  await bootstrapSupabase().timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw TimeoutException(
      'Supabase initialization timed out. Check SUPABASE_URL and network access.',
    ),
  );
});

class SupabaseEnvironment {
  const SupabaseEnvironment._();

  static String get projectId => _supabaseProjectId;

  static void validate() {
    final missing = <String>[
      if (_supabaseUrl.trim().isEmpty) 'SUPABASE_URL',
      if (_supabaseAnonKey.trim().isEmpty) 'SUPABASE_ANON_KEY',
      if (_supabaseProjectId.trim().isEmpty) 'PROJECT_ID',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing Supabase environment variables: ${missing.join(', ')}. '
        'Start Flutter with --dart-define values or tool/flutter_with_env.sh.',
      );
    }

    final uri = Uri.tryParse(_supabaseUrl.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('SUPABASE_URL must be a valid HTTPS URL.');
    }

    if (uri.host.endsWith('.supabase.co') &&
        uri.host.split('.').first != _supabaseProjectId.trim()) {
      throw StateError(
        'PROJECT_ID does not match the project reference in SUPABASE_URL.',
      );
    }
  }
}

Future<void> bootstrapSupabase() async {
  if (isSupabaseInitialized) return;

  SupabaseEnvironment.validate();

  await Supabase.initialize(
    url: _supabaseUrl.trim(),
    anonKey: _supabaseAnonKey.trim(),
  );
  _supabaseInitialized = true;
}
