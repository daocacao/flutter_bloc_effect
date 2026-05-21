import 'dart:async';

import 'package:flutter/foundation.dart';

import 'effect.dart';

/// A reducer-style store for Model-View-Intent state management.
///
/// [State] is immutable UI state, [Intent] is input from the view or
/// environment, and [Effect] is a one-off event such as navigation or a toast.
abstract base class MviStore<State extends Object, Intent extends Object,
    Effect extends Object> extends ChangeNotifier {
  /// Creates a store with [initialState].
  MviStore(State initialState) : _state = initialState;

  final StreamController<Effect> _effects =
      StreamController<Effect>.broadcast();
  EffectDispatcher<Object>? _dispatcher;
  State _state;
  bool _disposed = false;

  /// The current immutable state snapshot.
  State get state => _state;

  /// A broadcast stream of effects emitted by this store.
  Stream<Effect> get effects => _effects.stream;

  /// Whether this store has been disposed.
  bool get isDisposed => _disposed;

  /// Handles an [intent].
  FutureOr<void> accept(Intent intent);

  /// Replaces the current state and notifies listeners when it changed.
  @protected
  void setState(State state) {
    if (_disposed || identical(_state, state) || _state == state) {
      return;
    }

    _state = state;
    notifyListeners();
  }

  /// Emits a one-off [effect].
  ///
  /// Effects are added to [effects] and then dispatched through the active
  /// [MviScope] dispatcher. Dispatcher delivery is sequential.
  @protected
  Future<EffectResult> emitEffect(Effect effect) {
    if (_disposed) {
      return Future.value(EffectResult.unhandled);
    }

    _effects.add(effect);
    return _dispatcher?.dispatch(effect) ??
        Future.value(EffectResult.unhandled);
  }

  /// Attaches the scoped effect [dispatcher] to this store.
  @internal
  void attachEffectDispatcher(EffectDispatcher<Object>? dispatcher) {
    _dispatcher = dispatcher;
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _dispatcher = null;
    _effects.close();
    super.dispose();
  }
}
