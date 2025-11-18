import 'package:cadence/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // This is needed to mock the platform channels used by shared_preferences
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService Tests', () {
    const serverUrlKey = 'cadence_server_url';

    test('getServerUrl should return null if no URL is saved', () async {
      // Arrange: Start with an empty storage
      SharedPreferences.setMockInitialValues({});

      // Act: Try to get the URL
      final url = await StorageService.getServerUrl();

      // Assert: Expect it to be null
      expect(url, isNull);
    });

    test('saveServerUrl should correctly persist the URL', () async {
      // Arrange: Start with an empty storage
      SharedPreferences.setMockInitialValues({});
      const testUrl = 'http://my-cadence-instance.local';

      // Act: Save the URL
      await StorageService.saveServerUrl(testUrl);

      // Assert: Verify directly that shared_preferences has the value
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(serverUrlKey), testUrl);
    });

    test('getServerUrl should retrieve a saved URL', () async {
      // Arrange: Start with a pre-filled storage
      const testUrl = 'http://another-cadence.local';
      SharedPreferences.setMockInitialValues({serverUrlKey: testUrl});

      // Act: Get the URL using the service
      final url = await StorageService.getServerUrl();

      // Assert: Expect it to be the one we saved
      expect(url, testUrl);
    });

    test('saveServerUrl should overwrite an existing URL', () async {
      // Arrange: Start with an old URL in storage
      const oldUrl = 'http://old.local';
      const newUrl = 'http://new.local';
      SharedPreferences.setMockInitialValues({serverUrlKey: oldUrl});

      // Act: Save a new URL
      await StorageService.saveServerUrl(newUrl);
      final url = await StorageService.getServerUrl();

      // Assert: Expect the new URL to be retrieved
      expect(url, newUrl);
    });
  });
}
