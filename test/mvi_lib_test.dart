import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvi_lib/mvi_lib.dart';

final class CounterStore extends MviStore<int, String, String> {
  CounterStore() : super(0);

  Future<EffectResult> send(String effect) => emitEffect(effect);

  @override
  void accept(String intent) {
    if (intent == 'increment') {
      setState(state + 1);
    }
  }
}

final class OtherStore extends MviStore<int, String, String> {
  OtherStore() : super(0);

  Future<EffectResult> send(String effect) => emitEffect(effect);

  @override
  void accept(String intent) {}
}

void main() {
  test('store updates state and notifies listeners', () {
    final store = CounterStore();
    var notifications = 0;
    store.addListener(() => notifications++);

    store.accept('increment');

    expect(store.state, 1);
    expect(notifications, 1);
  });

  test('effect dispatcher handles effects sequentially', () async {
    final seen = <String>[];
    final dispatcher = EffectDispatcher<String>(
      handler: (effect) async {
        if (effect == 'first') {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        seen.add(effect);
        return EffectResult.handled;
      },
    );

    final first = dispatcher.dispatch('first');
    final second = dispatcher.dispatch('second');
    await Future.wait([first, second]);

    expect(seen, ['first', 'second']);
  });

  test('unhandled effects bubble to parent dispatcher', () async {
    final parentSeen = <String>[];
    final parent = EffectDispatcher<String>(
      handler: (effect) async {
        parentSeen.add(effect);
        return EffectResult.handled;
      },
    );
    final child = EffectDispatcher<String>(
      handler: (_) async => EffectResult.unhandled,
      bubble: parent.dispatch,
    );

    final result = await child.dispatch('navigate');

    expect(result, EffectResult.handled);
    expect(parentSeen, ['navigate']);
  });

  testWidgets('MviScope creates and exposes store', (tester) async {
    late CounterStore created;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MviScope<CounterStore>(
          create: (_) => created = CounterStore(),
          builder: (context, store) {
            return Builder(
              builder: (context) {
                return Text('${context.store<CounterStore>().state}');
              },
            );
          },
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);
    expect(created.isDisposed, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(created.isDisposed, isTrue);
  });

  testWidgets('MviScope bubbles unhandled effects to parent scopes', (
    tester,
  ) async {
    late OtherStore childStore;
    final seen = <String>[];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MviScope<CounterStore>(
          create: (_) => CounterStore(),
          onEffect: (effect) async {
            seen.add('parent:$effect');
            return EffectResult.handled;
          },
          builder: (context, parentStore) => MviScope<OtherStore>(
            create: (_) => childStore = OtherStore(),
            onEffect: (effect) async {
              seen.add('child:$effect');
              return EffectResult.unhandled;
            },
            builder: (context, store) => const SizedBox(),
          ),
        ),
      ),
    );

    final result = await childStore.send('global-error');

    expect(result, EffectResult.handled);
    expect(seen, ['child:global-error', 'parent:global-error']);
  });

  testWidgets('diagnostics expose store metadata for valid wiring', (
    tester,
  ) async {
    late MviDiagnosticFinding finding;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MviScope<CounterStore>(
          debugLabel: 'counter-feature',
          create: (_) => CounterStore(),
          builder: (context, store) => Builder(
            builder: (context) {
              finding = context.validateStore<CounterStore>();
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(finding.severity, MviDiagnosticSeverity.info);
    expect(finding.metadata?.debugLabel, 'counter-feature');
    expect(finding.metadata?.storeType, CounterStore);
  });

  testWidgets('diagnostics report missing stores with recommendations', (
    tester,
  ) async {
    late BuildContext leafContext;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            leafContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final finding = leafContext.validateStore<CounterStore>();

    expect(finding.severity, MviDiagnosticSeverity.error);
    expect(finding.message, contains('No MviScope<CounterStore>'));
    expect(finding.recommendation, contains('Wrap this widget'));
    expect(() => leafContext.store<CounterStore>(), throwsFlutterError);
  });

  testWidgets('diagnostics recommend moving stores closer when too high', (
    tester,
  ) async {
    late MviDiagnosticFinding finding;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MviScope<CounterStore>(
          create: (_) => CounterStore(),
          builder: (context, store) => Padding(
            padding: EdgeInsets.zero,
            child: Center(
              child: Column(
                children: <Widget>[
                  Builder(
                    builder: (context) {
                      finding = context.validateStore<CounterStore>(
                        tooHighDepth: 1,
                      );
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(finding.severity, MviDiagnosticSeverity.warning);
    expect(finding.metadata?.depth, greaterThan(1));
    expect(finding.recommendation, contains('Move MviScope<CounterStore>'));
  });

  testWidgets('diagnostics ignore scopes for other store types', (
    tester,
  ) async {
    late BuildContext leafContext;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MviScope<OtherStore>(
          create: (_) => OtherStore(),
          builder: (context, store) => Builder(
            builder: (context) {
              leafContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final finding = leafContext.validateStore<CounterStore>();

    expect(finding.severity, MviDiagnosticSeverity.error);
    expect(finding.metadata, isNull);
  });
}
