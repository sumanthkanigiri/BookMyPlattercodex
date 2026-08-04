import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authenticatedUserIdProvider = StreamProvider<String?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  var currentId = client.auth.currentUser?.id;
  yield currentId;
  await for (final state in client.auth.onAuthStateChange) {
    final nextId = state.session?.user.id;
    if (nextId != currentId) {
      currentId = nextId;
      yield nextId;
    }
  }
});
