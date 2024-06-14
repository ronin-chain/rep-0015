// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IREP15Errors {
  /**
   * @dev Indicates a token is already delegated ownership. Used in delegating ownership.
   * @param tokenId Identifier number of the token.
   * @param delegatee Address of the delegatee.
   * @param until The timestamp until the delegation is valid.
   */
  error REP15AlreadyDelegatedOwnership(uint256 tokenId, address delegatee, uint64 until);

  /**
   * @dev Indicates a token has an inactive ownership delegation. Used in delegating ownership.
   * This may be caused by the delegation is not existent or expired, or the delegation is not accepted yet.
   * @param tokenId Identifier number of the token.
   */
  error REP15InactiveOwnershipDelegation(uint256 tokenId);

  /**
   * @dev Indicates a token has no pending ownership delegation. Used in delegating ownership.
   * This may be caused by the delegation is not existent or expired, or the delegation is already accepted.
   * @param tokenId Identifier number of the token.
   */
  error REP15NonexistentPendingOwnershipDelegation(uint256 tokenId);

  /**
   * @dev Indicates a failure with the context `controller`. For example, caller is an unauthorized controller or
   * when setting the controller to zero address. Used in context management.
   * @param controller Address of the controller.
   */
  error REP15InvalidController(address controller);

  /**
   * @dev Indicates `detachingDuration` exceeds the maximum detaching duration. Used in context management.
   * @param detachingDuration The duration must be waited for detachment in second(s).
   */
  error REP15ExceededMaxDetachingDuration(uint64 detachingDuration);

  /**
   * @dev Indicates a failure with the `operator`’s approval. Used in authorization of REP15.
   * @param operator Address that may be allowed to operate on tokens without being their ownership manager.
   * @param tokenId Identifier number of a token.
   */
  error REP15InsufficientApproval(address operator, uint256 tokenId);

  /**
   * @dev Indicates a context is already attached. Used in attaching a token to a context.
   * @param ctxHash Hash of the context.
   * @param tokenId Identifier number of the token.
   */
  error REP15AlreadyAttachedContext(bytes32 ctxHash, uint256 tokenId);

  /**
   * @dev Indicates that have not waited enough time for detachment . Used in detaching a token from a context.
   * @param ctxHash Hash of the context.
   * @param tokenId Identifier number of the token.
   * @param current The current timestamp.
   * @param readyAt The timestamp when the token is ready for detachment.
   */
  error REP15UnreadyForDetachment(bytes32 ctxHash, uint256 tokenId, uint64 current, uint64 readyAt);

  /**
   * @dev Indicates a context is already existent. Used in creating context.
   * @param ctxHash Hash of the context.
   */
  error REP15ExistentContext(bytes32 ctxHash);

  /**
   * @dev Indicates a context is not existent yet. Used in getting context.
   * @param ctxHash Hash of the context.
   */
  error REP15NonexistentContext(bytes32 ctxHash);

  /**
   * @dev Indicates a context is not active, i.e., nonexistent or deprecated.
   * @param ctxHash Hash of the context.
   */
  error REP15InactiveContext(bytes32 ctxHash);

  /**
   * @dev Indicates a token context is not existent.
   * @param ctxHash Hash of the context.
   * @param tokenId Identifier number of the token.
   */
  error REP15NonexistentAttachedContext(bytes32 ctxHash, uint256 tokenId);

  /**
   * @dev Indicates a failure with the context `user`.
   * @param user Address of the user.
   */
  error REP15InvalidContextUser(address user);

  /**
   * Indicates an action is forbidden when a token context is requested for detachment.
   * @param ctxHash Hash of the context.
   * @param tokenId Identifier number of the token.
   */
  error REP15RequestedForDetachment(bytes32 ctxHash, uint256 tokenId);

  /**
   * Indicates an action is forbidden when a token context is not requested for detachment.
   * @param ctxHash Hash of the context.
   * @param tokenId Identifier number of the token.
   */
  error REP15NotRequestedForDetachment(bytes32 ctxHash, uint256 tokenId);
}
