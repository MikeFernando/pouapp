import 'package:flutter/material.dart';

class SessionLoadingView extends StatelessWidget {
  const SessionLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(semanticsLabel: 'Verificando sessão'),
      ),
    );
  }
}
