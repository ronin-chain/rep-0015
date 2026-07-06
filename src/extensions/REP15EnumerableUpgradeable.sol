// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin-upgradeable-v4/proxy/utils/Initializable.sol";
import { IERC165 } from "@openzeppelin-v4/utils/introspection/IERC165.sol";
import { REP15Upgradeable } from "../REP15Upgradeable.sol";
import { IREP15Enumerable } from "../interfaces/IREP15Enumerable.sol";

abstract contract REP15EnumerableUpgradeable is Initializable, REP15Upgradeable, IREP15Enumerable {
  error REP15OutOfBoundsContextIndex(uint256 index);

  /// @custom:storage-location erc7201:axieinfinity.storage.REP15EnumerableUpgradeable
  struct REP15EnumerableStorage {
    bytes32[] _allContexts;
    mapping(uint256 tokenId => bytes32[]) _attachedContexts;
    mapping(uint256 tokenId => mapping(bytes32 ctxHash => uint256)) _attachedContextsIndex;
  }

  /// @dev keccak256(abi.encode(uint256(keccak256("axieinfinity.storage.REP15EnumerableUpgradeable")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant $$_REP15EnumerableStorageLocation =
    0x6e70961efcabd68f91d9bacb93e920d816efce6ff4b05ce30b24943944639400;

  function _getREP15EnumerableStorage() private pure returns (REP15EnumerableStorage storage $) {
    assembly ("memory-safe") {
      $.slot := $$_REP15EnumerableStorageLocation
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function __REP15Enumerable_init() internal onlyInitializing {
    __REP15Enumerable_init_unchained();
  }

  function __REP15Enumerable_init_unchained() internal onlyInitializing { }

  /**
   * @inheritdoc IERC165
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(IERC165, REP15Upgradeable)
    returns (bool)
  {
    return interfaceId == type(IREP15Enumerable).interfaceId || super.supportsInterface(interfaceId);
  }

  /**
   * @inheritdoc IREP15Enumerable
   */
  function getContext(uint256 index) public view virtual returns (bytes32 ctxHash) {
    bytes32[] storage allContexts = _getREP15EnumerableStorage()._allContexts;
    if (index >= allContexts.length) revert REP15OutOfBoundsContextIndex(index);
    return allContexts[index];
  }

  /**
   * @inheritdoc IREP15Enumerable
   */
  function getContextCount() public view virtual returns (uint256) {
    return _getREP15EnumerableStorage()._allContexts.length;
  }

  /**
   * @inheritdoc IREP15Enumerable
   */
  function getAttachedContext(uint256 tokenId, uint256 index) public view virtual returns (bytes32 ctxHash) {
    bytes32[] storage attachedContexts = _getREP15EnumerableStorage()._attachedContexts[tokenId];
    if (index >= attachedContexts.length) revert REP15OutOfBoundsContextIndex(index);
    return attachedContexts[index];
  }

  /**
   * @inheritdoc IREP15Enumerable
   */
  function getAttachedContextCount(uint256 tokenId) public view virtual returns (uint256) {
    return _getREP15EnumerableStorage()._attachedContexts[tokenId].length;
  }

  /**
   * @dev Overrides {REP15Upgradeable._updateContext} to track all created contexts.
   */
  function _updateContext(bytes32 ctxHash, address controller, uint64 detachingDuration, address auth)
    internal
    virtual
    override
  {
    super._updateContext(ctxHash, controller, detachingDuration, auth);

    if (auth == address(0)) _getREP15EnumerableStorage()._allContexts.push(ctxHash);
  }

  /**
   * @dev Overrides {REP15Upgradeable._afterAttachContext} to record the attached context for enumeration.
   */
  function _afterAttachContext(bytes32 ctxHash, uint256 tokenId) internal virtual override {
    REP15EnumerableStorage storage $ = _getREP15EnumerableStorage();
    $._attachedContextsIndex[tokenId][ctxHash] = $._attachedContexts[tokenId].length;
    $._attachedContexts[tokenId].push(ctxHash);
  }

  /**
   * @dev Overrides {REP15Upgradeable._afterDetachContext} to remove the detached context from enumeration.
   */
  function _afterDetachContext(bytes32 ctxHash, uint256 tokenId) internal virtual override {
    REP15EnumerableStorage storage $ = _getREP15EnumerableStorage();
    bytes32[] storage attachedContexts = $._attachedContexts[tokenId];
    mapping(bytes32 => uint256) storage index = $._attachedContextsIndex[tokenId];

    uint256 ctxIndex = index[ctxHash];
    bytes32 lastCtxHash = attachedContexts[attachedContexts.length - 1];

    attachedContexts[ctxIndex] = lastCtxHash;
    index[lastCtxHash] = ctxIndex;

    attachedContexts.pop();
    delete index[ctxHash];
  }
}
