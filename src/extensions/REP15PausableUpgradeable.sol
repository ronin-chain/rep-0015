// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Initializable } from "@openzeppelin-upgradeable-v4/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "@openzeppelin-upgradeable-v4/security/PausableUpgradeable.sol";
import { REP15Upgradeable } from "../REP15Upgradeable.sol";

abstract contract REP15PausableUpgradeable is Initializable, REP15Upgradeable, PausableUpgradeable {
  function __REP15Pausable_init() internal onlyInitializing { }

  function __REP15Pausable_init_unchained() internal onlyInitializing { }

  /// @inheritdoc REP15Upgradeable
  function startDelegateOwnership(uint256 tokenId, address delegatee, uint64 until)
    public
    virtual
    override
    whenNotPaused
  {
    super.startDelegateOwnership(tokenId, delegatee, until);
  }

  /// @inheritdoc REP15Upgradeable
  function acceptOwnershipDelegation(uint256 tokenId) public virtual override whenNotPaused {
    super.acceptOwnershipDelegation(tokenId);
  }

  /// @inheritdoc REP15Upgradeable
  function stopOwnershipDelegation(uint256 tokenId) public virtual override whenNotPaused {
    super.stopOwnershipDelegation(tokenId);
  }

  /// @inheritdoc REP15Upgradeable
  function createContext(address controller, uint64 detachingDuration, bytes calldata ctxMsg)
    public
    virtual
    override
    whenNotPaused
    returns (bytes32)
  {
    return super.createContext(controller, detachingDuration, ctxMsg);
  }

  /// @inheritdoc REP15Upgradeable
  function updateContext(bytes32 ctxHash, address newController, uint64 newDetachingDuration)
    public
    virtual
    override
    whenNotPaused
  {
    super.updateContext(ctxHash, newController, newDetachingDuration);
  }

  /// @inheritdoc REP15Upgradeable
  function attachContext(bytes32 ctxHash, uint256 tokenId, bytes calldata data)
    public
    virtual
    override
    whenNotPaused
  {
    super.attachContext(ctxHash, tokenId, data);
  }

  /// @inheritdoc REP15Upgradeable
  function requestDetachContext(bytes32 ctxHash, uint256 tokenId, bytes calldata data)
    public
    virtual
    override
    whenNotPaused
  {
    super.requestDetachContext(ctxHash, tokenId, data);
  }

  /// @inheritdoc REP15Upgradeable
  function execDetachContext(bytes32 ctxHash, uint256 tokenId, bytes calldata data)
    public
    virtual
    override
    whenNotPaused
  {
    super.execDetachContext(ctxHash, tokenId, data);
  }

  /// @inheritdoc REP15Upgradeable
  function setContextLock(bytes32 ctxHash, uint256 tokenId, bool lock)
    public
    virtual
    override
    whenNotPaused
  {
    super.setContextLock(ctxHash, tokenId, lock);
  }

  /// @inheritdoc REP15Upgradeable
  function setContextUser(bytes32 ctxHash, uint256 tokenId, address user)
    public
    virtual
    override
    whenNotPaused
  {
    super.setContextUser(ctxHash, tokenId, user);
  }
}
