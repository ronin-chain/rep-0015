// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IREP15Batch {
  error REP15InvalidBatchLength(bytes4 sig);

  /**
   * @dev Attaches multiple contexts to multiple tokens.
   * Requirements:
   * - `ctxHashes`, `tokenIds` and `data` must have the same length.
   * - See {IREP15.attachContext} for more details.
   *
   * @param ctxHashes The list of context hashes.
   * @param tokenIds The list of token IDs.
   * @param data The list of data.
   */
  function batchAttachContexts(bytes32[] calldata ctxHashes, uint256[] calldata tokenIds, bytes[] calldata data)
    external;
}
