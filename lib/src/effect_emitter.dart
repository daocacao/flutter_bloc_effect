abstract interface class EffectEmitter<Effect> {
  Stream<Effect> get effect;

  void emitEffect(final Effect effect);
}