import 'package:flutter/material.dart';

enum LegalDocument { terms, privacy }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final isTerms = document == LegalDocument.terms;
    final title = isTerms ? 'Terms & Conditions' : 'Privacy Policy';
    final sections = isTerms ? _termsSections : _privacySections;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Last updated: August 24, 2026',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 24),
          for (final section in sections) ...[
            Text(section.$1, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(section.$2, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

const _termsSections = <(String, String)>[
  (
    'Using Clipzo',
    'Use Clipzo responsibly and in accordance with applicable laws. Do not post content that is harmful, unlawful, or infringes another person’s rights.',
  ),
  (
    'Your content',
    'You remain responsible for the videos and other content you share. By posting content, you allow Clipzo to host and display it so the service can work.',
  ),
  (
    'Account security',
    'Keep your account credentials secure and let us know if you believe your account has been accessed without permission.',
  ),
  (
    'Changes to these terms',
    'We may update these terms as Clipzo evolves. Continued use after an update means you accept the revised terms.',
  ),
];

const _privacySections = <(String, String)>[
  (
    'Information we collect',
    'We collect the details you provide for your account, such as your name, username, profile information, and the content you choose to upload.',
  ),
  (
    'How we use information',
    'We use your information to operate Clipzo, personalize your experience, keep the service secure, and communicate important account updates.',
  ),
  (
    'Sharing and visibility',
    'Your content’s visibility follows the privacy option you select. Public content may be visible to anyone using Clipzo.',
  ),
  (
    'Your choices',
    'You can update your profile details and control the visibility of new videos from within the app.',
  ),
];
