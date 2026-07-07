// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC165 } from "@openzeppelin-v4/utils/introspection/IERC165.sol";
import { REP15 } from "../REP15.sol";
import { IREP15Enumerable } from "../interfaces/IREP15Enumerable.sol";

abstract contract REP15Enumerable is REP15, IREP15Enumerable {
  error REP15OutOfBoundsContextIndex(uint256 index);

  bytes32[] private _allContexts;
  mapping(uint256 tokenId => bytes32[]) private _attachedContexts;
  mapping(uint256 tokenId => mapping(bytes32 ctxHash => uint256)) private _attachedContextsIndex;

  /**
   * @inheritdoc IERC165
   */
  function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, REP15) returns (bool) {
    return interfaceId == type(IREP15Enumerable).interfaceId || super.supportsInterface(interfaceId);
  }

  /**
   * @inheritdoc IREP15Enumerable
   */
  function getContext(uint256 index) public view virtual returns (bytes32 ctxHash) {
    if (index >= _allContexts.length) revert REP15OutOfBoundsContextIndex(index);
    return _allContexts[index];
  }

  /**
   * @inheritdoc IREP15Enumerable
   */
  function getContextCount() public view virtual returns (uint256) {
    return _allContexts.length;
  }

  /**
   * @inheritdoc IREP15Enumerable
   */
  function getAttachedContext(uint256 tokenId, uint256 index) public view virtual returns (bytes32 ctxHash) {
    bytes32[] storage attachedContexts = _attachedContexts[tokenId];
    if (index >= attachedContexts.length) revert REP15OutOfBoundsContextIndex(index);
    return attachedContexts[index];
  }

  /**
   * @inheritdoc IREP15Enumerable
   */
  function getAttachedContextCount(uint256 tokenId) public view virtual returns (uint256) {
    return _attachedContexts[tokenId].length;
  }

  /**
   * @dev Overrides {REP15._updateContext} to track all created contexts.
   */
  function _updateContext(bytes32 ctxHash, address controller, uint64 detachingDuration, address auth)
    internal
    virtual
    override
  {
    super._updateContext(ctxHash, controller, detachingDuration, auth);

    if (auth == address(0)) _allContexts.push(ctxHash);
  }

  /**
   * @dev Overrides {REP15._afterAttachContext} to record the attached context for enumeration.
   */
  function _afterAttachContext(bytes32 ctxHash, uint256 tokenId) internal virtual override {
    _attachedContextsIndex[tokenId][ctxHash] = _attachedContexts[tokenId].length;
    _attachedContexts[tokenId].push(ctxHash);
  }

  /**
   * @dev Overrides {REP15._afterDetachContext} to remove the detached context from enumeration.
   */
  function _afterDetachContext(bytes32 ctxHash, uint256 tokenId) internal virtual override {
    bytes32[] storage attachedContexts = _attachedContexts[tokenId];
    mapping(bytes32 => uint256) storage index = _attachedContextsIndex[tokenId];

    uint256 ctxIndex = index[ctxHash];
    bytes32 lastCtxHash = attachedContexts[attachedContexts.length - 1];

    attachedContexts[ctxIndex] = lastCtxHash;
    index[lastCtxHash] = ctxIndex;

    attachedContexts.pop();
    delete index[ctxHash];
  }
}
