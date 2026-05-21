import 'package:flutter/widgets.dart';

import 'diagnostics.dart';
import 'effect.dart';
import 'store.dart';

/// Creates a store for an [MviScope].
typedef StoreFactory<Store extends MviStore> = Store Function(
  BuildContext context,
);

/// Builds UI with a scoped [store].
typedef MviStoreWidgetBuilder<Store extends MviStore> = Widget Function(
  BuildContext context,
  Store store,
);

/// Provides an out-of-widget-tree MVI store to descendants.
///
/// The store is created once in [State.initState], held outside the widget tree,
/// exposed through [BuildContextMvi.store], and disposed with the scope unless
/// [disposeStore] is `false`.
class MviScope<Store extends MviStore> extends StatefulWidget
    implements MviScopeDebugInfo {
  /// Creates a scope that owns a store returned by [create].
  const MviScope({
    required this.create,
    required this.builder,
    this.onEffect,
    this.disposeStore = true,
    this.debugLabel,
    super.key,
  });

  /// Creates the scoped store once for this scope lifecycle.
  final StoreFactory<Store> create;

  /// Builds descendants that can read the store using `context.store<Store>()`.
  final MviStoreWidgetBuilder<Store> builder;

  /// Handles effects emitted by this store.
  ///
  /// Return [EffectResult.unhandled] to bubble the effect to a parent
  /// [MviScope]. Bubbling is dynamic so parent scopes can centralize app-level
  /// effects when they choose to handle them.
  final EffectHandler<Object>? onEffect;

  /// Whether the store should be disposed when this scope is removed.
  final bool disposeStore;

  @override
  final String? debugLabel;

  @override
  Object get store => _MviScopeState._debugStores[this]!;

  @override
  State<MviScope<Store>> createState() => _MviScopeState<Store>();
}

class _MviScopeState<Store extends MviStore> extends State<MviScope<Store>> {
  static final Expando<Object> _debugStores = Expando<Object>('mviStore');

  late final Store _store;
  late final EffectDispatcher<Object> _dispatcher;

  @override
  void initState() {
    super.initState();
    _store = widget.create(context);
    _debugStores[widget] = _store;
    _dispatcher = EffectDispatcher<Object>(handler: widget.onEffect);
    _store.attachEffectDispatcher(_dispatcher);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dispatcher.bubble = _findParentBubble(context);
  }

  @override
  void didUpdateWidget(covariant MviScope<Store> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _debugStores[oldWidget] = null;
    _debugStores[widget] = _store;
    _dispatcher.handler = widget.onEffect;
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedMviEffectScope(
      effectBubble: _dispatcher.dispatch,
      child: _InheritedMviScope<Store>(
        store: _store,
        child: widget.builder(context, _store),
      ),
    );
  }

  @override
  void dispose() {
    _debugStores[widget] = null;
    _store.attachEffectDispatcher(null);
    if (widget.disposeStore) {
      _store.dispose();
    }
    super.dispose();
  }

  EffectBubble<Object>? _findParentBubble(BuildContext context) {
    final parent = context
        .getElementForInheritedWidgetOfExactType<_InheritedMviEffectScope>()
        ?.widget;
    if (parent case final _InheritedMviEffectScope scope) {
      return scope.effectBubble;
    }
    return null;
  }
}

class _InheritedMviEffectScope extends InheritedWidget {
  const _InheritedMviEffectScope({
    required this.effectBubble,
    required super.child,
  });

  final EffectBubble<Object> effectBubble;

  @override
  bool updateShouldNotify(_InheritedMviEffectScope oldWidget) {
    return !identical(effectBubble, oldWidget.effectBubble);
  }
}

class _InheritedMviScope<Store extends MviStore> extends InheritedWidget {
  const _InheritedMviScope({
    required this.store,
    required super.child,
  });

  final Store store;

  @override
  bool updateShouldNotify(_InheritedMviScope<Store> oldWidget) {
    return !identical(store, oldWidget.store);
  }
}

/// Convenience APIs for reading MVI stores from a [BuildContext].
extension BuildContextMvi on BuildContext {
  /// Returns the nearest scoped store of type [Store].
  ///
  /// This method registers the caller as dependent on the scope. Use [readStore]
  /// when dependency tracking is not needed, such as in callbacks.
  Store store<Store extends MviStore>() {
    final scope =
        dependOnInheritedWidgetOfExactType<_InheritedMviScope<Store>>();
    if (scope != null) {
      return scope.store;
    }

    final finding = MviDiagnosticsRegistry.validateStore<Store>(this);
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary('Unable to resolve MVI store $Store.'),
      ErrorDescription(finding.message),
      if (finding.recommendation != null) ErrorHint(finding.recommendation!),
    ]);
  }

  /// Returns the nearest scoped store of type [Store] without listening.
  Store readStore<Store extends MviStore>() {
    final element =
        getElementForInheritedWidgetOfExactType<_InheritedMviScope<Store>>();
    final scope = element?.widget;
    if (scope is _InheritedMviScope<Store>) {
      return scope.store;
    }

    final finding = MviDiagnosticsRegistry.validateStore<Store>(this);
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary('Unable to resolve MVI store $Store.'),
      ErrorDescription(finding.message),
      if (finding.recommendation != null) ErrorHint(finding.recommendation!),
    ]);
  }

  /// Validates whether [store] would resolve for this context.
  MviDiagnosticFinding validateStore<Store extends MviStore>({
    int tooHighDepth = MviDiagnosticsRegistry.defaultTooHighDepth,
  }) =>
      MviDiagnosticsRegistry.validateStore<Store>(
        this,
        tooHighDepth: tooHighDepth,
      );
}
