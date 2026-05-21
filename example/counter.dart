import 'package:flutter/material.dart';
import 'package:mvi_lib/mvi_lib.dart';

/// User actions accepted by [CounterStore].
sealed class CounterIntent {
  const CounterIntent();
}

/// Increments the visible counter.
final class IncrementPressed extends CounterIntent {
  /// Creates an increment intent.
  const IncrementPressed();
}

/// Immutable UI state for the counter screen.
final class CounterState {
  /// Creates a counter state with [count].
  const CounterState({
    required this.count,
  });

  /// The current counter value.
  final int count;
}

/// One-shot events emitted by [CounterStore].
sealed class CounterEffect {
  const CounterEffect();
}

/// Signals that [count] reached a milestone.
final class CounterMilestoneReached extends CounterEffect {
  /// Creates a milestone effect for [count].
  const CounterMilestoneReached(this.count);

  /// The milestone value.
  final int count;
}

/// Example store used by [CounterScreen].
final class CounterStore
    extends MviStore<CounterState, CounterIntent, CounterEffect> {
  /// Creates a counter store.
  CounterStore() : super(const CounterState(count: 0));

  @override
  Future<void> accept(CounterIntent intent) async {
    switch (intent) {
      case IncrementPressed():
        final next = state.count + 1;
        setState(CounterState(count: next));
        if (next % 10 == 0) {
          await emitEffect(CounterMilestoneReached(next));
        }
    }
  }
}

/// Minimal runnable screen that keeps MVI lifecycle at the screen boundary.
class CounterScreen extends StatelessWidget {
  /// Creates a counter screen.
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MviScope<CounterStore>(
      create: (_) => CounterStore(),
      onEffect: (effect) async {
        if (effect is CounterMilestoneReached) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reached ${effect.count}')),
          );
          return EffectResult.handled;
        }
        return EffectResult.unhandled;
      },
      builder: (context, store) {
        return Scaffold(
          appBar: AppBar(title: const Text('mvi_lib counter')),
          body: Center(
            child: AnimatedBuilder(
              animation: store,
              builder: (context, _) => Text('${store.state.count}'),
            ),
          ),
          floatingActionButton: Builder(
            builder: (context) {
              return FloatingActionButton(
                onPressed: () {
                  context.readStore<CounterStore>().accept(
                        const IncrementPressed(),
                      );
                },
                child: const Icon(Icons.add),
              );
            },
          ),
        );
      },
    );
  }
}
