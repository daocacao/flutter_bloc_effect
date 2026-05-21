import 'package:flutter/widgets.dart';

import 'store.dart';

/// A machine-readable diagnostic severity.
enum MviDiagnosticSeverity {
  /// Informational metadata about a valid scope lookup.
  info,

  /// A recommendation that may prevent avoidable rebuilds or ambiguity.
  warning,

  /// A broken store lookup, such as no matching [MviScope].
  error,
}

/// Describes a registered [MviScope] in the widget tree.
@immutable
final class MviScopeDebugMetadata {
  /// Creates debug metadata for a mounted scope.
  const MviScopeDebugMetadata({
    required this.scopeType,
    required this.storeType,
    required this.depth,
    required this.widget,
    this.debugLabel,
  });

  /// Runtime type of the scope widget.
  final Type scopeType;

  /// Runtime type of the exposed store.
  final Type storeType;

  /// Number of ancestor hops from the lookup context to the matched scope.
  final int depth;

  /// The scope widget that provided the store.
  final Widget widget;

  /// Optional human-readable label supplied by the scope owner.
  final String? debugLabel;
}

/// A validation finding emitted by the MVI diagnostics registry.
@immutable
final class MviDiagnosticFinding {
  /// Creates a diagnostic finding.
  const MviDiagnosticFinding({
    required this.severity,
    required this.message,
    this.recommendation,
    this.metadata,
  });

  /// Severity of this finding.
  final MviDiagnosticSeverity severity;

  /// Short explanation of the lookup result.
  final String message;

  /// Suggested fix for warnings and errors.
  final String? recommendation;

  /// Metadata about the matched scope, when one exists.
  final MviScopeDebugMetadata? metadata;
}

/// Debug/test helper that validates [BuildContext] store lookups.
final class MviDiagnosticsRegistry {
  MviDiagnosticsRegistry._();

  /// Ancestor distance at which a found store is considered suspiciously high.
  static const int defaultTooHighDepth = 3;

  /// Validates whether [context] can resolve a store of type [Store].
  static MviDiagnosticFinding validateStore<Store extends MviStore>(
    BuildContext context, {
    int tooHighDepth = defaultTooHighDepth,
  }) {
    final metadata = lookupStoreMetadata<Store>(context);
    if (metadata == null) {
      return MviDiagnosticFinding(
        severity: MviDiagnosticSeverity.error,
        message: 'No MviScope<$Store> found above this BuildContext.',
        recommendation: 'Wrap this widget in MviScope<$Store> or move the '
            'context.store<$Store>() call below the matching scope.',
      );
    }

    if (metadata.depth > tooHighDepth) {
      return MviDiagnosticFinding(
        severity: MviDiagnosticSeverity.warning,
        message: 'MviScope<$Store> is ${metadata.depth} ancestors above the '
            'lookup context.',
        recommendation:
            'Move MviScope<$Store> closer to the widgets that use it, or split '
            'the feature so unrelated ancestors do not rebuild.',
        metadata: metadata,
      );
    }

    return MviDiagnosticFinding(
      severity: MviDiagnosticSeverity.info,
      message: 'MviScope<$Store> is correctly wired.',
      metadata: metadata,
    );
  }

  /// Returns metadata for the nearest matching [MviScope], if any.
  static MviScopeDebugMetadata? lookupStoreMetadata<Store extends MviStore>(
    BuildContext context,
  ) {
    MviScopeDebugMetadata? result;
    var depth = 0;

    context.visitAncestorElements((element) {
      depth += 1;
      final widget = element.widget;
      if (widget is MviScopeDebugInfo) {
        final debugInfo = widget as MviScopeDebugInfo;
        if (debugInfo.store is Store) {
          result = MviScopeDebugMetadata(
            scopeType: widget.runtimeType,
            storeType: debugInfo.store.runtimeType,
            depth: depth,
            widget: widget,
            debugLabel: debugInfo.debugLabel,
          );
          return false;
        }
      }
      return true;
    });

    return result;
  }
}

/// Debug contract implemented by [MviScope] widgets.
abstract interface class MviScopeDebugInfo {
  /// The store exposed by this scope.
  Object get store;

  /// Optional label used in tests and diagnostics.
  String? get debugLabel;
}
