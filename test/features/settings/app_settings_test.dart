import 'package:doon_walkers/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings.fromRows', () {
    test('maps key/value rows onto named getters', () {
      final settings = AppSettings.fromRows([
        {'key': 'org_name', 'value': 'Doon Walkers'},
        {'key': 'org_tagline', 'value': 'Explore the Himalayas with us'},
        {'key': 'community_story', 'value': 'Founded in 2020...'},
        {'key': 'instagram_url', 'value': 'https://instagram.com/doonwalkers'},
      ]);

      expect(settings.orgName, 'Doon Walkers');
      expect(settings.orgTagline, 'Explore the Himalayas with us');
      expect(settings.communityStory, 'Founded in 2020...');
      expect(settings.instagramUrl, 'https://instagram.com/doonwalkers');
    });

    test('missing keys fall back to empty string, not a crash', () {
      final settings = AppSettings.fromRows([]);

      expect(settings.orgName, '');
      expect(settings.founderMessage, '');
      expect(settings.whatsappUrl, '');
    });

    test('rows with a null key are skipped instead of throwing', () {
      final settings = AppSettings.fromRows([
        {'key': null, 'value': 'orphaned'},
        {'key': 'vision', 'value': 'Trails for everyone.'},
      ]);

      expect(settings.vision, 'Trails for everyone.');
    });

    test('a row with a null value maps to empty string, not "null"', () {
      final settings = AppSettings.fromRows([
        {'key': 'mission', 'value': null},
      ]);

      expect(settings.mission, '');
    });

    test('AppSettings.empty has every getter default to empty string', () {
      expect(AppSettings.empty.orgName, '');
      expect(AppSettings.empty.communityRules, '');
    });
  });
}
