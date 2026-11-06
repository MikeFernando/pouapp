/// Mirrors Flutter's debug detection without importing Flutter.
///
/// Profile (`dart.vm.profile`) and release (`dart.vm.product`) keep
/// simulated authentication off. An explicit runtime flag cannot turn it on.
const bool simulatedAuthEnabled =
    !bool.fromEnvironment('dart.vm.product') &&
    !bool.fromEnvironment('dart.vm.profile');
