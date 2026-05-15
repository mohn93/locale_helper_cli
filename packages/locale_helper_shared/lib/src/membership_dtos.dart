// packages/locale_helper_shared/lib/src/membership_dtos.dart
import 'package:meta/meta.dart';

@immutable
class MemberDto {
  final String userId;
  final String email;
  final String? displayName;
  final String role; // owner | reviewer | commenter
  final DateTime joinedAt;
  final String? claimedViaInviteId;
  final String? claimedViaInviteLabel;
  const MemberDto({
    required this.userId,
    required this.email,
    this.displayName,
    required this.role,
    required this.joinedAt,
    this.claimedViaInviteId,
    this.claimedViaInviteLabel,
  });

  /// Friendly display name: explicit displayName if present, falling back to
  /// the local part of the email so we never show "owner@x.com" as the
  /// primary title.
  String get friendlyName {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    final at = email.indexOf('@');
    return at <= 0 ? email : email.substring(0, at);
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        if (displayName != null) 'displayName': displayName,
        'role': role,
        'joinedAt': joinedAt.toUtc().toIso8601String(),
        if (claimedViaInviteId != null) 'claimedViaInviteId': claimedViaInviteId,
        if (claimedViaInviteLabel != null)
          'claimedViaInviteLabel': claimedViaInviteLabel,
      };

  factory MemberDto.fromJson(Map<String, dynamic> json) => MemberDto(
        userId: json['userId'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
        role: json['role'] as String,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        claimedViaInviteId: json['claimedViaInviteId'] as String?,
        claimedViaInviteLabel: json['claimedViaInviteLabel'] as String?,
      );
}

@immutable
class InvitationDto {
  final String id;
  final String role; // reviewer | commenter
  final String? label;
  final String? inviteeEmail;
  final int? maxUses;
  final int useCount;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime? revokedAt;
  final String? inviteUrl; // only present on create response

  const InvitationDto({
    required this.id,
    required this.role,
    this.label,
    this.inviteeEmail,
    this.maxUses,
    this.useCount = 0,
    this.expiresAt,
    required this.createdAt,
    required this.revokedAt,
    this.inviteUrl,
  });

  bool get isExhausted => maxUses != null && useCount >= maxUses!;
  bool get isExpired =>
      expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt!.toUtc());
  bool get isActive => revokedAt == null && !isExhausted && !isExpired;

  /// Reason a non-active invitation is unusable, or null when active.
  String? get inactiveReason {
    if (revokedAt != null) return 'revoked';
    if (isExhausted) return 'exhausted';
    if (isExpired) return 'expired';
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        if (label != null) 'label': label,
        if (inviteeEmail != null) 'inviteeEmail': inviteeEmail,
        if (maxUses != null) 'maxUses': maxUses,
        'useCount': useCount,
        if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (revokedAt != null) 'revokedAt': revokedAt!.toUtc().toIso8601String(),
        if (inviteUrl != null) 'inviteUrl': inviteUrl,
      };

  factory InvitationDto.fromJson(Map<String, dynamic> json) => InvitationDto(
        id: json['id'] as String,
        role: json['role'] as String,
        label: json['label'] as String?,
        inviteeEmail: json['inviteeEmail'] as String?,
        maxUses: json['maxUses'] as int?,
        useCount: (json['useCount'] as int?) ?? 0,
        expiresAt: json['expiresAt'] is String
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        revokedAt: json['revokedAt'] is String
            ? DateTime.parse(json['revokedAt'] as String)
            : null,
        inviteUrl: json['inviteUrl'] as String?,
      );
}
