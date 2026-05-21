# mvi_lib

`mvi_lib` is a small Flutter/Dart toolkit for building apps with **Model–View–Intent** while keeping business logic **out of the widget tree**.

The store owns intent handling, state transitions, effects, and diagnostics. Widgets only render state and send user intents.

```text
User action -> Intent -> Store -> State -> UI
                         └-> Effect -> nearest handler or parent scope
```

## Why another state-management package?

Most Flutter state-management solutions can implement MVI, but the store often leaks into widget lifecycle code, effect handling becomes ad-hoc, and debugging is hard once screens compose.

`mvi_lib` is positioned around four principles:

- **Out-of-widget-tree stores** — create stores in app/service composition, tests, or feature factories; inject them into UI with `MviScope`.
- **Typed intents, state, and effects** — model what can happen instead of passing loosely typed callbacks around.
- **Effect bubbling** — one-shot effects such as navigation, snack bars, analytics, dialogs, and parent feature messages can be handled locally or bubble upward.
- **Diagnostics first** — observe intents, state transitions, effects, store lifecycle, and dropped/unhandled effects.

## Install

```yaml
dependencies:
  mvi_lib: ^0.1.0
```

## Quick start

Define your feature contract:

```dart
sealed class CounterIntent {
  const CounterIntent();
}

final class IncrementPressed extends CounterIntent {
  const IncrementPressed();
}

final class CounterState {
  const CounterState({required this.count});

  final int count;

  CounterState copyWith({int? count}) => CounterState(count: count ?? this.count);
}

sealed class CounterEffect {
  const CounterEffect();
}

final class CounterMilestoneReached extends CounterEffect {
  const CounterMilestoneReached(this.count);

  final int count;
}
```

Create the store outside the widget tree:

```dart
final counterStore = MviStore<CounterIntent, CounterState, CounterEffect>(
  initialState: const CounterState(count: 0),
  onIntent: (intent, emit) async {
    switch (intent) {
      case IncrementPressed():
        final next = emit.state.count + 1;
        emit.state = emit.state.copyWith(count: next);

        if (next % 10 == 0) {
          emit.effect(CounterMilestoneReached(next));
        }
    }
  },
  diagnostics: const MviDiagnostics.tag('counter'),
);
```

Expose it to the UI with `MviScope`:

```dart
MviScope<CounterIntent, CounterState, CounterEffect>.value(
  store: counterStore,
  child: const CounterScreen(),
);
```

Use `context.store` in widgets:

```dart
class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store<CounterIntent, CounterState, CounterEffect>();

    return MviEffectListener<CounterEffect>(
      onEffect: (context, effect) {
        switch (effect) {
          case CounterMilestoneReached(:final count):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Reached $count')),
            );
        }
      },
      child: MviBuilder<CounterState>(
        selector: (state) => state.count,
        builder: (context, count) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$count'),
              ElevatedButton(
                onPressed: () => store.accept(const IncrementPressed()),
                child: const Text('Increment'),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

## Effect bubbling

Effects are one-shot messages. A child handler can consume them, transform them, or let them bubble to the parent scope.

```dart
MviEffectListener<LoginEffect>(
  onEffect: (context, effect) {
    switch (effect) {
      case LoginSucceeded():
        context.bubbleEffect(const AppEffect.openHome());
      case LoginFailed(:final message):
        context.consumeEffect(
          SnackBarEffect(message),
        );
    }
  },
  child: const LoginForm(),
);
```

Use this for feature-to-app communication without wiring navigation callbacks through every widget.

## Diagnostics

Attach diagnostics during store creation:

```dart
final store = MviStore<LoginIntent, LoginState, LoginEffect>(
  initialState: const LoginState.idle(),
  onIntent: loginReducer,
  diagnostics: MviDiagnostics(
    tag: 'login',
    observer: MviObserver.console(),
    includeStateDiffs: true,
    warnOnUnhandledEffects: true,
  ),
);
```

Diagnostics should answer:

- Which intent was accepted?
- Which state changed, and why?
- Which effects were emitted?
- Was an effect handled, bubbled, or dropped?
- Was a store disposed while async work was still running?

## Testing

Because stores are not tied to widgets, feature tests stay small:

```dart
mviTest<LoginIntent, LoginState, LoginEffect>(
  'emits success effect after valid credentials',
  build: () => createLoginStore(fakeAuth: successfulAuth),
  act: (store) => store.accept(
    const LoginSubmitted(email: 'd@example.com', password: 'secret'),
  ),
  expectStates: () => [
    const LoginState.loading(),
    const LoginState.authenticated(),
  ],
  expectEffects: () => [
    const LoginEffect.openHome(),
  ],
);
```

## API surface planned for v0.1

- `MviStore<I, S, E>`
- `MviScope<I, S, E>`
- `BuildContext.store<I, S, E>()`
- `MviBuilder<S>` and selector-based rebuilds
- `MviEffectListener<E>`
- effect consume/bubble helpers
- `MviDiagnostics` and `MviObserver`
- test helpers for states/effects

## Status

`mvi_lib` is pre-1.0. The public API may change while the package proves its ergonomics in real apps.

## License

MIT. See [LICENSE](LICENSE).
