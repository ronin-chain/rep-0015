// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// Note: the ERC-165 identifier for this interface is 0xcebf44b7.
interface IREP15Enumerable is IERC165 {
  /// @dev Returns a created context in this contract at `index`.
  /// An index must be a value between 0 and {getContextCount}, non-inclusive.
  /// Note: When using {getContext} and {getContextCount}, make sure you perform all queries on the same block.
  function getContext(uint256 index) external view returns (bytes32 ctxHash);

  /// @dev Returns the number of contexts created in the contract.
  function getContextCount() external view returns (uint256);

  /// @dev Returns a context attached with a token at `index`.
  /// An index must be a value between 0 and {getAttachedContextCount}, non-inclusive.
  /// Note: When using {getAttachedContext} and {getAttachedContextCount}, make sure you perform all queries on the same block.
  function getAttachedContext(uint256 tokenId, uint256 index) external view returns (bytes32 ctxHash);

  /// @dev Returns the number of contexts attached with the token.
  function getAttachedContextCount(uint256 tokenId) external view returns (uint256);
}
