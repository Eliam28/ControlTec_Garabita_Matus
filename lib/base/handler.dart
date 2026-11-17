abstract interface class Handler<I, O> {
  Future<O> execute(I input);
}
