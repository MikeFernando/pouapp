import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../../app/rounded_navigation_scaffold.dart';
import '../../../../injection_container.dart';
import '../../../customers/domain/usecases/customer_use_cases.dart';
import '../../../customers/presentation/customer_routes.dart';
import '../bloc/voice_assistant_bloc.dart';
import '../voice_attendance.dart';
import 'voice_assistant_sheet.dart';

/// Keeps the microphone above every page and above the voice panel.
class VoiceMicObserver extends NavigatorObserver {
  VoiceMicObserver(this.pageName);

  final ValueNotifier<String?> pageName;
  OverlayEntry? _entry;
  var _inserted = false;
  var _pending = false;
  var _disposed = false;

  void dispose() {
    _disposed = true;
    _remove();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PopupRoute) pageName.value = route.settings.name;
    _place();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PopupRoute) pageName.value = previousRoute?.settings.name;
    _place();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PopupRoute) pageName.value = previousRoute?.settings.name;
    _place();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is! PopupRoute) pageName.value = newRoute?.settings.name;
    _place();
  }

  void _place() {
    if (_disposed || _pending) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _insert());
  }

  void _insert({int attempt = 0}) {
    _pending = false;
    if (_disposed) return;
    final overlay = navigator?.overlay;
    if (overlay == null) {
      if (attempt >= 5) return;
      _pending = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _insert(attempt: attempt + 1),
      );
      return;
    }
    _remove();
    _entry = OverlayEntry(
      builder: (context) => VoiceMicLayer(pageName: pageName),
    );
    overlay.insert(_entry!);
    _inserted = true;
  }

  void _remove() {
    if (!_inserted) return;
    _entry?.remove();
    _entry = null;
    _inserted = false;
  }
}

class VoiceMicLayer extends StatelessWidget {
  const VoiceMicLayer({super.key, required this.pageName});

  final ValueNotifier<String?> pageName;

  @override
  Widget build(BuildContext context) {
    final onHome =
        pageName.value == null || pageName.value == CustomerRoutes.home;
    final bottom =
        16 +
        (onHome ? RoundedBottomNavigationBar.itemExtent : 0) +
        MediaQuery.paddingOf(context).bottom +
        MediaQuery.viewInsetsOf(context).bottom;
    return Positioned(
      right: 16,
      bottom: bottom,
      child: VoiceAssistantButton(pageName: pageName),
    );
  }
}

/// Lifts a screen's own action button so it stays above the microphone.
class AboveVoiceMicLocation extends FloatingActionButtonLocation {
  const AboveVoiceMicLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final base = FloatingActionButtonLocation.endFloat.getOffset(
      scaffoldGeometry,
    );
    return Offset(base.dx, base.dy - 72);
  }
}

class VoiceAssistantButton extends StatelessWidget {
  const VoiceAssistantButton({super.key, this.pageName});

  /// When set, a note saved by voice opens on this navigator.
  final ValueNotifier<String?>? pageName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Assistente de voz',
      child: FloatingActionButton(
        key: const Key('voice_assistant_button'),
        heroTag: null,
        tooltip: 'Assistente de voz',
        backgroundColor: pouInk,
        foregroundColor: Colors.white,
        onPressed: () {
          final session = VoiceSession.current;
          if (session != null && !session.isClosed) {
            session.add(const VoiceRetryRequested());
            return;
          }
          _open(context);
        },
        child: const Icon(Icons.mic),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final visit = VoiceAttendance.current;
    final id = visit?.customerId ?? customerIdFromVoiceRoute(pageName?.value);
    var label = visit?.label.trim();
    if ((label == null || label.isEmpty) &&
        id != null &&
        sl.isRegistered<GetCustomerById>()) {
      final result = await sl<GetCustomerById>()(id);
      if (!context.mounted) return;
      label = result.fold((_) => null, (customer) => customer.name);
    }
    if (!context.mounted) return;
    final routes = pageName;
    await openVoiceAssistant(
      context,
      customerId: id,
      customerLabel: label,
      onOpenNote: routes == null
          ? (savedId) {
              final open = VoiceAttendance.current;
              if (open != null && open.customerId == savedId) open.onChanged();
            }
          : (savedId) {
              final open = VoiceAttendance.current;
              if (open != null && open.customerId == savedId) {
                open.onChanged();
                return;
              }
              if (!context.mounted) return;
              final navigator = Navigator.of(context);
              final target = CustomerRoutes.details(savedId);
              if (routes.value == target) {
                navigator.pushReplacementNamed(target);
                return;
              }
              navigator.pushNamed(target);
            },
    );
  }
}

String? customerIdFromVoiceRoute(String? name) {
  if (name == null) return null;
  final match = RegExp(r'^/customers/([^/]+)$').firstMatch(name);
  if (match == null) return null;
  final id = Uri.decodeComponent(match.group(1)!);
  if (id == 'new') return null;
  return id;
}
