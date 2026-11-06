import 'package:flutter/material.dart';

import '../../../assistant/presentation/widgets/voice_mic.dart';
import '../widgets/login_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      resizeToAvoidBottomInset: true,
      floatingActionButton: VoiceAssistantButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(child: LoginForm()),
    );
  }
}
