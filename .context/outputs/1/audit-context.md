# Audit Context

## Scope
- Blockchain: Ethereum/EVM (Solidity >=0.8.17)
- Protocol Type: NFT Token Standard Extension (ERC-721 with Context/Delegation)
- Files in scope: src/ directory (13 Solidity files)
- Dependencies: OpenZeppelin v4 (non-upgradeable and upgradeable)

## Key Assumptions
1. The protocol is deployed as TransparentUpgradeableProxy (per CLAUDE.md guidance)
2. The REP15Upgradeable contract is NOT deployed as implementation directly — it expects to be behind a proxy
3. The protocol handles NFT contexts (rental, staking, delegation use-cases) with no direct fund management
4. Callbacks to external controllers are intentionally skippable for detach flows

## Architecture Summary
- REP15.sol: Abstract base for non-upgradeable ERC-721 with REP15 extension
- REP15Upgradeable.sol: Upgradeable version using ERC-7201 custom storage slots
- REP15Utils.sol: Library of utility functions and structs
- REP15Enumerable.sol / REP15EnumerableUpgradeable.sol: Enumeration extension
- REP15PausableUpgradeable.sol: Pause gate for delegation/context operations
- REP15BatchUpgradeable.sol: Batch attachContext operations
- ControllerMock.sol: Test mock for IREP15ContextCallback

## Finding Summary
| Severity | Count | Status |
|----------|-------|--------|
| High | 1 | VALID |
| Medium | 2 | VALID |
| Low | 2 | VALID |
| Informational | 1 | VALID |
