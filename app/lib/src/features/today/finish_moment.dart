import 'dart:math';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';

/// The quiet serif line under a finished day: "That's today. / Go in peace.", or "Day complete. / Nothing lost." for a
/// past date. With [animate] it rises 8px and fades in after a short wait (moment A); otherwise it is simply there.
/// Turning [animate] off mid-way lets the rise finish.
class FinishLine extends StatelessWidget {
  const FinishLine({super.key, required this.past, required this.animate});

  final bool past;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tones = context.tones;
    final serif = serifQuote(context);
    final total = Motion.finishDelay + Motion.finishRise;
    final rise = Interval(Motion.finishDelay.inMicroseconds / total.inMicroseconds, 1, curve: Curves.easeOutCubic);
    return MergeSemantics(
      // Only the first build's tween counts: the end never changes, so a running rise is never cut short.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: animate && !reduceMotion(context) ? 0 : 1, end: 1),
        duration: total,
        builder: (context, t, child) {
          final v = rise.transform(t);
          return Opacity(
            opacity: v,
            child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(past ? l.finishPastTitle : l.finishTodayTitle, style: serif),
            Text(past ? l.finishPastLine : l.finishTodayLine, style: serif.copyWith(color: tones.muted)),
          ],
        ),
      ),
    );
  }
}

/// [text] setting in word by word: each word fades and rises a little, [Motion.staggerStep] after the one before.
/// With Reduce Motion it is one plain [Text].
class SettleWords extends StatefulWidget {
  const SettleWords({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<SettleWords> createState() => _SettleWordsState();
}

class _SettleWordsState extends State<SettleWords> with SingleTickerProviderStateMixin {
  late final List<String> _words = widget.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.staggerStep * max(0, _words.length - 1) + Motion.medium,
  );
  late final List<CurvedAnimation> _curves = [
    for (var i = 0; i < _words.length; i++)
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          (Motion.staggerStep * i).inMicroseconds / _controller.duration!.inMicroseconds,
          (Motion.staggerStep * i + Motion.medium).inMicroseconds / _controller.duration!.inMicroseconds,
          curve: Curves.easeOutCubic,
        ),
      ),
  ];
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    for (final c in _curves) {
      c.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return Text(widget.text, style: widget.style);
    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: Wrap(
          children: [
            for (var i = 0; i < _words.length; i++) _word(i, _curves[i]),
          ],
        ),
      ),
    );
  }

  Widget _word(int i, Animation<double> curve) => FadeTransition(
    key: ValueKey('quote-word-$i'),
    opacity: curve,
    child: AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Transform.translate(offset: Offset(0, 6 * (1 - curve.value)), child: child),
      child: Text(i == _words.length - 1 ? _words[i] : '${_words[i]} ', style: widget.style),
    ),
  );
}
