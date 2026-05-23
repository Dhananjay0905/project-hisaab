import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

class LegalSection {
  final String iconName;
  final String title;
  final String content;

  LegalSection({
    required this.iconName,
    required this.title,
    required this.content,
  });

  IconData get icon {
    switch (iconName) {
      case 'info_outline_rounded': return Icons.info_outline_rounded;
      case 'folder_outlined': return Icons.folder_outlined;
      case 'lock_outline_rounded': return Icons.lock_outline_rounded;
      case 'pie_chart_outline_rounded': return Icons.pie_chart_outline_rounded;
      case 'cloud_outlined': return Icons.cloud_outlined;
      case 'access_time_rounded': return Icons.access_time_rounded;
      case 'delete_outline_rounded': return Icons.delete_outline_rounded;
      case 'cookie_outlined': return Icons.cookie_outlined;
      case 'gavel_rounded': return Icons.gavel_rounded;
      case 'shield_outlined': return Icons.shield_outlined;
      case 'child_care_rounded': return Icons.child_care_rounded;
      case 'security_rounded': return Icons.security_rounded;
      case 'edit_note_rounded': return Icons.edit_note_rounded;
      case 'mail_outline_rounded': return Icons.mail_outline_rounded;
      case 'handshake_outlined': return Icons.handshake_outlined;
      case 'description_outlined': return Icons.description_outlined;
      case 'person_outline_rounded': return Icons.person_outline_rounded;
      case 'account_circle_outlined': return Icons.account_circle_outlined;
      case 'check_circle_outline_rounded': return Icons.check_circle_outline_rounded;
      case 'data_usage_rounded': return Icons.data_usage_rounded;
      case 'copyright_outlined': return Icons.copyright_outlined;
      case 'cloud_done_outlined': return Icons.cloud_done_outlined;
      case 'warning_amber_rounded': return Icons.warning_amber_rounded;
      case 'balance_rounded': return Icons.balance_rounded;
      case 'cut_outlined': return Icons.cut_outlined;
      case 'article_outlined': return Icons.article_outlined;
      case 'phone_android': return Icons.phone_android_rounded;
      case 'share_outlined': return Icons.share_outlined;
      default: return Icons.description_outlined;
    }
  }

  factory LegalSection.fromJson(Map<String, dynamic> json) {
    return LegalSection(
      iconName: json['icon'] as String? ?? 'description_outlined',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}

class LegalData {
  final String privacyPolicyLastUpdated;
  final List<LegalSection> privacyPolicySections;
  final String termsOfServiceLastUpdated;
  final List<LegalSection> termsOfServiceSections;

  LegalData({
    required this.privacyPolicyLastUpdated,
    required this.privacyPolicySections,
    required this.termsOfServiceLastUpdated,
    required this.termsOfServiceSections,
  });

  factory LegalData.fromJson(Map<String, dynamic> json) {
    final privacy = json['privacyPolicy'] as Map<String, dynamic>? ?? {};
    final terms = json['termsOfService'] as Map<String, dynamic>? ?? {};

    final privacySectionsJson = privacy['sections'] as List? ?? [];
    final termsSectionsJson = terms['sections'] as List? ?? [];

    return LegalData(
      privacyPolicyLastUpdated: privacy['lastUpdated'] as String? ?? 'May 2025',
      privacyPolicySections: privacySectionsJson
          .map((s) => LegalSection.fromJson(s as Map<String, dynamic>))
          .toList(),
      termsOfServiceLastUpdated: terms['lastUpdated'] as String? ?? 'May 2025',
      termsOfServiceSections: termsSectionsJson
          .map((s) => LegalSection.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

final legalProvider = FutureProvider<LegalData>((ref) async {
  final response = await ApiClient.instance.get(ApiEndpoints.legal);
  return LegalData.fromJson(response.data as Map<String, dynamic>);
});
