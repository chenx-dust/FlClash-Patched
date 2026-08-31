abstract mixin class WindowExtListener {
  Future<void> onWindowActivated() async {}

  Future<void> onShouldTerminate() async {}
}
