/// Same compile-time rule used by simulated authentication.
///
/// Demo customers are inserted only in debug builds. Profile and release
/// never receive them, even if seeding is requested.
const bool customerDemoAllowed =
    !bool.fromEnvironment('dart.vm.product') &&
    !bool.fromEnvironment('dart.vm.profile');

const demoSeedKey = 'customer_demo_seeded';
