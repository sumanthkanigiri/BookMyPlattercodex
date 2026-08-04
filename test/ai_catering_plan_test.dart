import 'package:bookmyplatter/src/features/assistant/application/catering_assistant_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AiCateringPlan maps recommendation payload', () {
    final plan = AiCateringPlan.fromMap({
      'best_package': {'name': 'Royal Wedding Feast', 'reason': 'Best fit'},
      'budget': {'maximum': 50000, 'per_guest': 500},
      'guest_estimate': {'recommended_buffer_guests': 108},
      'serving_plan': {'starters': 4, 'mains': 3, 'desserts': 2, 'service_staff': 3},
      'festival_recommendation': 'Add festival sweets.',
      'support_answer': 'A specialist can confirm the plan.',
      'faq': [
        {'question': 'Can I customize?', 'answer': 'Yes'},
      ],
    });

    expect(plan.bestPackage['name'], 'Royal Wedding Feast');
    expect(plan.budget['per_guest'], 500);
    expect(plan.guestEstimate['recommended_buffer_guests'], 108);
    expect(plan.servingPlan['service_staff'], 3);
    expect(plan.faq.single['answer'], 'Yes');
  });
}
