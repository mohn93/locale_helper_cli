// packages/locale_helper_shared/lib/src/dtos.dart
import 'package:meta/meta.dart';
import 'bundle.dart';

@immutable
class PublishRequest {
  final Bundle bundle;
  final String projectName;
  final String? projectId;
  const PublishRequest({
    required this.bundle,
    required this.projectName,
    this.projectId,
  });

  Map<String, dynamic> toJson() => {
    'bundle': bundle.toJson(),
    'projectName': projectName,
    if (projectId != null) 'projectId': projectId,
  };

  factory PublishRequest.fromJson(Map<String, dynamic> json) => PublishRequest(
    bundle: Bundle.fromJson((json['bundle'] as Map).cast<String, dynamic>()),
    projectName: json['projectName'] as String,
    projectId: json['projectId'] as String?,
  );
}

@immutable
class PublishResponse {
  final String projectId;
  final String reviewUrl;
  final String settingsUrl;
  const PublishResponse({
    required this.projectId,
    required this.reviewUrl,
    required this.settingsUrl,
  });

  Map<String, dynamic> toJson() => {
    'projectId': projectId,
    'reviewUrl': reviewUrl,
    'settingsUrl': settingsUrl,
  };

  factory PublishResponse.fromJson(Map<String, dynamic> json) => PublishResponse(
    projectId: json['projectId'] as String,
    reviewUrl: json['reviewUrl'] as String,
    settingsUrl: json['settingsUrl'] as String,
  );
}

@immutable
class SubmitEditRequest {
  final String key;
  final String? locale; // null defaults to project source locale on the server
  final String proposedValue;
  final String? comment;
  final String? reviewerAlias;
  const SubmitEditRequest({
    required this.key,
    this.locale,
    required this.proposedValue,
    this.comment,
    this.reviewerAlias,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        if (locale != null) 'locale': locale,
        'proposedValue': proposedValue,
        if (comment != null) 'comment': comment,
        if (reviewerAlias != null) 'reviewerAlias': reviewerAlias,
      };

  factory SubmitEditRequest.fromJson(Map<String, dynamic> json) =>
      SubmitEditRequest(
        key: json['key'] as String,
        locale: json['locale'] as String?,
        proposedValue: json['proposedValue'] as String,
        comment: json['comment'] as String?,
        reviewerAlias: json['reviewerAlias'] as String?,
      );
}
