import 'package:flutter/material.dart';

import '../widgets/login_form.dart';
import '../widgets/register_form.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  var _creatingAccount = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: _creatingAccount
            ? RegisterForm(
                onSignIn: () => setState(() => _creatingAccount = false),
              )
            : LoginForm(
                onCreateAccount: () => setState(() => _creatingAccount = true),
              ),
      ),
    );
  }
}
