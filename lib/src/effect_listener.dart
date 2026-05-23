import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc_effect/flutter_bloc_effect.dart';

class BlocEffectListener<B extends EffectEmitter<E>, E> extends StatefulWidget {
  final void Function(BuildContext context, E effect) listener;
  final Widget child;

  const BlocEffectListener({
    super.key,
    required this.listener,
    required this.child,
  });

  @override
  State<BlocEffectListener<B, E>> createState() =>
      _BlocEffectListenerState<B, E>();
}

class _BlocEffectListenerState<B extends EffectEmitter<E>, E>
    extends State<BlocEffectListener<B, E>> {
  late final StreamSubscription<E> subscription;

  @override
  initState() {
    super.initState();
    subscription = context.read<B>().effect.listen(
      (effect) => mounted ? widget.listener(context, effect) : null,
    );
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
