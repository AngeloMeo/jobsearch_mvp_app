import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jobsearch_mvp_app/config/api_config.dart';
import 'package:jobsearch_mvp_app/main.dart';
import 'package:jobsearch_mvp_app/services/api_service.dart';

void main() {
  testWidgets('JobBoardScreen renders app bar and login button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ApiService.instance.init();

    await tester.pumpWidget(const JobSearchMvpApp());
    await tester.pump();

    expect(find.text('Bacheca Lavoro'), findsOneWidget);
    expect(find.text('Area Aziende / Login'), findsOneWidget);
    expect(find.byTooltip('Impostazioni IP'), findsOneWidget);
  });

  test('ApiConfig normalizes IP and URL correctly', () {
    expect(
      ApiConfig.normalizeServerUrl('192.168.1.42'),
      'http://192.168.1.42:8080',
    );
    expect(
      ApiConfig.normalizeServerUrl('http://10.0.2.2:8080/'),
      'http://10.0.2.2:8080',
    );
  });
}
