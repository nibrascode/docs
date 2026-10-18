import 'package:flutter/material.dart';

import '../legal/legal_screen.dart';
import '../legal/legal_texts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const LegalScreen(doc: LegalTexts.privacy, icon: Icons.shield_rounded);
}
