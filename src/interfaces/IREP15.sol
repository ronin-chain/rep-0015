// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// Note: the ERC-165 identifier for this interface is 0xba63ebbb.
interface IREP15 is IERC165 {
  /// @dev This emits when a context is updated by any mechanism.
  event ContextUpdated(bytes32 indexed ctxHash, address indexed controller, uint64 detachingDuration);
  /// @dev This emits when a token is attached to a certain context by any mechanism.
  event ContextAttached(bytes32 indexed ctxHash, uint256 indexed tokenId);
  /// @dev This emits when a token is requested to detach from a certain context by any mechanism.
  event ContextDetachmentRequested(bytes32 indexed ctxHash, uint256 indexed tokenId);
  /// @dev This emits when a token is detached from a certain context by any mechanism.
  event ContextDetached(bytes32 indexed ctxHash, uint256 indexed tokenId);
  /// @dev This emits when a user is assigned to a certain context by any mechanism.
  event ContextUserAssigned(bytes32 indexed ctxHash, uint256 indexed tokenId, address indexed user);
  /// @dev This emits when a token is (un)locked in a certain context by any mechanism.
  event ContextLockUpdated(bytes32 indexed ctxHash, uint256 indexed tokenId, bool locked);
  /// @dev This emits when the ownership delegation is started by any mechanism.
  event OwnershipDelegationStarted(uint256 indexed tokenId, address indexed delegatee, uint64 until);
  /// @dev This emits when the ownership delegation is accepted by any mechanism.
  event OwnershipDelegationAccepted(uint256 indexed tokenId, address indexed delegatee, uint64 until);
  /// @dev This emits when the ownership delegation is stopped by any mechanism.
  event OwnershipDelegationStopped(uint256 indexed tokenId, address indexed delegatee);

  /// @notice Gets the longest duration the detaching can happen.
  function maxDetachingDuration() external view returns (uint64);

  /// @notice Gets controller address and detachment duration of a context.
  /// @dev MUST revert if the context is not existent.
  /// @param ctxHash            A hash of context to query the controller.
  /// @return controller        The address of the context controller.
  /// @return detachingDuration The duration must be waited for detachment in second(s).
  function getContext(bytes32 ctxHash) external view returns (address controller, uint64 detachingDuration);

  /// @notice Creates a new context.
  /// @dev MUST revert if the context is already existent.
  /// MUST revert if the controller address is zero address.
  /// MUST revert if the detaching duration is larger than max detaching duration.
  /// MUST emit the event {ContextUpdated} to reflect context created and controller set.
  /// @param controller        The address that controls the created context.
  /// @param detachingDuration The duration must be waited for detachment in second(s).
  /// @param ctxMsg            The message of new context.
  /// @return ctxHash          Hash of the created context.
  function createContext(address controller, uint64 detachingDuration, bytes calldata ctxMsg)
    external
    returns (bytes32 ctxHash);

  /// @notice Updates an existing context.
  /// @dev MUST revert if method caller is not the current controller.
  /// MUST revert if the context is non-existent.
  /// MUST revert if the new controller address is zero address.
  /// MUST revert if the detaching duration is larger than max detaching duration.
  /// MUST emit the event {ContextUpdated} on success.
  /// @param ctxHash              Hash of the context to set.
  /// @param newController        The address of new controller.
  /// @param newDetachingDuration The new duration must be waited for detachment in second(s).
  function updateContext(bytes32 ctxHash, address newController, uint64 newDetachingDuration) external;

  /// @notice Queries if a token is attached to a certain context.
  /// @param ctxHash Hash of a context.
  /// @param tokenId The NFT to query.
  /// @return        True if the token is attached to the context, false if not.
  function isAttachedWithContext(bytes32 ctxHash, uint256 tokenId) external view returns (bool);

  /// @notice Attaches a token with a certain context.
  /// @dev See "attachContext rules" in "Token (Un)lock Rules".
  /// @param ctxHash Hash of a context.
  /// @param tokenId The NFT to be attached.
  /// @param data    Additional data with no specified format, MUST be sent unaltered in call to the {IREP15ContextCallback} hook(s) on controller.
  function attachContext(bytes32 ctxHash, uint256 tokenId, bytes calldata data) external;

  /// @notice Requests to detach a token from a certain context.
  /// @dev See "requestDetachContext rules" in "Token (Un)lock Rules".
  /// @param ctxHash Hash of a context.
  /// @param tokenId The NFT to be detached.
  /// @param data    Additional data with no specified format, MUST be sent unaltered in call to the {IREP15ContextCallback} hook(s) on controller.
  function requestDetachContext(bytes32 ctxHash, uint256 tokenId, bytes calldata data) external;

  /// @notice Executes context detachment.
  /// @dev See "execDetachContext rules" in "Token (Un)lock Rules".
  /// @param ctxHash Hash of a context.
  /// @param tokenId The NFT to be detached.
  /// @param data    Additional data with no specified format, MUST be sent unaltered in call to the {IREP15ContextCallback} hook(s) on controller.
  function execDetachContext(bytes32 ctxHash, uint256 tokenId, bytes calldata data) external;

  /// @notice Finds the context user of a token.
  /// @param ctxHash Hash of a context.
  /// @param tokenId The NFT to be detached.
  /// @return user   Address of the context user.
  function getContextUser(bytes32 ctxHash, uint256 tokenId) external view returns (address user);

  /// @notice Updates the context user of a token.
  /// @dev MUST revert if the method caller is not context controller.
  /// MUST revert if the context is non-existent.
  /// MUST revert if the token is not attached to the context.
  /// MUST emit the event {ContextUserAssigned} on success.
  /// @param ctxHash Hash of a context.
  /// @param tokenId The NFT to be update.
  /// @param user    Address of the new user.
  function setContextUser(bytes32 ctxHash, uint256 tokenId, address user) external;

  /// @notice Queries if the lock a token is locked in a certain context.
  /// @param ctxHash Hash of a context.
  /// @param tokenId The NFT to be queried.
  /// @return        True if the token context is locked, false if not.
  function isTokenContextLocked(bytes32 ctxHash, uint256 tokenId) external view returns (bool);

  /// @notice (Un)locks a token in a certain context.
  /// @dev See "setContextLock rules" in "Token (Un)lock Rules".
  /// @param ctxHash Hash of a context.
  /// @param tokenId The NFT to be queried.
  /// @param lock    New status to be (un)locked.
  function setContextLock(bytes32 ctxHash, uint256 tokenId, bool lock) external;

  /// @notice Finds the ownership manager of a specified token.
  /// @param tokenId  The NFT to be queried.
  /// @return manager Address of delegatee.
  function getOwnershipManager(uint256 tokenId) external view returns (address manager);

  /// @notice Finds the ownership delegatee of a token.
  /// @dev MUST revert if there is no (or an expired) ownership delegation.
  /// @param tokenId    The NFT to be queried.
  /// @return delegatee Address of delegatee.
  /// @return until     The delegation expiry time.
  function getOwnershipDelegatee(uint256 tokenId) external view returns (address delegatee, uint64 until);

  /// @notice Finds the pending ownership delegatee of a token.
  /// @dev MUST revert if there is no (or an expired) pending ownership delegation.
  /// @param tokenId    The NFT to be queried.
  /// @return delegatee Address of pending delegatee.
  /// @return until     The delegation expiry time in the future.
  function pendingOwnershipDelegatee(uint256 tokenId) external view returns (address delegatee, uint64 until);

  /// @notice Starts ownership delegation and retains ownership until a specific timestamp.
  /// @dev Replaces the pending delegation if any.
  /// See "startDelegateOwnership rules" in "Ownership Delegation Rules".
  /// @param tokenId   The NFT to be delegated.
  /// @param delegatee Address of new delegatee.
  /// @param until     The delegation expiry time.
  function startDelegateOwnership(uint256 tokenId, address delegatee, uint64 until) external;

  /// @notice Accepts ownership delegation request.
  /// @dev See "acceptOwnershipDelegation rules" in "Ownership Delegation Rules".
  /// @param tokenId The NFT to be accepted.
  function acceptOwnershipDelegation(uint256 tokenId) external;

  /// @notice Stops the current ownership delegation.
  /// @dev See "stopOwnershipDelegation rules" in "Ownership Delegation Rules".
  /// @param tokenId The NFT to be stopped.
  function stopOwnershipDelegation(uint256 tokenId) external;
}
