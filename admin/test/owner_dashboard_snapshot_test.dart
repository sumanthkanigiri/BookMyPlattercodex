import 'package:bookmyplatter_admin/src/features/dashboard/dashboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OwnerDashboardSnapshot maps analytics sections', () {
    final snapshot = OwnerDashboardSnapshot.fromMap({
      'owner_dashboard': {'today_revenue': 125000, 'today_orders': 8},
      'sales_analytics': {'lead_conversion_percent': 42.5},
      'customer_analytics': {'new_customers': 12},
      'website_analytics': {'live_visitors': 18},
      'app_analytics': {'daily_active_users': 44},
      'booking_analytics': {'completed_orders': 6},
      'marketing_analytics': {'communication_reports': []},
      'finance_analytics': {'profit': 85000},
      'staff_analytics': {'attendance_today': 9},
      'ai_reports': {'business_health': 'healthy'},
    });

    expect(metricDouble(snapshot.owner, 'today_revenue'), 125000);
    expect(metricText(snapshot.sales, 'lead_conversion_percent'), '42.5');
    expect(metricText(snapshot.website, 'live_visitors'), '18');
    expect(metricText(snapshot.ai, 'business_health'), 'healthy');
  });
}
