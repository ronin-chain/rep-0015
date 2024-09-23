// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// Note: the ERC-165 identifier for this interface is 0xad0491f1.
interface IREP15ContextCallback is IERC165 {
  /// @dev This method is called once the token is attached by any mechanism.
  /// This function MAY throw to revert and reject the attachment.
  /// @param ctxHash  The hash of context invoked this call.
  /// @param tokenId  NFT identifier which is being attached.
  /// @param operator The address which called {attachContext} function.
  /// @param data     Additional data with no specified format.
  function onAttached(bytes32 ctxHash, uint256 tokenId, address operator, bytes calldata data) external;

  /// @dev This method is called once the token detachment is requested by any mechanism.
  /// @param ctxHash  The hash of context invoked this call.
  /// @param tokenId  NFT identifier which is being requested for detachment.
  /// @param operator The address which called {requestDetachContext} function.
  /// @param data     Additional data with no specified format.
  function onDetachRequested(bytes32 ctxHash, uint256 tokenId, address operator, bytes calldata data) external;

  /// @dev This method is called once a token context is detached by any mechanism.
  /// @param ctxHash  The hash of context invoked this call.
  /// @param tokenId  NFT identifier which is being detached.
  /// @param user     The address of the context user which is being detached.
  /// @param operator The address which called {execDetachContext} function.
  /// @param data     Additional data with no specified format.
  function onExecDetachContext(bytes32 ctxHash, uint256 tokenId, address user, address operator, bytes calldata data)
    external;
}
