// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC165, ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC721, ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IREP15 } from "./interfaces/IREP15.sol";
import { IREP15Errors } from "./interfaces/IREP15Errors.sol";
import { IREP15ContextCallback } from "./interfaces/IREP15ContextCallback.sol";
import { REP15Utils } from "./REP15Utils.sol";

abstract contract REP15 is ERC721, IREP15, IREP15Errors {
  using REP15Utils for REP15Utils.Delegation;
  using REP15Utils for REP15Utils.Context;
  using REP15Utils for REP15Utils.TokenContext;

  uint64 internal immutable _MAX_DETACHING_DURATION;

  mapping(uint256 tokenId => REP15Utils.Delegation) private _delegations;

  mapping(bytes32 ctxHash => REP15Utils.Context) private _contexts;

  mapping(uint256 tokenId => mapping(bytes32 ctxHash => REP15Utils.TokenContext)) private _tokenContext;

  mapping(uint256 tokenId => bytes32[] ctxHashes) internal _attachedContexts;

  mapping(uint256 tokenId => mapping(bytes32 ctxHash => uint256 index)) internal _attachedContextsIndex;

  constructor(uint64 maxDetachingDurationSeconds) {
    _MAX_DETACHING_DURATION = maxDetachingDurationSeconds;
  }

  /**
   * @inheritdoc IERC165
   */
  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
    return interfaceId == type(IREP15).interfaceId || super.supportsInterface(interfaceId);
  }

  /**
   * @inheritdoc IREP15
   */
  function startDelegateOwnership(uint256 tokenId, address delegatee, uint64 until) public virtual {
    address owner = _requireOwned(tokenId);

    if (delegatee == owner || delegatee == address(0)) revert REP15InvalidDelegatee(delegatee);

    if (until <= block.timestamp) revert REP15InvalidDelegationExpiration(until);

    REP15Utils.Delegation storage $delegation = _delegations[tokenId];

    if ($delegation.isActive()) {
      revert REP15AlreadyDelegatedOwnership(tokenId, $delegation.delegatee, $delegation.until);
    }

    ERC721._checkAuthorized(owner, _msgSender(), tokenId);

    $delegation.delegatee = delegatee;
    $delegation.until = until;

    emit OwnershipDelegationStarted(tokenId, delegatee, until);
  }

  /**
   * @inheritdoc IREP15
   */
  function acceptOwnershipDelegation(uint256 tokenId) public virtual {
    REP15Utils.Delegation storage $delegation = _delegations[tokenId];
    address delegatee = $delegation.delegatee;
    uint64 until = $delegation.until;

    if (!$delegation.isPending()) revert REP15NonexistentPendingOwnershipDelegation(tokenId);

    _checkAuthorizedDelegatee(delegatee, _msgSender(), tokenId);

    $delegation.delegated = true;

    emit OwnershipDelegationAccepted(tokenId, delegatee, until);
  }

  /**
   * @inheritdoc IREP15
   */
  function stopOwnershipDelegation(uint256 tokenId) public virtual {
    REP15Utils.Delegation storage $delegation = _delegations[tokenId];
    address delegatee = $delegation.delegatee;

    if (!$delegation.isActive()) revert REP15InactiveOwnershipDelegation(tokenId);

    _checkAuthorizedDelegatee(delegatee, _msgSender(), tokenId);

    delete _delegations[tokenId];

    emit OwnershipDelegationStopped(tokenId, delegatee);
  }

  /**
   * @inheritdoc IREP15
   */
  function createContext(address controller, uint64 detachingDuration, bytes calldata ctxMsg)
    external
    virtual
    returns (bytes32 ctxHash)
  {
    ctxHash = keccak256(abi.encode(_msgSender(), ctxMsg));

    _updateContext(ctxHash, controller, detachingDuration, address(0));
  }

  /**
   * @inheritdoc IREP15
   */
  function updateContext(bytes32 ctxHash, address newController, uint64 newDetachingDuration) external virtual {
    _updateContext(ctxHash, newController, newDetachingDuration, _msgSender());
  }

  /**
   * @inheritdoc IREP15
   */
  function attachContext(bytes32 ctxHash, uint256 tokenId, bytes calldata data) external virtual {
    address operator = _msgSender();

    _checkAuthorizedOwnershipManager(tokenId, operator);

    _attachContext(ctxHash, tokenId, operator, data);
  }

  /**
   * @inheritdoc IREP15
   */
  function requestDetachContext(bytes32 ctxHash, uint256 tokenId, bytes calldata data) external virtual {
    address operator = _msgSender();

    if (operator != _contexts[ctxHash].controller) {
      _checkAuthorizedOwnershipManager(tokenId, operator);
      _requestDetachContext(ctxHash, tokenId, operator, data);
    } else {
      // _detachContext(ctxHash, tokenId, operator, data, false, true);
      _detachContext({
        ctxHash: ctxHash,
        tokenId: tokenId,
        operator: operator,
        data: data,
        checkReadyForDetachment: false,
        emitEvent: true
      });
    }
  }

  /**
   * @inheritdoc IREP15
   */
  function execDetachContext(bytes32 ctxHash, uint256 tokenId, bytes calldata data) external virtual {
    address operator = _msgSender();

    _checkAuthorizedOwnershipManager(tokenId, operator);

    _detachContext(ctxHash, tokenId, operator, data, true, true);
  }

  /**
   * @inheritdoc IREP15
   */
  function setContextLock(bytes32 ctxHash, uint256 tokenId, bool lock) external virtual {
    _checkAuthorizedController(_msgSender(), ctxHash);

    _requireAttachedTokenContext(ctxHash, tokenId, true).locked = lock;

    emit ContextLockUpdated(ctxHash, tokenId, lock);
  }

  /**
   * @inheritdoc IREP15
   */
  function setContextUser(bytes32 ctxHash, uint256 tokenId, address user) external virtual {
    _checkAuthorizedController(_msgSender(), ctxHash);

    _requireAttachedTokenContext(ctxHash, tokenId, false).user = user;

    emit ContextUserAssigned(ctxHash, tokenId, user);
  }

  /**
   * @inheritdoc IREP15
   */
  function maxDetachingDuration() public view virtual override returns (uint64) {
    return _MAX_DETACHING_DURATION;
  }

  /**
   * @inheritdoc IREP15
   */
  function getContext(bytes32 ctxHash) external view virtual returns (address controller, uint64 detachingDuration) {
    REP15Utils.Context storage $context = _contexts[ctxHash];

    if (!$context.isExistent()) revert REP15NonexistentContext(ctxHash);

    return ($context.controller, $context.detachingDuration);
  }

  /**
   * @inheritdoc IREP15
   */
  function isAttachedWithContext(bytes32 ctxHash, uint256 tokenId) external view virtual returns (bool) {
    return _tokenContext[tokenId][ctxHash].attached;
  }

  /**
   * @inheritdoc IREP15
   */
  function getContextUser(bytes32 ctxHash, uint256 tokenId) external view virtual returns (address user) {
    return _tokenContext[tokenId][ctxHash].user;
  }

  /**
   * @inheritdoc IREP15
   */
  function isTokenContextLocked(bytes32 ctxHash, uint256 tokenId) external view virtual returns (bool) {
    return _tokenContext[tokenId][ctxHash].locked;
  }

  /**
   * @inheritdoc IREP15
   */
  function getOwnershipManager(uint256 tokenId) public view virtual returns (address manager) {
    REP15Utils.Delegation storage $delegation = _delegations[tokenId];

    if ($delegation.isActive()) return _delegations[tokenId].delegatee;

    return _requireOwned(tokenId);
  }

  /**
   * @inheritdoc IREP15
   */
  function getOwnershipDelegatee(uint256 tokenId) external view virtual returns (address delegatee, uint64 until) {
    REP15Utils.Delegation storage $delegation = _delegations[tokenId];

    if (!$delegation.isActive()) revert REP15InactiveOwnershipDelegation(tokenId);

    return ($delegation.delegatee, $delegation.until);
  }

  /**
   * @inheritdoc IREP15
   */
  function pendingOwnershipDelegatee(uint256 tokenId) external view virtual returns (address delegatee, uint64 until) {
    REP15Utils.Delegation storage $delegation = _delegations[tokenId];

    if (!$delegation.isPending()) revert REP15NonexistentPendingOwnershipDelegation(tokenId);

    return ($delegation.delegatee, $delegation.until);
  }

  /**
   * @dev Ensures the context is existent and returns the controller of the context `ctxHash`.
   */
  function _requireControlled(bytes32 ctxHash) internal view returns (address controller) {
    controller = _contexts[ctxHash].controller;
    if (controller == address(0)) revert REP15NonexistentContext(ctxHash);
  }

  /**
   * @dev Checks if the context is active and `controller` is the controller of the context `ctxHash`.
   */
  function _checkAuthorizedController(address controller, bytes32 ctxHash) internal view virtual {
    if (controller != _requireControlled(ctxHash)) revert REP15InvalidController(controller);
  }

  /**
   * @dev Internal function to create or update a context.
   *
   * The `auth` argument is optional. If the value passed is non 0, then this function will check that
   * `auth` is the controller of `ctxHash` before updating the context.
   *
   * Emits a {ContextUpdated} event.
   */
  function _updateContext(bytes32 ctxHash, address controller, uint64 detachingDuration, address auth) internal virtual {
    if (controller == address(0)) revert REP15InvalidController(address(0));
    if (detachingDuration > maxDetachingDuration()) revert REP15ExceededMaxDetachingDuration(detachingDuration);

    REP15Utils.Context storage $context = _contexts[ctxHash];

    if (auth != address(0)) {
      // Updating context
      _checkAuthorizedController(auth, ctxHash);
    } else {
      // Creating context
      if ($context.controller != address(0)) revert REP15ExistentContext(ctxHash);
    }

    $context.controller = controller;
    $context.detachingDuration = detachingDuration;

    emit ContextUpdated(ctxHash, controller, detachingDuration);
  }

  /**
   * @dev Ensures the context is attached to the token and returns the token context storage pointer.
   * If `checkNotRequestedForDetachment` is true, this function will check that the context has not requested for detachment.
   */
  function _requireAttachedTokenContext(bytes32 ctxHash, uint256 tokenId, bool checkNotRequestedForDetachment)
    internal
    view
    returns (REP15Utils.TokenContext storage $tokenContext)
  {
    $tokenContext = _tokenContext[tokenId][ctxHash];

    if (!$tokenContext.attached) revert REP15NonexistentAttachedContext(ctxHash, tokenId);

    if (checkNotRequestedForDetachment && $tokenContext.hasRequestedForDetachment()) {
      revert REP15RequestedForDetachment(ctxHash, tokenId);
    }
  }

  /**
   * @dev Ensures the context is not attached to the token and returns the token context storage pointer.
   */
  function _requireNotAttachedTokenContext(bytes32 ctxHash, uint256 tokenId)
    internal
    view
    returns (REP15Utils.TokenContext storage $tokenContext)
  {
    $tokenContext = _tokenContext[tokenId][ctxHash];

    if ($tokenContext.attached) revert REP15AlreadyAttachedContext(ctxHash, tokenId);
  }

  /**
   * @dev Attaches a context to a token.
   */
  function _attachContext(bytes32 ctxHash, uint256 tokenId, address operator, bytes calldata data) internal {
    address controller = _requireControlled(ctxHash);

    _requireNotAttachedTokenContext(ctxHash, tokenId).attached = true;
    _addAttachedContext(tokenId, ctxHash);

    emit ContextAttached(ctxHash, tokenId);

    if (controller.code.length > 0) {
      IREP15ContextCallback(controller).onAttached(ctxHash, tokenId, operator, data);
    }
  }

  /**
   * @dev Requests detachment of a context from a token.
   */
  function _requestDetachContext(bytes32 ctxHash, uint256 tokenId, address operator, bytes calldata data) internal {
    REP15Utils.TokenContext storage $tokenContext = _requireAttachedTokenContext(ctxHash, tokenId, true);

    if (!$tokenContext.locked) {
      _detachContext(ctxHash, tokenId, operator, data, false, true);
      return;
    }

    $tokenContext.readyForDetachmentAt = uint64(block.timestamp) + _contexts[ctxHash].detachingDuration;

    emit ContextDetachmentRequested(ctxHash, tokenId);

    address controller = _contexts[ctxHash].controller;
    if (controller.code.length > 0) {
      try IREP15ContextCallback(controller).onDetachRequested(ctxHash, tokenId, operator, data) { } catch { }
    }
  }

  /**
   * @dev Detaches a context from a token.
   * If `checkReadyForDetachment` is true, this function will check if the context is ready for detachment.
   */
  function _detachContext(
    bytes32 ctxHash,
    uint256 tokenId,
    address operator,
    bytes memory data,
    bool checkReadyForDetachment,
    bool emitEvent
  ) internal {
    if (checkReadyForDetachment) {
      uint64 readyForDetachmentAt = _tokenContext[tokenId][ctxHash].readyForDetachmentAt;

      if (readyForDetachmentAt == 0) {
        revert REP15NotRequestedForDetachment(ctxHash, tokenId);
      }

      if (readyForDetachmentAt > block.timestamp) {
        revert REP15UnreadyForDetachment(ctxHash, tokenId, uint64(block.timestamp), readyForDetachmentAt);
      }
    }

    delete _tokenContext[tokenId][ctxHash];
    _removeAttachedContext(tokenId, ctxHash);

    if (emitEvent) emit ContextDetached(ctxHash, tokenId);

    address controller = _contexts[ctxHash].controller;
    if (controller.code.length > 0) {
      try IREP15ContextCallback(controller).onExecDetachContext(ctxHash, tokenId, operator, data) { } catch { }
    }
  }

  /**
   * @dev Overrides the internal `_update` function to revoke ownership delegation and detach all attached contexts
   * in case of transfers or burns.
   *
   * If `auth` is non-zero and this function will check if `auth` is the ownership manager, an authorized operator of
   * ownership manager, or the approved address for this NFT (if the token is not being delegated).
   */
  function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
    if (auth != address(0)) {
      _checkAuthorizedOwnershipManager(tokenId, auth);
    }

    if (auth != address(0) || to == address(0)) {
      // Revoke current ownership delegation if any.
      // No need to check if the delegation is active or emit the OwnershipDelegationStopped event.
      delete _delegations[tokenId];

      // Detach all attached contexts. No need to emit the ContextDetached event.
      bytes32[] storage attachedContexts = _attachedContexts[tokenId];
      for (int256 i = int256(attachedContexts.length) - 1; i >= 0; --i) {
        bytes32 ctxHash = attachedContexts[uint256(i)];
        _detachContext(ctxHash, tokenId, auth, "", _tokenContext[tokenId][ctxHash].locked, false);
      }
    }

    return super._update(to, tokenId, address(0));
  }

  /**
   * @dev Checks if the `delegatee` is the owner or an approved operator of the `tokenId`.
   */
  function _checkAuthorizedDelegatee(address delegatee, address operator, uint256 tokenId) internal view virtual {
    if (!(delegatee == operator || isApprovedForAll(delegatee, operator))) {
      revert REP15InsufficientApproval(operator, tokenId);
    }
  }

  /**
   * @dev Checks if the `operator` is the ownership manager, an authorized operator of ownership manager,
   * or the approved address for this NFT (if the token is not being delegated).
   */
  function _checkAuthorizedOwnershipManager(uint256 tokenId, address operator) internal view virtual {
    REP15Utils.Delegation storage $delegation = _delegations[tokenId];

    if (!$delegation.isActive()) {
      ERC721._checkAuthorized(_ownerOf(tokenId), operator, tokenId);
      return;
    }

    _checkAuthorizedDelegatee($delegation.delegatee, operator, tokenId);
  }

  /**
   * @dev Adds a context to the attached context enumeration of a token.
   */
  function _addAttachedContext(uint256 tokenId, bytes32 ctxHash) private {
    _attachedContextsIndex[tokenId][ctxHash] = _attachedContexts[tokenId].length;
    _attachedContexts[tokenId].push(ctxHash);
  }

  /**
   * @dev Removes a context from the attached context enumeration of a token.
   */
  function _removeAttachedContext(uint256 tokenId, bytes32 ctxHash) private {
    bytes32[] storage attachedContexts = _attachedContexts[tokenId];
    mapping(bytes32 ctxHash => uint256 index) storage attachedContextsIndex = _attachedContextsIndex[tokenId];

    uint256 contextIndex = attachedContextsIndex[ctxHash];
    bytes32 lastContext = attachedContexts[attachedContexts.length - 1];

    attachedContexts[contextIndex] = lastContext;
    attachedContextsIndex[lastContext] = contextIndex;

    attachedContexts.pop();
    delete attachedContextsIndex[ctxHash];
  }
}
