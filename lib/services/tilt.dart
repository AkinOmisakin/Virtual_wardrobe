import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Normalised device tilt in the range [-1, 1] per axis, read off the
/// accelerometer's view of gravity.
///
/// `dx` grows as the right edge of the phone drops and `dy` as the top edge
/// drops, so a layer translated by `tilt * depth` leans the way the phone does.
///
/// Neutral is deliberately *not* "flat on a table" — it is a slow-moving
/// average of how the phone has actually been held over the last few seconds.
/// Anyone reading in bed holds their phone at a steep angle, and against a
/// fixed neutral they would sit pinned at full deflection with the effect
/// looking broken. A quick tilt outruns the average and shows up; a new resting
/// angle gets absorbed and re-centres.
class TiltNotifier extends ValueNotifier<Offset> {
  TiltNotifier({required TickerProvider vsync}) : super(Offset.zero) {
    _ticker = vsync.createTicker(_onFrame);
    _subscribe();
  }

  /// Deviation from neutral that counts as full deflection, in m/s².
  /// 3.0 is roughly 18°, so a wrist flick reaches the end stop.
  static const _fullScaleTilt = 3.0;

  /// Per-sample weight for the noise filter on the raw reading.
  static const _readingWeight = 0.2;

  /// Per-sample weight for the drifting neutral point described above. Much
  /// smaller than [_readingWeight] — that gap is what separates "a deliberate
  /// tilt" from "this is just how they're holding it".
  static const _neutralWeight = 0.01;

  /// Share of the remaining distance covered each frame. Animating on the
  /// ticker rather than on sensor events keeps motion smooth on 120Hz screens,
  /// where frames outnumber samples two to one.
  static const _followWeight = 0.12;

  late final Ticker _ticker;
  StreamSubscription<AccelerometerEvent>? _subscription;

  Offset _target = Offset.zero;
  double _readingX = 0;
  double _readingY = 0;
  double _neutralX = 0;
  double _neutralY = 0;
  bool _seeded = false;
  bool _enabled = true;

  /// Whether the device actually reports tilt. False on desktop and anywhere
  /// the accelerometer stream fails, so callers can skip the effect rather than
  /// wait for motion that never arrives.
  bool get isAvailable => _subscription != null;

  /// Park the effect at centre — for reduced-motion, or a user-facing toggle.
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) _target = Offset.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  bool get enabled => _enabled;

  void _subscribe() {
    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(
      _onReading,
      onError: (Object _) {
        // No accelerometer (desktop, some emulators, web without permission).
        // Stay centred and stop pretending the effect exists.
        _subscription?.cancel();
        _subscription = null;
        _target = Offset.zero;
        if (!_ticker.isActive) _ticker.start();
      },
      cancelOnError: true,
    );
  }

  void _onReading(AccelerometerEvent event) {
    // Seed both filters from the first sample outright. Letting them ease in
    // from zero would swing the whole page in from one corner on every open.
    if (!_seeded) {
      _seeded = true;
      _readingX = _neutralX = event.x;
      _readingY = _neutralY = event.y;
      return;
    }

    _readingX += (event.x - _readingX) * _readingWeight;
    _readingY += (event.y - _readingY) * _readingWeight;
    _neutralX += (_readingX - _neutralX) * _neutralWeight;
    _neutralY += (_readingY - _neutralY) * _neutralWeight;

    if (!_enabled) return;

    // Negated because the accelerometer reads the reaction to gravity: the x
    // component goes negative as the right edge drops.
    _target = Offset(
      (-(_readingX - _neutralX) / _fullScaleTilt).clamp(-1.0, 1.0),
      (-(_readingY - _neutralY) / _fullScaleTilt).clamp(-1.0, 1.0),
    );
    if (!_ticker.isActive) _ticker.start();
  }

  void _onFrame(Duration _) {
    final delta = _target - value;
    // Settling stops the ticker so a phone lying still costs nothing.
    if (delta.distance < 0.001) {
      if (value != _target) value = _target;
      _ticker.stop();
      return;
    }
    value = value + delta * _followWeight;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker.dispose();
    super.dispose();
  }
}

/// Provides a single [TiltNotifier] to a subtree.
///
/// Deliberately a plain [InheritedWidget] rather than an [InheritedNotifier]:
/// dependents should take the notifier once and listen to it locally, so a
/// tilt at 60fps repaints two transforms instead of rebuilding the page.
class TiltScope extends StatefulWidget {
  const TiltScope({super.key, required this.child});

  final Widget child;

  /// The nearest tilt source, or null when there is no [TiltScope] above.
  /// Callers should fall back to a static layout on null rather than assume
  /// one exists.
  static TiltNotifier? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TiltSource>()?.notifier;

  @override
  State<TiltScope> createState() => _TiltScopeState();
}

class _TiltScopeState extends State<TiltScope>
    with SingleTickerProviderStateMixin {
  late final TiltNotifier _notifier = TiltNotifier(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Reduce motion" is exactly the setting this effect has to answer to — a
    // background that drifts under a fixed card is a classic motion-sickness
    // trigger for people who turn it on.
    _notifier.enabled = !MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _TiltSource(notifier: _notifier, child: widget.child);
}

class _TiltSource extends InheritedWidget {
  const _TiltSource({required this.notifier, required super.child});

  final TiltNotifier notifier;

  @override
  bool updateShouldNotify(_TiltSource oldWidget) =>
      notifier != oldWidget.notifier;
}
