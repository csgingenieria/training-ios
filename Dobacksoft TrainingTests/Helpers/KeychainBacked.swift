import Testing

/// Parent suite for everything that touches the simulator's real Keychain.
///
/// `TokenStore` addresses one fixed service/account pair, so every such test
/// shares a single global resource. Marking each suite `.serialized`
/// individually was not enough: that orders cases *within* a suite, while
/// distinct suites still run in parallel and clobber each other's tokens.
///
/// Nesting them under one serialized parent — child suites inherit the trait —
/// makes the whole subtree run one case at a time.
@Suite(.serialized)
struct KeychainBacked {}
