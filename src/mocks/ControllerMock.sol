// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IREP15ContextCallback, IERC165 } from "../interfaces/IREP15ContextCallback.sol";

contract ControllerMock is IREP15ContextCallback {
  bool private immutable _reverted;

  event OnAttached(bytes32 ctxHash, uint256 tokenId, address operator, bytes data);
  event OnDetachRequested(bytes32 ctxHash, uint256 tokenId, address operator, bytes data);
  event OnExecDetachContext(bytes32 ctxHash, uint256 tokenId, address user, address operator, bytes data);

  constructor(bool reverted) {
    _reverted = reverted;
  }

  function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
    return interfaceId == type(IREP15ContextCallback).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  function onAttached(bytes32 ctxHash, uint256 tokenId, address operator, bytes calldata data) external {
    emit OnAttached(ctxHash, tokenId, operator, data);
    if (_reverted && bytes32(data) != bytes32("test-init")) revert("ControllerMock: reverted onAttached");
  }

  function onDetachRequested(bytes32 ctxHash, uint256 tokenId, address operator, bytes calldata data) external {
    emit OnDetachRequested(ctxHash, tokenId, operator, data);
    if (_reverted) revert("ControllerMock: reverted onDetachRequested");
  }

  function onExecDetachContext(bytes32 ctxHash, uint256 tokenId, address user, address operator, bytes calldata data)
    external
  {
    emit OnExecDetachContext(ctxHash, tokenId, user, operator, data);
    if (_reverted) revert("ControllerMock: reverted onExecDetachContext");
  }
}
