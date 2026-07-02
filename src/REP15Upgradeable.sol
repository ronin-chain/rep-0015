// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Initializable } from "@openzeppelin-upgradeable-v4/proxy/utils/Initializable.sol";
import { ERC721Upgradeable } from "@openzeppelin-upgradeable-v4/token/ERC721/ERC721Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin-upgradeable-v4/security/PausableUpgradeable.sol";
import { ERC165Upgradeable } from "@openzeppelin-upgradeable-v4/utils/introspection/ERC165Upgradeable.sol";
import { IERC165 } from "@openzeppelin-v4/utils/introspection/IERC165.sol";
import { REP15Utils } from "./REP15Utils.sol";
import { IREP15 } from "./interfaces/IREP15.sol";
import { IREP15Errors } from "./interfaces/IREP15Errors.sol";
import { IREP15ContextCallback } from "./interfaces/IREP15ContextCallback.sol";

contract REP15Upgradeable is Initializable, ERC721Upgradeable, PausableUpgradeable, IREP15, IREP15Errors {
  using REP15Utils for REP15Utils.Delegation;
  using REP15Utils for REP15Utils.Context;
  using REP15Utils for REP15Utils.TokenContext;

  /// @custom:storage-location erc7201:axieinfinity.storage.REP15Upgradeable
  struct REP15Storage {
    mapping(uint256 tokenId => REP15Utils.Delegation) _delegations;
    mapping(bytes32 ctxHash => REP15Utils.Context) _contexts;
    mapping(uint256 tokenId => mapping(bytes32 ctxHash => REP15Utils.TokenContext)) _tokenContext;
    mapping(uint256 tokenId => bytes32[] ctxHashes) _attachedContexts;
    mapping(uint256 tokenId => mapping(bytes32 ctxHash => uint256 index)) _attachedContextsIndex;
  }

  /// @dev Value is equal to keccak256(abi.encode(uint256(keccak256("axieinfinity.storage.REP15Upgradeable")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant $$_REP15StorageLocation = 0x2d8b96ed06e1e4e698120e91bb5a55b8ef8d39e3d6e06d21c184ee4f24dd6b00;

  /// @dev Return `REP15Storage` at storage slot `REP15StorageLocation`.
  function _getREP15Storage() private pure returns (REP15Storage storage $) {
    assembly ("memory-safe") {
      $.slot := $$_REP15StorageLocation
    }
  }

  function __REP15_init() internal onlyInitializing { }

  function __REP15_init_unchained() internal onlyInitializing { }

  modifier onlyOwnershipManager(uint256 tokenId) {
    _checkAuthorizedOwnershipManager(tokenId, _msgSender());
    _;
  }

  modifier onlyController(bytes32 ctxHash) {
    _checkAuthorizedController(_msgSender(), ctxHash);
    _;
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721Upgradeable, IERC165)
    returns (bool)
  {
    return interfaceId == type(IREP15).interfaceId || super.supportsInterface(interfaceId);
  }

  /**
   * @inheritdoc IREP15
   */
  function startDelegateOwnership(uint256 tokenId, address delegatee, uint64 until) external whenNotPaused {
    address owner = ownerOf(tokenId);

    if (delegatee == owner || delegatee == address(0)) revert REP15InvalidDelegatee(delegatee);

    if (until <= block.timestamp) revert REP15InvalidDelegationExpiration(until);

    REP15Utils.Delegation storage $delegation = _getREP15Storage()._delegations[tokenId];

    if ($delegation.isActive()) {
      revert REP15AlreadyDelegatedOwnership(tokenId, $delegation.delegatee, $delegation.until);
    }

    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");

    $delegation.delegatee = delegatee;
    $delegation.until = until;
    $delegation.delegated = false;

    emit OwnershipDelegationStarted(tokenId, delegatee, until);
  }

  /**
   * @inheritdoc IREP15
   */
  function acceptOwnershipDelegation(uint256 tokenId) public virtual whenNotPaused {
    REP15Utils.Delegation storage $delegation = _requirePendingDelegation(tokenId);
    address delegatee = $delegation.delegatee;

    _checkAuthorizedDelegatee({ delegatee: delegatee, operator: _msgSender() });

    $delegation.delegated = true;

    emit OwnershipDelegationAccepted(tokenId, delegatee, $delegation.until);
  }

  /**
   * @inheritdoc IREP15
   */
  function stopOwnershipDelegation(uint256 tokenId) public virtual whenNotPaused {
    REP15Utils.Delegation storage $delegation = _requireActiveDelegation(tokenId);
    address delegatee = $delegation.delegatee;

    _checkAuthorizedDelegatee({ delegatee: delegatee, operator: _msgSender() });

    _removeDelegations(tokenId);

    emit OwnershipDelegationStopped(tokenId, delegatee);
  }

  /**
   * @inheritdoc IREP15
   */
  function createContext(address controller, uint64 detachingDuration, bytes calldata ctxMsg)
    external
    whenNotPaused
    returns (bytes32 ctxHash)
  {
    ctxHash = keccak256(abi.encode(_msgSender(), ctxMsg));

    _updateContext(ctxHash, controller, detachingDuration, address(0));
  }

  /**
   * @inheritdoc IREP15
   */
  function updateContext(bytes32 ctxHash, address newController, uint64 newDetachingDuration) external whenNotPaused {
    _updateContext(ctxHash, newController, newDetachingDuration, _msgSender());
  }

  /**
   * @inheritdoc IREP15
   */
  function attachContext(bytes32 ctxHash, uint256 tokenId, bytes calldata data)
    public
    onlyOwnershipManager(tokenId)
    whenNotPaused
  {
    _attachContext({ ctxHash: ctxHash, tokenId: tokenId, operator: _msgSender(), data: data });
  }

  /**
   * @inheritdoc IREP15
   */
  function requestDetachContext(bytes32 ctxHash, uint256 tokenId, bytes calldata data) external whenNotPaused {
    address operator = _msgSender();

    if (operator != _getREP15Storage()._contexts[ctxHash].controller) {
      _checkAuthorizedOwnershipManager(tokenId, operator);
      _requestDetachContext(ctxHash, tokenId, operator, data);
    } else {
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
  function execDetachContext(bytes32 ctxHash, uint256 tokenId, bytes calldata data)
    external
    onlyOwnershipManager(tokenId)
    whenNotPaused
  {
    _detachContext({
      ctxHash: ctxHash,
      tokenId: tokenId,
      operator: _msgSender(),
      data: data,
      checkReadyForDetachment: true,
      emitEvent: true
    });
  }

  /**
   * @inheritdoc IREP15
   */
  function setContextLock(bytes32 ctxHash, uint256 tokenId, bool lock)
    public
    virtual
    onlyController(ctxHash)
    whenNotPaused
  {
    _requireAttachedTokenContext({
      ctxHash: ctxHash, tokenId: tokenId, checkNotRequestedForDetachment: true
    }).locked = lock;

    emit ContextLockUpdated(ctxHash, tokenId, lock);
  }

  /**
   * @inheritdoc IREP15
   */
  function setContextUser(bytes32 ctxHash, uint256 tokenId, address user)
    external
    onlyController(ctxHash)
    whenNotPaused
  {
    _requireAttachedTokenContext({
      ctxHash: ctxHash, tokenId: tokenId, checkNotRequestedForDetachment: false
    }).user = user;

    emit ContextUserAssigned(ctxHash, tokenId, user);
  }

  /**
   * @inheritdoc IREP15
   */
  function maxDetachingDuration() public pure virtual override returns (uint64) {
    return 365 days;
  }

  /**
   * @inheritdoc IREP15
   */
  function getContext(bytes32 ctxHash) public view virtual returns (address controller, uint64 detachingDuration) {
    REP15Utils.Context storage $context = _requireExistentContext(ctxHash);

    return ($context.controller, $context.detachingDuration);
  }

  /**
   * @inheritdoc IREP15
   */
  function isAttachedWithContext(bytes32 ctxHash, uint256 tokenId) public view virtual returns (bool) {
    return _getREP15Storage()._tokenContext[tokenId][ctxHash].attached;
  }

  /**
   * @inheritdoc IREP15
   */
  function getContextUser(bytes32 ctxHash, uint256 tokenId) public view virtual returns (address user) {
    return _getREP15Storage()._tokenContext[tokenId][ctxHash].user;
  }

  /**
   * @inheritdoc IREP15
   */
  function isTokenContextLocked(bytes32 ctxHash, uint256 tokenId) public view virtual returns (bool) {
    return _getREP15Storage()._tokenContext[tokenId][ctxHash].locked;
  }

  /**
   * @inheritdoc IREP15
   */
  function getOwnershipManager(uint256 tokenId) public view virtual returns (address manager) {
    REP15Utils.Delegation storage $delegation = _getREP15Storage()._delegations[tokenId];

    if ($delegation.isActive()) return $delegation.delegatee;

    return ownerOf(tokenId);
  }

  /**
   * @inheritdoc IREP15
   */
  function getOwnershipDelegatee(uint256 tokenId) public view returns (address delegatee, uint64 until) {
    REP15Utils.Delegation storage $delegation = _requireActiveDelegation(tokenId);

    return ($delegation.delegatee, $delegation.until);
  }

  /**
   * @inheritdoc IREP15
   */
  function pendingOwnershipDelegatee(uint256 tokenId) public view returns (address delegatee, uint64 until) {
    REP15Utils.Delegation storage $delegation = _requirePendingDelegation(tokenId);

    return ($delegation.delegatee, $delegation.until);
  }

  /**
   * @dev Ensures the delegation is active and returns the delegation storage pointer.
   */
  function _requireActiveDelegation(uint256 tokenId) internal view returns (REP15Utils.Delegation storage $delegation) {
    $delegation = _getREP15Storage()._delegations[tokenId];
    if (!$delegation.isActive()) revert REP15InactiveOwnershipDelegation(tokenId);
  }

  /**
   * @dev Ensures the delegation is pending and returns the delegation storage pointer.
   */
  function _requirePendingDelegation(uint256 tokenId)
    internal
    view
    returns (REP15Utils.Delegation storage $delegation)
  {
    $delegation = _getREP15Storage()._delegations[tokenId];
    if (!$delegation.isPending()) revert REP15NonexistentPendingOwnershipDelegation(tokenId);
  }

  /**
   * @dev Ensures the context is existent and returns the context storage pointer.
   */
  function _requireExistentContext(bytes32 ctxHash) internal view returns (REP15Utils.Context storage $context) {
    $context = _getREP15Storage()._contexts[ctxHash];
    if (!$context.isExistent()) revert REP15NonexistentContext(ctxHash);
  }

  /**
   * @dev Checks if `controller` is the controller of the context `ctxHash`.
   */
  function _checkAuthorizedController(address controller, bytes32 ctxHash) internal view virtual {
    if (controller != _requireExistentContext(ctxHash).controller) revert REP15InvalidController(controller);
  }

  /**
   * @dev Internal function to create or update a context.
   *
   * The `auth` argument is optional. If the value passed is non 0, then this function will check that
   * `auth` is the controller of `ctxHash` before updating or deprecating the context.
   * If the value of `auth` is 0, then this method will implicitly create a new context, and will revert if the context already exists.
   *
   * Emits a {ContextUpdated} event.
   */
  function _updateContext(bytes32 ctxHash, address controller, uint64 detachingDuration, address auth)
    internal
    virtual
  {
    if (controller == address(0)) revert REP15InvalidController(address(0));
    if (detachingDuration > maxDetachingDuration()) revert REP15ExceededMaxDetachingDuration(detachingDuration);

    REP15Utils.Context storage $context = _getREP15Storage()._contexts[ctxHash];

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
    returns (REP15Utils.TokenContext storage tokenContext)
  {
    tokenContext = _getREP15Storage()._tokenContext[tokenId][ctxHash];

    if (!tokenContext.attached) revert REP15NonexistentAttachedContext(ctxHash, tokenId);

    if (checkNotRequestedForDetachment && tokenContext.hasRequestedForDetachment()) {
      revert REP15RequestedForDetachment(ctxHash, tokenId);
    }
  }

  /**
   * @dev Ensures the context is not attached to the token and returns the token context storage pointer.
   */
  function _requireNotAttachedTokenContext(bytes32 ctxHash, uint256 tokenId)
    internal
    view
    returns (REP15Utils.TokenContext storage tokenContext)
  {
    tokenContext = _getREP15Storage()._tokenContext[tokenId][ctxHash];

    if (tokenContext.attached) revert REP15AlreadyAttachedContext(ctxHash, tokenId);
  }

  /**
   * @dev Attaches a context to a token.
   */
  function _attachContext(bytes32 ctxHash, uint256 tokenId, address operator, bytes calldata data) internal {
    address controller = _requireExistentContext(ctxHash).controller;

    _requireNotAttachedTokenContext(ctxHash, tokenId).attached = true;
    _addAttachedContext(tokenId, ctxHash);

    emit ContextAttached(ctxHash, tokenId);

    _triggerContextCallback({
      controller: controller,
      callData: abi.encodeCall(IREP15ContextCallback.onAttached, (ctxHash, tokenId, operator, data)),
      allowFail: false
    });
  }

  /**
   * @dev Requests detachment of a context from a token.
   */
  function _requestDetachContext(bytes32 ctxHash, uint256 tokenId, address operator, bytes calldata data) internal {
    REP15Utils.TokenContext storage $tokenContext =
      _requireAttachedTokenContext({ ctxHash: ctxHash, tokenId: tokenId, checkNotRequestedForDetachment: true });

    if (!$tokenContext.locked) {
      _detachContext({
        ctxHash: ctxHash,
        tokenId: tokenId,
        operator: operator,
        data: data,
        checkReadyForDetachment: false,
        emitEvent: true
      });
      return;
    }

    REP15Utils.Context storage $context = _getREP15Storage()._contexts[ctxHash];
    $tokenContext.readyForDetachmentAt = uint64(block.timestamp) + $context.detachingDuration;

    emit ContextDetachmentRequested(ctxHash, tokenId);

    _triggerContextCallback({
      controller: $context.controller,
      callData: abi.encodeCall(IREP15ContextCallback.onDetachRequested, (ctxHash, tokenId, operator, data)),
      allowFail: true
    });
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
    REP15Storage storage $ = _getREP15Storage();
    REP15Utils.TokenContext storage $tokenContext = $._tokenContext[tokenId][ctxHash];
    if (checkReadyForDetachment) {
      uint64 readyForDetachmentAt = $tokenContext.readyForDetachmentAt;

      if (readyForDetachmentAt == 0) {
        revert REP15NotRequestedForDetachment(ctxHash, tokenId);
      }

      if (readyForDetachmentAt > block.timestamp) {
        revert REP15UnreadyForDetachment(ctxHash, tokenId, uint64(block.timestamp), readyForDetachmentAt);
      }
    }

    address contextUser = $tokenContext.user;
    delete $._tokenContext[tokenId][ctxHash];
    _removeAttachedContext(tokenId, ctxHash);

    if (emitEvent) emit ContextDetached(ctxHash, tokenId);

    _triggerContextCallback({
      controller: $._contexts[ctxHash].controller,
      callData: abi.encodeCall(
        IREP15ContextCallback.onExecDetachContext, (ctxHash, tokenId, contextUser, operator, data)
      ),
      allowFail: true
    });
  }

  /**
   * @dev Detaches all contexts from a token.
   */
  function _detachAllContexts(uint256 tokenId, address operator) internal virtual {
    REP15Storage storage $ = _getREP15Storage();
    bytes32[] storage $attachedContexts = $._attachedContexts[tokenId];
    int256 length = int256($attachedContexts.length);

    // skip if there are no attached contexts
    if (length == 0) return;
    bytes32 ctxHash;
    for (int256 i = length - 1; i >= 0; --i) {
      ctxHash = $attachedContexts[uint256(i)];
      _detachContext({
        ctxHash: ctxHash,
        tokenId: tokenId,
        operator: operator,
        data: "",
        checkReadyForDetachment: $._tokenContext[tokenId][ctxHash].locked,
        emitEvent: false
      });
    }
  }

  /**
   * @dev Removes the delegation of a token.
   */
  function _removeDelegations(uint256 tokenId) internal {
    delete _getREP15Storage()._delegations[tokenId];
  }

  /**
   * @dev Overrides `transferFrom` to check against the ownership manager instead of the standard ERC721 approval.
   */
  function transferFrom(address from, address to, uint256 tokenId) public virtual override {
    _checkAuthorizedOwnershipManager({ tokenId: tokenId, operator: _msgSender() });
    _transfer(from, to, tokenId);
  }

  /**
   * @dev Overrides `safeTransferFrom` to check against the ownership manager instead of the standard ERC721 approval.
   */
  function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
    _checkAuthorizedOwnershipManager({ tokenId: tokenId, operator: _msgSender() });
    _safeTransfer(from, to, tokenId, "");
  }

  /**
   * @dev Overrides `safeTransferFrom` to check against the ownership manager instead of the standard ERC721 approval.
   */
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override {
    _checkAuthorizedOwnershipManager({ tokenId: tokenId, operator: _msgSender() });
    _safeTransfer(from, to, tokenId, data);
  }

  /**
   * @dev Revokes ownership delegation and detaches all attached contexts before transfers or burns.
   * Mints (from == address(0)) are unaffected.
   */
  function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize)
    internal
    virtual
    override
  {
    super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

    if (from != address(0)) {
      _removeDelegations(firstTokenId);
      _detachAllContexts({ tokenId: firstTokenId, operator: _msgSender() });
    }
  }

  /**
   * @dev Checks if the `delegatee` is the owner or an approved operator of the `tokenId`.
   */
  function _checkAuthorizedDelegatee(address delegatee, address operator) internal view virtual {
    if (!(delegatee == operator || isApprovedForAll(delegatee, operator))) {
      revert REP15InsufficientApproval(operator, delegatee);
    }
  }

  /**
   * @dev Checks if the `operator` is the ownership manager, an authorized operator of ownership manager,
   * or the approved address for this NFT (if the token is not being delegated).
   */
  function _checkAuthorizedOwnershipManager(uint256 tokenId, address operator) internal view virtual {
    REP15Utils.Delegation storage $delegation = _getREP15Storage()._delegations[tokenId];

    if (!$delegation.isActive()) {
      require(_isApprovedOrOwner(operator, tokenId), "ERC721: caller is not token owner or approved");
      return;
    }

    _checkAuthorizedDelegatee({ delegatee: $delegation.delegatee, operator: operator });
  }

  /**
   * @dev Adds a context to the attached context enumeration of a token.
   */
  function _addAttachedContext(uint256 tokenId, bytes32 ctxHash) private {
    REP15Storage storage $ = _getREP15Storage();
    $._attachedContextsIndex[tokenId][ctxHash] = $._attachedContexts[tokenId].length;
    $._attachedContexts[tokenId].push(ctxHash);
  }

  /**
   * @dev Removes a context from the attached context enumeration of a token.
   */
  function _removeAttachedContext(uint256 tokenId, bytes32 ctxHash) private {
    REP15Storage storage $ = _getREP15Storage();
    bytes32[] storage $attachedContexts = $._attachedContexts[tokenId];
    mapping(bytes32 ctxHash => uint256 index) storage $attachedContextsIndex = $._attachedContextsIndex[tokenId];

    uint256 contextIndex = $attachedContextsIndex[ctxHash];
    bytes32 lastCtxHash = $attachedContexts[$attachedContexts.length - 1];

    $attachedContexts[contextIndex] = lastCtxHash;
    $attachedContextsIndex[lastCtxHash] = contextIndex;

    $attachedContexts.pop();
    delete $attachedContextsIndex[ctxHash];
  }

  /**
   * @dev Triggers the callback to the context controller.
   *
   * WARNING:
   *  - If the `controller` is not a contract, this function will be early exited.
   *  - This function does not verify the `callData` is a valid function call.
   */
  function _triggerContextCallback(address controller, bytes memory callData, bool allowFail) private {
    // early exit if the controller is not a contract
    if (controller.code.length == 0) return;

    // low-level call to the controller contract.
    (bool success, bytes memory data) = controller.call(callData);

    // If the call fails and `allowFail` is false, revert with the returned data.
    if (!success && !allowFail) {
      assembly ("memory-safe") {
        revert(add(data, 0x20), mload(data))
      }
    }
  }
}
