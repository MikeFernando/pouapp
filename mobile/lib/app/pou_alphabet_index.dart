import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const pouAlphabetLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// Large center letter while scrubbing / when a letter filter has no rows.
class PouAlphabetLetterPreview extends StatelessWidget {
  const PouAlphabetLetterPreview({
    super.key,
    required this.letter,
    this.faint = false,
  });

  final String letter;
  final bool faint;

  @override
  Widget build(BuildContext context) {
    return Text(
      letter,
      style: TextStyle(
        fontSize: 96,
        fontWeight: FontWeight.w800,
        height: 1,
        color: Color(faint ? 0xFFC5CAC7 : 0xFFB0B5B2),
      ),
    );
  }
}

/// First letter of [name] for A–Z filtering. Accented letters map to A–Z.
String pouAlphabetInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '#';
  final raw = trimmed[0].toUpperCase();
  const from = 'ÁÀÂÃÄÅÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const to = 'AAAAAAEEEEIIIIOOOOOUUUUCN';
  final index = from.indexOf(raw);
  final letter = index >= 0 ? to[index] : raw;
  if (letter.compareTo('A') < 0 || letter.compareTo('Z') > 0) return '#';
  return letter;
}

class PouAlphabetIndex extends StatefulWidget {
  const PouAlphabetIndex({
    super.key,
    required this.activeLetter,
    required this.scrubbing,
    required this.onDragLetter,
    required this.onTapLetter,
    required this.onDragEnd,
    this.keyPrefix = 'catalog',
  });

  final String? activeLetter;
  final bool scrubbing;
  /// Letter under the finger, or `null` when dragged above A / below Z (clear filter).
  final ValueChanged<String?> onDragLetter;
  final ValueChanged<String> onTapLetter;
  final VoidCallback onDragEnd;
  final String keyPrefix;

  @override
  State<PouAlphabetIndex> createState() => _PouAlphabetIndexState();
}

class _PouAlphabetIndexState extends State<PouAlphabetIndex> {
  var _moved = false;
  String? _pressed;
  String? _hapticLetter;
  double? _focusY;

  @override
  void didUpdateWidget(covariant PouAlphabetIndex oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.scrubbing && _focusY != null && !_moved) {
      _focusY = null;
    }
  }

  void _tickLetter(String? letter) {
    if (letter == _hapticLetter) return;
    _hapticLetter = letter;
    if (letter != null) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        if (height <= 0) return const SizedBox.shrink();
        final focusY = _focusY ?? _focusForLetter(widget.activeLetter, height);
        final waving = focusY != null;
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            _PouAlphabetDragRecognizer:
                GestureRecognizerFactoryWithHandlers<_PouAlphabetDragRecognizer>(
                  _PouAlphabetDragRecognizer.new,
                  (_PouAlphabetDragRecognizer instance) {
                    instance
                      ..onDown = (details) {
                        _moved = false;
                        _hapticLetter = null;
                        _pressed = _letterAt(details.localPosition.dy, height);
                        setState(() => _focusY = details.localPosition.dy);
                      }
                      ..onStart = (details) {
                        final letter = _letterAt(
                          details.localPosition.dy,
                          height,
                        );
                        _moved = true;
                        _tickLetter(_pressed ?? letter);
                        widget.onDragLetter(_pressed ?? letter);
                        setState(
                          () => _focusY = letter == null
                              ? null
                              : details.localPosition.dy,
                        );
                      }
                      ..onUpdate = (details) {
                        final letter = _letterAt(
                          details.localPosition.dy,
                          height,
                        );
                        if (!_moved) {
                          _moved = true;
                          _tickLetter(_pressed ?? letter);
                          widget.onDragLetter(_pressed ?? letter);
                        }
                        _tickLetter(letter);
                        widget.onDragLetter(letter);
                        setState(
                          () => _focusY = letter == null
                              ? null
                              : details.localPosition.dy,
                        );
                      }
                      ..onEnd = (_) {
                        _finishDrag();
                      }
                      ..onCancel = _finishDrag;
                  },
                ),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  TapGestureRecognizer.new,
                  (TapGestureRecognizer instance) {
                    instance.onTapUp = (details) {
                      final letter = _letterAt(
                        details.localPosition.dy,
                        height,
                      );
                      if (letter == null) return;
                      HapticFeedback.selectionClick();
                      widget.onTapLetter(letter);
                    };
                  },
                ),
          },
          child: SizedBox(
            width: waving ? 48 : 26,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < pouAlphabetLetters.length; i++)
                  _PouAlphabetWaveLetter(
                    key: ValueKey(pouAlphabetLetters[i]),
                    letter: pouAlphabetLetters[i],
                    letterKey: Key(
                      '${widget.keyPrefix}_letter_${pouAlphabetLetters[i]}',
                    ),
                    index: i,
                    count: pouAlphabetLetters.length,
                    height: height,
                    focusY: focusY,
                    active: widget.activeLetter == pouAlphabetLetters[i],
                    scrubbing: widget.scrubbing || _focusY != null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _finishDrag() {
    if (_moved) widget.onDragEnd();
    _pressed = null;
    _hapticLetter = null;
    _moved = false;
    if (_focusY != null) setState(() => _focusY = null);
  }

  /// Returns the letter at [dy], or `null` when above A / below Z.
  String? _letterAt(double dy, double height) {
    if (dy < 0 || dy >= height) return null;
    final index = (dy / height * pouAlphabetLetters.length).floor().clamp(
      0,
      pouAlphabetLetters.length - 1,
    );
    return pouAlphabetLetters[index];
  }

  double? _focusForLetter(String? letter, double height) {
    if (letter == null) return null;
    final index = pouAlphabetLetters.indexOf(letter);
    if (index < 0) return null;
    return (index + 0.5) / pouAlphabetLetters.length * height;
  }
}

/// Wins the gesture arena so a parent sheet does not drag-dismiss.
class _PouAlphabetDragRecognizer extends VerticalDragGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}

class _PouAlphabetWaveLetter extends StatelessWidget {
  const _PouAlphabetWaveLetter({
    super.key,
    required this.letter,
    required this.letterKey,
    required this.index,
    required this.count,
    required this.height,
    required this.focusY,
    required this.active,
    required this.scrubbing,
  });

  final String letter;
  final Key letterKey;
  final int index;
  final int count;
  final double height;
  final double? focusY;
  final bool active;
  final bool scrubbing;

  @override
  Widget build(BuildContext context) {
    final slot = height / count;
    final centerY = (index + 0.5) * slot;
    final wave = _wave(centerY, slot);
    final shift = scrubbing || active ? -16 * wave : 0.0;
    final scale = 1 + 1.1 * wave;
    return Positioned(
      top: centerY - slot / 2,
      right: 2,
      height: slot,
      child: Transform.translate(
        offset: Offset(shift, 0),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.centerRight,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              letter,
              key: letterKey,
              style: TextStyle(
                fontSize: 13,
                height: 1,
                fontWeight: wave > 0.75 ? FontWeight.w900 : FontWeight.w700,
                color: Color.lerp(
                  const Color(0xFF4B5563),
                  const Color(0xFF0E0D0F),
                  wave.clamp(0.0, 1.0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _wave(double centerY, double slot) {
    final focus = focusY;
    if (focus == null) return active ? 0.28 : 0.0;
    final distSlots = (centerY - focus).abs() / slot;
    if (distSlots >= 3) return 0.0;
    final t = 1 - distSlots / 3;
    return t * t;
  }
}
