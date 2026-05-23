import 'dart:async';

import 'package:flutter_bloc_effect/flutter_bloc_effect.dart';

abstract class EffectBloc<Event, State, Effect> extends Bloc<Event, State>
    implements EffectEmitter<Effect> {
  final StreamController<Effect> _effectController = .broadcast();

  EffectBloc(super.initialState);

  @override
  Stream<Effect> get effect => _effectController.stream;

  @override
  void emitEffect(Effect effect) {
    _effectController.add(effect);
  }

  @override
  Future<void> close() async {
    await _effectController.close();
    await super.close();
  }
}
