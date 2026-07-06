# Audit Context — REP-15 Upgradeable

## Protocol Summary

REP-15 is an ERC-721 extension standard for the Ronin blockchain implementing three features:
1. **Context System**: Named contexts (created by game/dApp contracts) that attach to tokens, granting context-specific usage rights and user assignment
2. **Ownership Delegation**: Temporary transfer of management rights to a delegatee without transferring ownership
3. **Lock Mechanism**: Contexts can lock tokens preventing transfer until the lock is released (or detaching duration passes after requesting detachment)

## Scope

All contracts in `src/`:
- `REP15.sol` — non-upgradeable abstract base
- `REP15Upgradeable.sol` — upgradeable version (TransparentUpgradeableProxy)
- `REP15Utils.sol` — library with core structs
- `extensions/REP15Enumerable.sol` — adds global context enumeration
- `extensions/REP15EnumerableUpgradeable.sol` — upgradeable enumerable
- `extensions/REP15PausableUpgradeable.sol` — adds pause functionality
- `extensions/REP15BatchUpgradeable.sol` — adds batch attachContext
- `interfaces/*` — all protocol interfaces

## Key Assumptions

- Controller contracts are game/dApp smart contracts that may be malicious (any address can create a context)
- Tokens may have many contexts attached simultaneously
- The ownership manager (owner or active delegatee) controls attach/detach operations
- `onAttached` does NOT use try/catch — controller rejection propagates and reverts attachContext
- `onExecDetachContext` and `onDetachRequested` use try/catch — controller failures are silently ignored
- Transfers call `_detachAllContexts` in `_beforeTokenTransfer` before actual ownership change
- No reentrancy guards exist anywhere in the protocol

## Finding Summaries

### MEDIUM

**M-1: Ghost Context Injection via Reentrancy in `_detachAllContexts`**
Both `REP15.sol` (`_beforeTokenTransfer` inline loop) and `REP15Upgradeable.sol` (`_detachAllContexts`) capture the attached context array length once before iterating. During the `onExecDetachContext` callback in `_detachContext`, a malicious controller with appropriate approval can re-enter `attachContext` and append a new context at an index beyond the captured loop bound. The backward loop exits without visiting the ghost context. After token transfer completes, the recipient inherits the ghost context which the controller can immediately lock for up to 365 days, preventing the recipient from transferring the token for the full detaching duration.

Files: `src/REP15.sol:468`, `src/REP15Upgradeable.sol:498-513`

### LOW

**L-1: Transfers Not Guarded in `REP15PausableUpgradeable`**
`REP15PausableUpgradeable` adds pause protection only to delegation and context operations via `_beforeOwnershipDelegation()` and `_beforeTokenContext()` virtual hooks. Token transfers (`transferFrom`, `safeTransferFrom`) are not guarded. When paused, transfers still execute `_detachAllContexts`, which fires `onExecDetachContext` callbacks on all controller contracts. This means external controller calls occur during a paused state, potentially violating the expected "no state changes while paused" invariant.

File: `src/extensions/REP15PausableUpgradeable.sol`

**L-2: Wrong Revert Error for `execDetachContext` on Non-Attached Context**
`execDetachContext` delegates to `_detachContext(checkReadyForDetachment: true)`. In `_detachContext`, the `readyForDetachmentAt == 0` check (→ `REP15NotRequestedForDetachment`) fires before any attachment check. For a context that was never attached (or was previously detached), `readyForDetachmentAt` is zero, producing `REP15NotRequestedForDetachment` instead of the correct `REP15NonexistentAttachedContext`. Integrators handling these errors off-chain may take incorrect actions.

Files: `src/REP15Upgradeable.sol:458-468`, `src/REP15.sol:397-407`

### INFORMATIONAL

**I-1: Authorization Check After State Query in `startDelegateOwnership`**
`startDelegateOwnership` checks delegation state (`isActive()`) before the caller authorization (`_isApprovedOrOwner`). An unauthorized caller can determine whether an active delegation exists by observing which error is returned. This information is already publicly readable via `getOwnershipDelegatee()`, so there is no practical exploit.

File: `src/REP15Upgradeable.sol:83-87`

**I-2: Redundant `_attachedContexts` Storage in Enumerable Extension**
`REP15Upgradeable` maintains `_attachedContexts` and `_attachedContextsIndex` in its own storage struct for efficient swap-and-pop operations. `REP15EnumerableUpgradeable` adds a separate `_attachedContexts` and `_attachedContextsIndex` in its own ERC-7201 storage struct. Both are maintained in parallel via the `_afterAttachContext`/`_afterDetachContext` hook chain. This doubles the gas cost of attach and detach operations when using the Enumerable extension.

Files: `src/REP15Upgradeable.sol:591-613`, `src/extensions/REP15EnumerableUpgradeable.sol:101-123`
