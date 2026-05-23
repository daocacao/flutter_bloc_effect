import 'package:flutter/material.dart';
import 'package:flutter_bloc_effect/flutter_bloc_effect.dart';

void main() => runApp(ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BlocProvider(
        create: (context) => CounterBloc(),
        child: CounterPage(),
      ),
    );
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocEffectListener<CounterBloc, CounterEffect>(
        listener: (context, effect) => switch (effect) {
          CounterEffectMilestoneReached() => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Milestone reached!'))),
        },
        child: Center(
          child: BlocBuilder<CounterBloc, CounterState>(
            builder: (context, state) => Text('${state.count}'),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<CounterBloc>().add(const .increment()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CounterBloc
    extends EffectBloc<CounterIntent, CounterState, CounterEffect> {
  CounterBloc() : super(const CounterState(0)) {
    on<CounterIntentIncrement>(_increment);
  }

  void _increment(CounterIntentIncrement event, Emitter<CounterState> emit) {
    final newCount = state.count + 1;
    if (newCount % 5 == 0) emitEffect(CounterEffect.milestoneReached());
    emit(CounterState(newCount));
  }
}

sealed class CounterIntent {
  const CounterIntent();

  const factory CounterIntent.increment() = CounterIntentIncrement;
}

class CounterIntentIncrement extends CounterIntent {
  const CounterIntentIncrement();
}

class CounterState {
  final int count;

  const CounterState(this.count);
}

sealed class CounterEffect {
  const CounterEffect();

  const factory CounterEffect.milestoneReached() =
      CounterEffectMilestoneReached;
}

class CounterEffectMilestoneReached extends CounterEffect {
  const CounterEffectMilestoneReached();
}
