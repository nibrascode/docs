import 'package:flutter/material.dart';

import '../legal/legal_screen.dart';
import '../legal/legal_texts.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const LegalScreen(doc: LegalTexts.terms, icon: Icons.description_rounded);
}
