import 'package:bookmyplatter/src/features/assistant/application/catering_assistant_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking assistant progress round-trips through Supabase JSON', () {
    final eventDate = DateTime(2026, 12, 10);
    final state = CateringAssistantState(
      eventType: 'wedding',
      foodPreference: 'both',
      guestCount: 150,
      eventDate: eventDate,
      mealTime: 'dinner',
      addressId: 'address-id',
      budgetMaximum: 50000,
    );

    final restored = CateringAssistantState.fromMap(state.toMap());
    expect(restored.eventType, 'wedding');
    expect(restored.foodPreference, 'both');
    expect(restored.guestCount, 150);
    expect(restored.eventDate, eventDate);
    expect(restored.mealTime, 'dinner');
    expect(restored.addressId, 'address-id');
    expect(restored.budgetMaximum, 50000);
  });
}
