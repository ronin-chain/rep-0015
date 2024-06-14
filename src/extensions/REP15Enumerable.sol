pragma solidity ^0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { REP15 } from "../REP15.sol";
import { IREP15Enumerable } from "../interfaces/IREP15Enumerable.sol";

abstract contract REP15Enumerable is REP15, IREP15Enumerable {
  error REP15OutOfBoundsContextIndex(uint256 index);

  bytes32[] private _allContexts;

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
    if (index >= getContextCount()) revert REP15OutOfBoundsContextIndex(index);
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
    if (index >= getAttachedContextCount(tokenId)) revert REP15OutOfBoundsContextIndex(index);
    return _attachedContexts[tokenId][index];
  }

  /**
   * @inheritdoc IREP15Enumerable
   */
  function getAttachedContextCount(uint256 tokenId) public view virtual returns (uint256) {
    return _attachedContexts[tokenId].length;
  }

  /**
   * @dev Overrides {REP15._updateContext} to keep track of all contexts.
   */
  function _updateContext(bytes32 ctxHash, address controller, uint64 detachingDuration, address auth)
    internal
    virtual
    override
  {
    super._updateContext(ctxHash, controller, detachingDuration, auth);

    if (auth == address(0)) _allContexts.push(ctxHash);
  }
}
