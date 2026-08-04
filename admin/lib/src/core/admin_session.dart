import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

class AdminIdentity {
  const AdminIdentity({required this.id, required this.name, required this.role});
  final String id;
  final String name;
  final String role;
  bool get canManage => role == 'admin';
}

final adminIdentityProvider = StreamProvider<AdminIdentity?>((ref) async* {
  final client = ref.watch(supabaseProvider);
  Future<AdminIdentity?> load() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final profile = await client.from('profiles').select('full_name,role').eq('id', user.id).single();
    final role = profile['role'] as String;
    if (!const {'admin', 'support', 'kitchen', 'delivery_partner'}.contains(role)) {
      await client.auth.signOut();
      throw StateError('This account is not authorized for administration');
    }
    return AdminIdentity(id: user.id, name: profile['full_name'] as String, role: role);
  }

  yield await load();
  await for (final _ in client.auth.onAuthStateChange) {
    yield await load();
  }
});

class AdminAuthRepository {
  const AdminAuthRepository(this.client);
  final SupabaseClient client;

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email.trim(), password: password);
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Authentication failed');
    final profile = await client.from('profiles').select('role').eq('id', user.id).single();
    if (!const {'admin', 'support', 'kitchen', 'delivery_partner'}.contains(profile['role'])) {
      await client.auth.signOut();
      throw const AuthException('This account is not authorized for administration');
    }
  }

  Future<void> resetPassword(String email) => client.auth.resetPasswordForEmail(email.trim());
  Future<void> signOut() => client.auth.signOut();
}

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>((ref) {
  return AdminAuthRepository(ref.watch(supabaseProvider));
});
