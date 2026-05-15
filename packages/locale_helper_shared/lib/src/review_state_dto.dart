// packages/locale_helper_shared/lib/src/review_state_dto.dart
import 'package:meta/meta.dart';

@immutable
class ReviewStateDto {
  final bool reviewed;
  final bool changedSinceReview;
  const ReviewStateDto({required this.reviewed, required this.changedSinceReview});

  Map<String, dynamic> toJson() => {
    'reviewed': reviewed,
    'changedSinceReview': changedSinceReview,
  };

  factory ReviewStateDto.fromJson(Map<String, dynamic> json) => ReviewStateDto(
    reviewed: json['reviewed'] as bool,
    changedSinceReview: json['changedSinceReview'] as bool,
  );
}
