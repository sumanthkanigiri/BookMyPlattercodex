import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupportContact {
  const SupportContact({required this.phone, required this.email, required this.whatsapp});

  factory SupportContact.fromMap(Map<String, dynamic> map) => SupportContact(
        phone: map['phone'] as String? ?? '',
        email: map['email'] as String? ?? '',
        whatsapp: map['whatsapp'] as String? ?? '',
      );

  final String phone;
  final String email;
  final String whatsapp;
}

class FrequentlyAskedQuestion {
  const FrequentlyAskedQuestion({required this.id, required this.question, required this.answer});

  factory FrequentlyAskedQuestion.fromMap(Map<String, dynamic> map) => FrequentlyAskedQuestion(
        id: map['id'] as String,
        question: map['question'] as String,
        answer: map['answer'] as String,
      );

  final String id;
  final String question;
  final String answer;
}

class SupportTicket {
  const SupportTicket({required this.id, required this.subject, required this.status, required this.createdAt});

  factory SupportTicket.fromMap(Map<String, dynamic> map) => SupportTicket(
        id: map['id'] as String,
        subject: map['subject'] as String,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );

  final String id;
  final String subject;
  final String status;
  final DateTime createdAt;
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(supabaseClientProvider));
});

final supportContactProvider = FutureProvider<SupportContact>((ref) {
  return ref.watch(supportRepositoryProvider).contact();
});

final frequentlyAskedQuestionsProvider = FutureProvider<List<FrequentlyAskedQuestion>>((ref) {
  return ref.watch(supportRepositoryProvider).frequentlyAskedQuestions();
});

final supportTicketsProvider = FutureProvider<List<SupportTicket>>((ref) {
  return ref.watch(supportRepositoryProvider).tickets();
});

class SupportRepository {
  const SupportRepository(this._client);

  final SupabaseClient _client;

  Future<SupportContact> contact() async {
    final row = await _client.from('app_config').select('value').eq('key', 'support_contact').single();
    return SupportContact.fromMap(row['value'] as Map<String, dynamic>);
  }

  Future<List<FrequentlyAskedQuestion>> frequentlyAskedQuestions() async {
    final rows = await _client
        .from('frequently_asked_questions')
        .select('id,question,answer')
        .eq('is_active', true)
        .order('sort_order');
    return [for (final row in rows) FrequentlyAskedQuestion.fromMap(row)];
  }

  Future<List<SupportTicket>> tickets() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('support_tickets')
        .select('id,subject,status,created_at')
        .eq('customer_id', userId)
        .order('created_at', ascending: false);
    return [for (final row in rows) SupportTicket.fromMap(row)];
  }

  Future<void> createTicket({required String subject, required String message}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException('Sign in to raise a support ticket', code: 'auth_required');
    }
    final cleanSubject = subject.trim();
    final cleanMessage = message.trim();
    if (cleanSubject.length < 5 || cleanSubject.length > 120) {
      throw const AppException('Subject must contain 5 to 120 characters', code: 'invalid_subject');
    }
    if (cleanMessage.length < 10 || cleanMessage.length > 2000) {
      throw const AppException('Message must contain 10 to 2000 characters', code: 'invalid_message');
    }
    await _client.from('support_tickets').insert({
      'customer_id': userId,
      'subject': cleanSubject,
      'message': cleanMessage,
    });
  }
}
