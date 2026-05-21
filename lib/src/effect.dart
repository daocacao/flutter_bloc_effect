/// The result of delivering an effect to an effect handler.
enum EffectResult {
  /// The effect was consumed and should not bubble any farther.
  handled,

  /// The effect was ignored and should be offered to the next parent handler.
  unhandled,
}

/// Handles a single effect emitted by a store.
///
/// Return [EffectResult.handled] when the effect has been consumed. Return
/// [EffectResult.unhandled] to let the effect bubble to an ancestor [MviScope].
typedef EffectHandler<Effect extends Object> = Future<EffectResult> Function(
  Effect effect,
);

/// A typed callback used by [EffectDispatcher] to bubble unhandled effects.
typedef EffectBubble<Effect extends Object> = Future<EffectResult> Function(
  Effect effect,
);

/// Dispatches effects sequentially and supports handled/unhandled bubbling.
///
/// Stores call [dispatch] when they emit an effect. Calls are queued so an
/// effect is fully handled, including parent bubbling, before the next effect is
/// delivered.
final class EffectDispatcher<Effect extends Object> {
  /// Creates an effect dispatcher.
  EffectDispatcher({
    EffectHandler<Effect>? handler,
    EffectBubble<Effect>? bubble,
  })  : _handler = handler,
        _bubble = bubble;

  EffectHandler<Effect>? _handler;
  EffectBubble<Effect>? _bubble;
  Future<void> _tail = Future<void>.value();

  /// Updates the local effect [handler].
  set handler(EffectHandler<Effect>? handler) => _handler = handler;

  /// Updates the parent [bubble] callback.
  set bubble(EffectBubble<Effect>? bubble) => _bubble = bubble;

  /// Queues [effect] for sequential delivery.
  ///
  /// The returned future completes with the final handling result after the
  /// effect has either been handled locally, handled by an ancestor, or reached
  /// the root unhandled.
  Future<EffectResult> dispatch(Effect effect) {
    final delivery = _tail.then((_) => _deliver(effect));
    _tail = delivery.then<void>((_) {}, onError: (_) {});
    return delivery;
  }

  Future<EffectResult> _deliver(Effect effect) async {
    final localResult = await _handler?.call(effect);
    if (localResult == EffectResult.handled) {
      return EffectResult.handled;
    }

    return _bubble?.call(effect) ?? Future.value(EffectResult.unhandled);
  }
}
