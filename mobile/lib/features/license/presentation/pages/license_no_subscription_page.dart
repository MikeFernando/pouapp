import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/api_config.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/widgets/welcome_pou_brand.dart';
import '../../../customers/presentation/whatsapp_launch.dart';
import '../bloc/license_bloc.dart';
import '../bloc/license_event.dart';
import '../bloc/license_state.dart';

/// Account has no active subscription (usually logged in with the wrong email).
///
/// Visual reference: cream background, profile-card illustration, dual CTAs.
class LicenseNoSubscriptionPage extends StatelessWidget {
  const LicenseNoSubscriptionPage({super.key, this.paidEmail});

  /// Email that currently holds an active paid license, when known.
  final String? paidEmail;

  static const _bg = Color(0xFFF9F7F2);
  static const _title = Color(0xFF111111);
  static const _body = Color(0xFF6B6B6B);
  static const _badgeBg = Color(0xFFF5D2A8);
  static const _badgeFg = Color(0xFF9A5B1F);
  static const _chipBg = Color(0xFFEEE9E2);
  static const _button = Color(0xFF080808);
  static const _illustrationAsset = 'assets/images/profile-card.png';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final email = switch (auth) {
      Authenticated(:final user) => user.email,
      AuthLogoutInProgress(:final user) => user.email,
      _ => '—',
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _bg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final content = _NoSubscriptionContent(
                maxWidth: constraints.maxWidth,
                currentEmail: email,
                paidEmail: paidEmail,
                onSwitchEmail: () {
                  context.read<LicenseBloc>().add(const LicenseCacheCleared());
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                },
                onSubscribe: () => _openSupportWhatsApp(
                  context,
                  accountEmail: email,
                ),
                onVerify: () {
                  context.read<LicenseBloc>().add(
                    const LicenseCheckRequested(forceRemote: true),
                  );
                },
              );

              if (constraints.maxHeight < 700) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: content,
                  ),
                );
              }
              return content;
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openSupportWhatsApp(
    BuildContext context, {
    required String accountEmail,
  }) async {
    final digits = ApiConfig.supportWhatsAppDigits.replaceAll(
      RegExp(r'\D'),
      '',
    );
    if (digits.length < 10) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'WhatsApp de suporte não configurado. Defina SUPPORT_WHATSAPP_DIGITS.',
            ),
          ),
        );
      }
      return;
    }

    final message =
        'Olá! Quero assinar o PouApp com esta conta.\n\n'
        'E-mail da conta: $accountEmail\n\n'
        'Por favor, me envie o link de pagamento.';

    final ok = await launchCustomerWhatsApp(digits, message: message);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o WhatsApp.'),
        ),
      );
    }
  }
}

class _NoSubscriptionContent extends StatelessWidget {
  const _NoSubscriptionContent({
    required this.maxWidth,
    required this.currentEmail,
    required this.paidEmail,
    required this.onSwitchEmail,
    required this.onSubscribe,
    required this.onVerify,
  });

  final double maxWidth;
  final String currentEmail;
  final String? paidEmail;
  final VoidCallback onSwitchEmail;
  final VoidCallback onSubscribe;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final illustrationWidth = (maxWidth * 0.62).clamp(200.0, 280.0);
    final hint = (paidEmail != null && paidEmail!.trim().isNotEmpty)
        ? 'Já realizou o pagamento? Entre com o e-mail\nutilizado na assinatura.'
        : 'Já realizou o pagamento? Entre com o e-mail utilizado na assinatura.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 18),
          const _Brand(),
          const SizedBox(height: 18),
          SizedBox(
            width: illustrationWidth,
            child: Image.asset(
              LicenseNoSubscriptionPage._illustrationAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ),
          const SizedBox(height: 10),
          const _Badge(label: 'CONTA SEM ASSINATURA'),
          const SizedBox(height: 14),
          const Text(
            'Nenhuma assinatura\nnesta conta',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LicenseNoSubscriptionPage._title,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.08,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 16),
          _EmailChip(email: currentEmail),
          const SizedBox(height: 14),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: LicenseNoSubscriptionPage._body,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 28),
          _PrimaryButton(
            keyName: 'license_switch_email',
            label: 'Entrar com outro e-mail',
            icon: Icons.people_alt_outlined,
            onPressed: onSwitchEmail,
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            keyName: 'license_subscribe',
            label: 'Assinar via WhatsApp',
            onPressed: onSubscribe,
          ),
          const SizedBox(height: 18),
          BlocBuilder<LicenseBloc, LicenseState>(
            buildWhen: (previous, current) =>
                current is LicenseChecking || previous is LicenseChecking,
            builder: (context, state) {
              final checking = state is LicenseChecking;
              return _VerifyPaymentLink(
                checking: checking,
                onVerify: onVerify,
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 36,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: AssetImage(WelcomePouBrand.logoAsset),
              width: 30,
              height: 34,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              isAntiAlias: true,
            ),
            SizedBox(width: 8),
            Text(
              'PouApp',
              style: TextStyle(
                color: Colors.black,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: LicenseNoSubscriptionPage._badgeBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: LicenseNoSubscriptionPage._badgeFg,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1.1,
        ),
      ),
    );
  }
}

class _EmailChip extends StatelessWidget {
  const _EmailChip({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: LicenseNoSubscriptionPage._chipBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.mail_outline_rounded, size: 22, color: Color(0xFF333333)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Você está conectado como',
                  style: TextStyle(
                    color: LicenseNoSubscriptionPage._body,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LicenseNoSubscriptionPage._title,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String keyName;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: LicenseNoSubscriptionPage._button,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key(keyName),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.keyName,
    required this.label,
    required this.onPressed,
  });

  final String keyName;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 1.4),
        ),
        child: InkWell(
          key: Key(keyName),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifyPaymentLink extends StatelessWidget {
  const _VerifyPaymentLink({
    required this.checking,
    required this.onVerify,
  });

  final bool checking;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Colors.black,
          ),
        ),
      );
    }

    return Column(
      children: [
        const Text(
          'Já paguei com este e-mail',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LicenseNoSubscriptionPage._body,
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
            height: 1.35,
          ),
        ),
        TextButton(
          key: const Key('license_verify_payment'),
          onPressed: onVerify,
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
            textStyle: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
            minimumSize: const Size(44, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Verificar pagamento'),
        ),
      ],
    );
  }
}
