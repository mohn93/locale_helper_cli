// packages/locale_helper_shared/test/dtos_test.dart
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:test/test.dart';

void main() {
  test('PublishRequest round-trips', () {
    final bundle = Bundle(
      projectId: '',
      sourceLocale: 'en',
      locales: const ['en'],
      strings: const [],
      createdAt: DateTime.utc(2026, 5, 12),
    );
    final req = PublishRequest(bundle: bundle, projectName: 'Demo');
    final decoded = PublishRequest.fromJson(req.toJson());
    expect(decoded.projectName, 'Demo');
    expect(decoded.bundle.sourceLocale, 'en');
  });

  test('SubmitEditRequest round-trips', () {
    final req = SubmitEditRequest(
      key: 'hello',
      proposedValue: 'Hi',
      comment: 'shorter',
      reviewerAlias: 'amir',
    );
    final decoded = SubmitEditRequest.fromJson(req.toJson());
    expect(decoded.proposedValue, 'Hi');
    expect(decoded.reviewerAlias, 'amir');
  });

  test('PublishRequest round-trips with optional projectId', () {
    final bundle = Bundle(
      projectId: '',
      sourceLocale: 'en',
      locales: const ['en'],
      strings: const [],
      createdAt: DateTime.utc(2026, 5, 13),
    );
    final req = PublishRequest(
      bundle: bundle,
      projectName: 'Demo',
      projectId: 'existing-123',
    );
    final json = req.toJson();
    expect(json['projectId'], 'existing-123');
    final decoded = PublishRequest.fromJson(json);
    expect(decoded.projectId, 'existing-123');
    expect(decoded.projectName, 'Demo');
  });

  test('PublishRequest omits projectId when null', () {
    final bundle = Bundle(
      projectId: '',
      sourceLocale: 'en',
      locales: const ['en'],
      strings: const [],
      createdAt: DateTime.utc(2026, 5, 13),
    );
    final req = PublishRequest(bundle: bundle, projectName: 'Demo');
    final json = req.toJson();
    expect(json.containsKey('projectId'), isFalse);
    final decoded = PublishRequest.fromJson(json);
    expect(decoded.projectId, isNull);
  });

  test('PublishResponse round-trips', () {
    final resp = PublishResponse(
      projectId: 'p1',
      reviewUrl: 'https://x/review/p1',
      settingsUrl: 'https://x/settings/p1',
    );
    final decoded = PublishResponse.fromJson(resp.toJson());
    expect(decoded.projectId, 'p1');
    expect(decoded.reviewUrl, 'https://x/review/p1');
    expect(decoded.settingsUrl, 'https://x/settings/p1');
  });
}
