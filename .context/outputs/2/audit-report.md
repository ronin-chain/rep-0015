# Smart Contract Security Assessment Report
## REP-15 Upgradeable — ERC-721 Context/Delegation Extension

---

## Executive Summary

### Protocol Overview

**Protocol Purpose:** REP-15 is an ERC-721 extension standard for the Ronin blockchain that introduces three interrelated mechanics: a **Context System** allowing game/dApp contracts to attach named usage contexts to tokens (granting in-game rights, user assignments), an **Ownership Delegation** mechanism enabling temporary transfer of management authority without transferring ownership, and a **Lock Mechanism** allowing contexts to prevent token transfers until a controlled unlock sequence is completed.

**Industry Vertical:** NFT/Gaming — on-chain protocol for Axie Infinity and the broader Ronin gaming ecosystem. Tokens represent playable assets (axes, land, pets) whose in-game usage is mediated by context controllers.

**User Profile:** NFT holders (players/collectors), delegatees (account managers or rental agents), and context controllers (game contracts, rental protocols). Primary risk is holders' assets becoming locked or transferred with residual entanglements.

**Total Value Locked:** Not directly applicable (NFT protocol, not DeFi). However, NFTs in the Ronin ecosystem can carry significant individual value (Axies have historically traded at $100–$10,000+ per token). The protocol will mediate context attachment for an entire collection.

### Threat Model Summary

**Primary Threats Identified:**
- A malicious previous owner injecting a persistent ghost context onto a token at point-of-sale, locking the buyer out of transferring the asset for up to 365 days
- External game/dApp controller contracts being invoked while the protocol is in a paused state
- Integration errors arising from misleading revert reasons in the detach flow

### Security Posture Assessment

**Overall Risk Level:** Medium

**Total Findings:** 0 Critical, 0 High, 1 Medium, 2 Low, 2 Informational

**Key Risk Areas:**
1. Reentrancy via controller callbacks during token transfer — the protocol makes external calls inside `_beforeTokenTransfer` with no reentrancy guard
2. Incomplete pause coverage — pause guards do not extend to the transfer flow
3. Error-message fidelity for non-existent context detachment

---

## Table of Contents

### Medium Findings
- [M-1 Ghost Context Injection via Reentrancy in `_detachAllContexts`](#m-1-ghost-context-injection-via-reentrancy-in-_detachallcontexts) — VALID

### Low Findings
- [L-1 Transfers Not Guarded in `REP15PausableUpgradeable`](#l-1-transfers-not-guarded-in-rep15pausableupgradeable) — VALID
- [L-2 Wrong Revert Error for `execDetachContext` on Non-Attached Context](#l-2-wrong-revert-error-for-execdetachcontext-on-non-attached-context) — VALID

### Informational Findings
- [I-1 Authorization Check After Delegation State Query in `startDelegateOwnership`](#i-1-authorization-check-after-delegation-state-query-in-startdelegateownership) — ACKNOWLEDGED
- [I-2 Redundant `_attachedContexts` Storage in Enumerable Extension](#i-2-redundant-_attachedcontexts-storage-in-enumerable-extension) — ACKNOWLEDGED

---

## Detailed Findings

---

### M-1: Ghost Context Injection via Reentrancy in `_detachAllContexts`

**Severity:** Medium
**Type:** Cross-function Reentrancy / Logic Error
**Locations:**
- `src/REP15.sol:467-478` (`_beforeTokenTransfer` inline loop)
- `src/REP15Upgradeable.sol:495-514` (`_detachAllContexts`)
**Status:** Open

#### Description

When a token is transferred, `_beforeTokenTransfer` iterates over all attached contexts and detaches each one. In `REP15Upgradeable`, this logic is extracted into `_detachAllContexts`; in `REP15.sol`, it is inlined in `_beforeTokenTransfer`. In both cases, the implementation captures the array length once before the loop and then reads context hashes from the storage array on each iteration:

```solidity
// REP15Upgradeable.sol:495-513
function _detachAllContexts(uint256 tokenId, address operator) internal virtual {
    REP15Storage storage $ = _getREP15Storage();
    bytes32[] storage $attachedContexts = $._attachedContexts[tokenId];
    int256 length = int256($attachedContexts.length);  // length captured once

    if (length == 0) return;
    bytes32 ctxHash;
    for (int256 i = length - 1; i >= 0; --i) {
        ctxHash = $attachedContexts[uint256(i)];       // dynamic storage read
        _detachContext({ ctxHash: ctxHash, tokenId: tokenId, ... });
    }
}
```

Inside `_detachContext`, after removing the context from storage, the protocol calls `onExecDetachContext` on the controller contract (with `allowFail: true` so failures are silently swallowed):

```solidity
// REP15Upgradeable.sol:477-483
_triggerContextCallback({
    controller: $._contexts[ctxHash].controller,
    callData: abi.encodeCall(IREP15ContextCallback.onExecDetachContext, (...)),
    allowFail: true
});
```

A malicious controller can re-enter `attachContext` during this callback. At the time of the callback, the token's ownership has not yet changed (the actual ERC-721 `_owners` update happens after `_beforeTokenTransfer` returns), so the original owner's approvals (`approve()` on the token ID, or a persistent `setApprovalForAll`) are still valid. The re-entrant `attachContext` appends a new context to `$._attachedContexts[tokenId]` at an index `>= original_length`. The backward loop never visits indices beyond `original_length - 1`, so the ghost context survives the loop.

**Concrete trace** (initial: contexts `[A, B, C]`, `length = 3`):
1. `i=2`: detach `C` → callback fires → malicious controller calls `attachContext(D)` → `$._attachedContexts = [A, B, D]` (swap-and-pop put D at index 2, then D appended → wait: C was detached via pop at index 2, then D pushed → `[A, B, D]`)
2. `i=1`: detach `B` → `B` is at index 1, `D` is last → swap `B` with `D` → pop → `$._attachedContexts = [A, D]`
3. `i=0`: detach `A` → `A` is at index 0, `D` is last → swap → pop → `$._attachedContexts = [D]`
4. Loop exits (i becomes -1). Context `D` remains attached; `_tokenContext[tokenId][D].attached == true`.

After the transfer, the recipient receives the token with context `D` still attached. The malicious controller immediately calls `setContextLock(D, tokenId, true)`, locking the token. The recipient cannot transfer the token until they call `requestDetachContext` (starting the detaching duration clock, up to 365 days).

#### Impact

A malicious previous token owner can grief the buyer by:
1. Attaching a context with a malicious controller before selling
2. At point of sale (or at any later transfer), the controller re-enters `attachContext` during the `onExecDetachContext` callback
3. The ghost context is locked immediately after attachment
4. The buyer's token is transfer-locked for the full detaching duration (up to 365 days)

This is a griefing attack enabling permanent token lock for any configurable duration. The attacker need not be sophisticated — the setup can be automated in the malicious controller's `onExecDetachContext` implementation. Anyone selling a token with an innocuous-looking context attached could trigger this against the buyer.

#### Proof of Concept

```solidity
contract MaliciousController is IREP15ContextCallback {
    IREP15 public immutable nft;
    bytes32 public ghostCtxHash;
    uint256 public targetTokenId;

    constructor(IREP15 _nft) { nft = _nft; }

    function setup(bytes32 _ghostCtxHash, uint256 _tokenId) external {
        ghostCtxHash = _ghostCtxHash;
        targetTokenId = _tokenId;
    }

    function onAttached(bytes32, uint256, address, bytes calldata) external override {}
    function onDetachRequested(bytes32, uint256, address, bytes calldata) external override {}

    function onExecDetachContext(bytes32, uint256 tokenId, address, address, bytes calldata) external override {
        if (tokenId == targetTokenId && ghostCtxHash != bytes32(0)) {
            // Re-enter attachContext — the token's previous owner still has approval
            // because _beforeTokenTransfer hasn't returned yet
            nft.attachContext(ghostCtxHash, tokenId, "");
            // Immediately lock the ghost context
            nft.setContextLock(ghostCtxHash, tokenId, true);
            ghostCtxHash = bytes32(0); // prevent infinite recursion
        }
    }
}
```

Attack setup:
1. Attacker creates `MaliciousController` and calls `createContext(maliciousController, 365 days, "ghost")`
2. Attacker calls `createContext(maliciousController, 0, "trigger")` — zero-duration context used as the trigger
3. Attacker calls `attachContext(triggerCtxHash, tokenId, "")` and `attachContext(ghostCtxHash, tokenId, "")`
4. `setup(ghostCtxHash, tokenId)` — wait, the attacker needs the ghost context to not be attached yet for the re-entry to work. The ghost context would need to be a DIFFERENT context created but not yet attached. Let the trigger context be the one that fires the callback.
5. Actually the simplest: attach only the trigger context, then during the onExecDetachContext of the trigger context, attach a NEW ghost context. For this, the ghost context must exist (created separately).

Simpler version: Attacker creates two contexts `trigger` (attached to token) and `ghost` (not yet attached). During `onExecDetachContext(trigger)`, attaches `ghost` and locks it.

Precondition: The attacker needs `setApprovalForAll` from the token owner (or be the owner), which is the normal flow for a game integration.

#### Recommendation

Add a reentrancy guard to the transfer flow. The cleanest fix is to prevent reentrant calls to `attachContext` during `_beforeTokenTransfer`:

**Option A — Reentrancy guard flag in storage:**
```solidity
// In REP15Storage struct, add:
bool _detachingInProgress;

// In _detachAllContexts / _beforeTokenTransfer:
if ($._detachingInProgress) revert REP15ReentrantDetach();
$._detachingInProgress = true;
// ... loop ...
$._detachingInProgress = false;

// In _attachContext:
if ($._detachingInProgress) revert REP15ReentrantDetach();
```

**Option B — Snapshot the array before iterating:**
```solidity
function _detachAllContexts(uint256 tokenId, address operator) internal virtual {
    bytes32[] storage $attachedContexts = _getREP15Storage()._attachedContexts[tokenId];
    bytes32[] memory snapshot = $attachedContexts; // copy to memory
    for (int256 i = int256(snapshot.length) - 1; i >= 0; --i) {
        _detachContext({ ctxHash: snapshot[uint256(i)], tokenId: tokenId, ... });
    }
}
```

Option A has lower gas cost; Option B is simpler but copies the array. Option A is recommended.

#### Triager Validation

**Cross-Reference Analysis:**
- Checked against all other findings — no contradiction; this finding is independent of the pausable and wrong-error findings
- Verified no other mechanism clears the ghost context post-transfer
- Severity consistent with ghost context findings in NFT gaming audit patterns

**Economic Feasibility:**
- Attack cost: gas to create 2 contexts + 2 attachContext calls + 1 transfer. Negligible vs. value of high-priced NFTs
- Attack profit: attacker may extort the recipient to unlock the context, OR use the locked ghost context to prevent a secondary-market sale (competing with the attacker's own listing)
- No capital requirement; attack is griefing-based, not profit-maximizing

**Technical Verification:**
- Confirmed via code trace: `_detachContext` deletes `_tokenContext[tokenId][ctxHash]` and calls `_removeAttachedContext` BEFORE triggering the callback (lines 470-483 in REP15Upgradeable). The storage is "clean" for the reentrant `_requireNotAttachedTokenContext` check on the ghost context — it passes because `attached == false` for the not-yet-attached ghost context.
- Confirmed approval persists: OZ ERC721 `_afterTokenTransfer` clears `approve()`; `_beforeTokenTransfer` is called first, so individual token approval is still valid during the callback. `setApprovalForAll` is never cleared by the protocol.
- Attempted technical disproof: is there any modifier or check that would prevent reentrant `attachContext`? There is none — `attachContext` only requires `onlyOwnershipManager` and the context to not already be attached.
- **RELUCTANTLY VALID:** Finding is technically sound. The reentrancy path is real, the authorization conditions are realistic for a gaming context (game contracts routinely have `setApprovalForAll`), and the impact (365-day transfer lock) is severe for the affected user.

---

### L-1: Transfers Not Guarded in `REP15PausableUpgradeable`

**Severity:** Low
**Type:** Incomplete Pause Coverage / Design Gap
**Location:** `src/extensions/REP15PausableUpgradeable.sol`
**Status:** Open

#### Description

`REP15PausableUpgradeable` extends `REP15Upgradeable` with pause functionality by overriding two virtual hooks:

```solidity
abstract contract REP15PausableUpgradeable is Initializable, REP15Upgradeable, PausableUpgradeable {
    function _beforeOwnershipDelegation() internal virtual override { _requireNotPaused(); }
    function _beforeTokenContext() internal virtual override { _requireNotPaused(); }
}
```

This guards all delegation operations (`startDelegateOwnership`, `acceptOwnershipDelegation`, `stopOwnershipDelegation`) and all context operations (`createContext`, `updateContext`, `attachContext`, `requestDetachContext`, `execDetachContext`, `setContextLock`, `setContextUser`). However, token transfers (`transferFrom`, `safeTransferFrom`, `safeTransferFrom(bytes)`) are NOT guarded.

When a transfer occurs while paused, `_beforeTokenTransfer` calls `_detachAllContexts`, which in turn fires `onExecDetachContext` and (for pending detachments) reads from controller state. External controller contracts are thus called while the protocol is in a paused state. A pausing admin may expect that all external calls cease during pause; this expectation is violated.

#### Impact

- **Operator expectation violation:** Pause is typically engaged during incidents or upgrades. Controller contracts may have their own internal state that is not safe to update while the REP-15 protocol is paused.
- **Incomplete emergency stop:** An attacker triggering a transfer (if they hold or are approved for a token) can force callbacks even during an emergency pause.
- Low direct financial impact in isolation, but could amplify another vulnerability if an attacker transfers tokens to trigger callbacks that interact with a vulnerable system.

#### Recommendation

Override `_beforeTokenTransfer` in `REP15PausableUpgradeable` to block transfers while paused:

```solidity
function _beforeTokenTransfer(
    address from, address to, uint256 firstTokenId, uint256 batchSize
) internal virtual override {
    if (from != address(0)) _requireNotPaused(); // skip mint
    super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
}
```

If burning while paused is also to be blocked, remove the `from != address(0)` guard.

The test file `test/REP15Upgradeable.pausable.t.sol` should be extended with a test `test_transferFrom_RevertWhen_Paused` to document this behavior.

#### Triager Validation

**Technical Verification:**
- Confirmed: `test/REP15Upgradeable.pausable.t.sol` contains no test for `transferFrom` while paused.
- Confirmed: `_beforeTokenTransfer` is not overridden in `REP15PausableUpgradeable`.
- Attempted disproof: Is there any parent contract that blocks transfers while paused? ERC721Upgradeable does not check pause state. No such protection exists.

**Economic Feasibility:**
- An attacker who holds a token could call `transferFrom` to themselves (or to any address) while the protocol is paused, triggering callbacks. Cost: gas only.

**VALID:** Transfers fire controller callbacks during pause. Severity is Low because no direct fund loss occurs, but the incomplete pause coverage is a real design gap that could amplify other vulnerabilities.

---

### L-2: Wrong Revert Error for `execDetachContext` on Non-Attached Context

**Severity:** Low
**Type:** Logic Error / Misleading Error Message
**Locations:**
- `src/REP15Upgradeable.sol:458-467` (`_detachContext`)
- `src/REP15.sol:397-407` (`_detachContext`)
**Status:** Open

#### Description

`execDetachContext` calls `_detachContext` with `checkReadyForDetachment: true`. In `_detachContext`, when `checkReadyForDetachment` is true, the first check is `readyForDetachmentAt == 0`:

```solidity
// REP15Upgradeable.sol:458-467
function _detachContext(..., bool checkReadyForDetachment, ...) internal {
    REP15Storage storage $ = _getREP15Storage();
    REP15Utils.TokenContext storage $tokenContext = $._tokenContext[tokenId][ctxHash];
    if (checkReadyForDetachment) {
        uint64 readyForDetachmentAt = $tokenContext.readyForDetachmentAt;
        if (readyForDetachmentAt == 0) {
            revert REP15NotRequestedForDetachment(ctxHash, tokenId);  // ← wrong error
        }
        ...
    }
    // No prior check: if (!$tokenContext.attached) revert REP15NonexistentAttachedContext(...)
```

For a context that is not attached (never was, or was previously detached), the `_tokenContext` struct is zeroed — `attached == false` and `readyForDetachmentAt == 0`. The `readyForDetachmentAt == 0` guard fires first, producing `REP15NotRequestedForDetachment`. The correct error is `REP15NonexistentAttachedContext`.

By contrast, `requestDetachContext` (when called by the ownership manager) correctly delegates to `_requireAttachedTokenContext` which checks `attached` first.

#### Impact

Off-chain integrators (wallets, dApp front-ends, indexers) that distinguish between `REP15NotRequestedForDetachment` ("a detach request is needed before executing") and `REP15NonexistentAttachedContext` ("this context is not attached at all") may take incorrect recovery actions. For example, a UI might prompt the user to call `requestDetachContext` on a context that doesn't exist, producing another misleading error.

#### Recommendation

In `_detachContext`, check attachment before checking `readyForDetachmentAt` when `checkReadyForDetachment` is true:

```solidity
function _detachContext(..., bool checkReadyForDetachment, ...) internal {
    ...
    REP15Utils.TokenContext storage $tokenContext = $._tokenContext[tokenId][ctxHash];

    // Attachment check should always precede readiness check
    if (checkReadyForDetachment && !$tokenContext.attached) {
        revert REP15NonexistentAttachedContext(ctxHash, tokenId);
    }

    if (checkReadyForDetachment) {
        uint64 readyForDetachmentAt = $tokenContext.readyForDetachmentAt;
        if (readyForDetachmentAt == 0) revert REP15NotRequestedForDetachment(ctxHash, tokenId);
        if (readyForDetachmentAt > block.timestamp) revert REP15UnreadyForDetachment(...);
    }
    ...
}
```

Alternatively, always check attachment at the top of `_detachContext` regardless of `checkReadyForDetachment`, since detaching a non-attached context is always invalid.

Add test: `test_execDetachContext_RevertWhen_NotAttachedContext` asserting `REP15NonexistentAttachedContext`.

#### Triager Validation

**Technical Verification:**
- Confirmed: `_detachContext` in both `REP15.sol` and `REP15Upgradeable.sol` checks `readyForDetachmentAt == 0` before any `attached` check.
- Confirmed: the existing test `test_execDetachContext_RevertWhen_NotRequested` uses `withContext(NOT_REQUESTED)` — a context that IS attached but has no pending request. This correctly exercises `REP15NotRequestedForDetachment`. The missing test case is `execDetachContext` on a completely non-attached context.
- No existing test covers `execDetachContext` on a non-attached context asserting `REP15NonexistentAttachedContext`.

**VALID:** The wrong error is confirmed. The finding is Low because it does not lead to fund loss, but it produces incorrect error messages that will confuse integrators.

---

### I-1: Authorization Check After Delegation State Query in `startDelegateOwnership`

**Severity:** Informational
**Type:** Auth Order / Information Leakage
**Location:** `src/REP15Upgradeable.sol:73-93`, `src/REP15.sol` (same pattern)
**Status:** Acknowledged

#### Description

In `startDelegateOwnership`, the delegation state check precedes the caller authorization check:

```solidity
function startDelegateOwnership(uint256 tokenId, address delegatee, uint64 until) external virtual {
    _beforeOwnershipDelegation();
    address owner = ownerOf(tokenId);
    if (delegatee == owner || delegatee == address(0)) revert REP15InvalidDelegatee(delegatee);
    if (until <= block.timestamp) revert REP15InvalidDelegationExpiration(until);

    REP15Utils.Delegation storage $delegation = _getREP15Storage()._delegations[tokenId];
    if ($delegation.isActive()) {
        revert REP15AlreadyDelegatedOwnership(...);  // fires before auth check
    }

    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: ...");  // auth check is last
```

An unauthorized caller can probe whether a token has an active delegation by calling `startDelegateOwnership` with any valid `delegatee` and `until` and observing whether they receive `REP15AlreadyDelegatedOwnership` (delegation is active) or "ERC721: caller is not token owner or approved" (no active delegation).

#### Impact

Negligible. This information is already publicly accessible via `getOwnershipDelegatee()` (reverts with `REP15InactiveOwnershipDelegation` if no active delegation exists). No funds are at risk.

#### Recommendation

Reorder checks so authorization precedes state queries:

```solidity
require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: ...");
if ($delegation.isActive()) revert REP15AlreadyDelegatedOwnership(...);
```

This matches the typical secure coding convention of "check authorization before reading sensitive state."

#### Triager Validation

**ACKNOWLEDGED:** State information is already public. No practical exploit exists. Fix is cosmetic — consistent ordering is a code quality improvement.

---

### I-2: Redundant `_attachedContexts` Storage in Enumerable Extension

**Severity:** Informational
**Type:** Design / Gas Efficiency
**Locations:**
- `src/REP15Upgradeable.sol:591-613` (`_addAttachedContext`, `_removeAttachedContext`)
- `src/extensions/REP15EnumerableUpgradeable.sol:101-123` (`_afterAttachContext`, `_afterDetachContext`)
**Status:** Acknowledged

#### Description

`REP15Upgradeable` maintains `_attachedContexts[tokenId]` and `_attachedContextsIndex[tokenId]` within its ERC-7201 storage struct for the backward-iteration and swap-and-pop operations used in `_detachAllContexts`. `REP15EnumerableUpgradeable` adds an identically named pair in its own ERC-7201 storage struct, maintained in parallel through the `_afterAttachContext` / `_afterDetachContext` virtual hook chain.

When `REP15EnumerableUpgradeable` is in use, every `attachContext` call writes to two storage locations, and every detach writes to two more. This doubles the `SSTORE` count for the mapping updates on each attach/detach.

#### Impact

Increased gas cost only. No security impact. The duplication is functionally correct — both arrays are kept in sync, and the enumerable array serves external queries while the base-class array drives `_detachAllContexts`. However, the base-class array is `private`, so the enumerable extension cannot reuse it.

#### Recommendation

Consider whether the base-class `_attachedContexts` is strictly necessary, or whether `_detachAllContexts` can delegate to a virtual internal getter that enumerable contracts can override to supply their own array. This would eliminate the redundancy. Since the base class array is `private`, any restructuring would require making it `internal` or providing an internal virtual hook for `_detachAllContexts`.

This is a design trade-off that may be acceptable given the clarity it provides for the base implementation.

#### Triager Validation

**ACKNOWLEDGED:** Gas inefficiency only. No security impact. Storage slot verification confirms no collision between the two ERC-7201 slots.

---

## Appendix: Storage Slot Verification

Both ERC-7201 storage slot constants were verified by independent computation:

| Contract | Namespace | Expected | Computed | Match |
|---|---|---|---|---|
| `REP15Upgradeable` | `axieinfinity.storage.REP15Upgradeable` | `0x2d8b...6b00` | `0x2d8b...6b00` | ✓ |
| `REP15EnumerableUpgradeable` | `axieinfinity.storage.REP15EnumerableUpgradeable` | `0x6e70...9400` | `0x6e70...9400` | ✓ |

No storage collisions detected.

## Appendix: Test Suite

All 202 tests pass across 13 test suites. No flaky tests observed. Coverage gaps identified:

- No test for `transferFrom` while paused (L-1)
- No test for `execDetachContext` on a completely non-attached context (L-2)
- No reentrancy test exercising the ghost context injection path (M-1)
