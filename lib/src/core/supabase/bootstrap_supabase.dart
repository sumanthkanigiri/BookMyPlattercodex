import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _supabaseProjectId = String.fromEnvironment('PROJECT_ID');

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

    final uri = Uri.tryParse(_supabaseUrl);
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
  SupabaseEnvironment.validate();

  await Supabase.initialize(
    url: _supabaseUrl.trim(),
    anonKey: _supabaseAnonKey.trim(),
  );
}
