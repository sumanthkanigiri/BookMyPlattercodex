import 'package:bookmyplatter/src/features/support/application/support_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps support configuration returned by Supabase', () {
    final contact = SupportContact.fromMap({
      'phone': '+91 98765 43210',
      'email': 'care@bookmyplatter.com',
      'whatsapp': '+91 98765 43210',
    });

    expect(contact.phone, '+91 98765 43210');
    expect(contact.email, 'care@bookmyplatter.com');
    expect(contact.whatsapp, '+91 98765 43210');
  });

  test('maps support tickets with local timestamps', () {
    final ticket = SupportTicket.fromMap({
      'id': 'ticket-id',
      'subject': 'Payment confirmation',
      'status': 'in_progress',
      'created_at': '2026-08-04T12:00:00Z',
    });

    expect(ticket.id, 'ticket-id');
    expect(ticket.status, 'in_progress');
    expect(ticket.createdAt.isUtc, isFalse);
  });
}
