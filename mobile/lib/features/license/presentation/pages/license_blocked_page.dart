import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/widgets/welcome_pou_brand.dart';
import '../../domain/entities/license_status.dart';
import '../bloc/license_bloc.dart';
import '../bloc/license_event.dart';
import '../bloc/license_state.dart';

/// Server suspended when there is no active paid license in the system.
class LicenseBlockedPage extends StatelessWidget {
  const LicenseBlockedPage({
    super.key,
    this.message,
    this.showRetryAsPrimary = false,
    this.reason,
    this.paidEmail,
  });

  final String? message;
  final bool showRetryAsPrimary;
  final LicenseBlockReason? reason;
  final String? paidEmail;

  static const _bg = Color(0xFFFAF7F4);
  static const _title = Color(0xFF111111);
  static const _body = Color(0xFF626262);
  static const _badgeBg = Color(0xFFFFD58C);
  static const _badgeFg = Color(0xFF915319);
  static const _cardBg = Color(0xFFF0EBE5);
  static const _cardTitle = Color(0xFF171717);
  static const _cardBody = Color(0xFF6B6B6B);
  static const _button = Color(0xFF080808);
  static const _logout = Color(0xFF777777);
  static const _illustrationAsset = 'assets/images/server-off.png';

  @override
  Widget build(BuildContext context) {
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
              final bodyCopy =
                  showRetryAsPrimary &&
                      message != null &&
                      message!.trim().isNotEmpty
                  ? message!
                  : 'Seu acesso está suspenso até a\nconfirmação do pagamento.';

              final content = _BlockedContent(
                maxWidth: constraints.maxWidth,
                bodyCopy: bodyCopy,
                onRetry: () {
                  context.read<LicenseBloc>().add(
                    const LicenseCheckRequested(forceRemote: true),
                  );
                },
                onLogout: () {
                  context.read<LicenseBloc>().add(const LicenseCacheCleared());
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                },
              );

              final needsScroll = constraints.maxHeight < 640;
              if (needsScroll) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewPaddingOf(context).bottom > 0
                        ? 0
                        : 8,
                  ),
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
}

class _BlockedContent extends StatelessWidget {
  const _BlockedContent({
    required this.maxWidth,
    required this.bodyCopy,
    required this.onRetry,
    required this.onLogout,
  });

  final double maxWidth;
  final String bodyCopy;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final illustrationWidth = (maxWidth * 0.72).clamp(220.0, 320.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const _BlockedBrand(),
          const SizedBox(height: 8),
          SizedBox(
            width: illustrationWidth,
            child: Image.asset(
              LicenseBlockedPage._illustrationAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ),
          const SizedBox(height: 6),
          const _AccessPausedBadge(label: 'ACESSO PAUSADO'),
          const SizedBox(height: 16),
          const Text(
            'Serviço\nindisponível',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LicenseBlockedPage._title,
              fontSize: 39,
              fontWeight: FontWeight.w800,
              height: 1.05,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              bodyCopy,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LicenseBlockedPage._body,
                fontSize: 17.5,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: _PaymentInfoCard(),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _RetryButton(onPressed: onRetry),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 44,
            child: TextButton(
              key: const Key('license_logout'),
              onPressed: onLogout,
              style: TextButton.styleFrom(
                foregroundColor: LicenseBlockedPage._logout,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Sair da conta'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _BlockedBrand extends StatelessWidget {
  const _BlockedBrand();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 40,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image(
              image: AssetImage(WelcomePouBrand.logoAsset),
              width: 34,
              height: 38,
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
                fontSize: 29,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessPausedBadge extends StatelessWidget {
  const _AccessPausedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: LicenseBlockedPage._badgeBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: LicenseBlockedPage._badgeFg,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          height: 1.1,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _PaymentInfoCard extends StatelessWidget {
  const _PaymentInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: LicenseBlockedPage._cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 31,
            color: Color(0xFF4A4A4A),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Já realizou o pagamento?',
                  style: TextStyle(
                    color: LicenseBlockedPage._cardTitle,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Toque abaixo para verificar a liberação.',
                  style: TextStyle(
                    color: LicenseBlockedPage._cardBody,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    height: 1.25,
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

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LicenseBloc, LicenseState>(
      buildWhen: (previous, current) =>
          current is LicenseChecking || previous is LicenseChecking,
      builder: (context, state) {
        final checking = state is LicenseChecking;
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: Material(
            color: LicenseBlockedPage._button,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              key: const Key('license_retry'),
              onTap: checking ? null : onPressed,
              borderRadius: BorderRadius.circular(15),
              child: Center(
                child: checking
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 23,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Tentar novamente',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
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
      },
    );
  }
}
