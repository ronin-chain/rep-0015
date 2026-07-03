// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin-upgradeable-v4/proxy/utils/Initializable.sol";
import { REP15Upgradeable } from "../REP15Upgradeable.sol";
import { IREP15Batch } from "../interfaces/IREP15Batch.sol";

contract REP15BatchUpgradeable is Initializable, REP15Upgradeable, IREP15Batch {
  function __REP15Batch_init() internal onlyInitializing {
    __REP15Batch_init_unchained();
  }

  function __REP15Batch_init_unchained() internal onlyInitializing { }

  /**
   * @inheritdoc IREP15Batch
   */
  function batchAttachContexts(bytes32[] calldata ctxHashes, uint256[] calldata tokenIds, bytes[] calldata data)
    external
  {
    uint256 length = ctxHashes.length;
    if (length != tokenIds.length || length != data.length) revert REP15InvalidBatchLength(msg.sig);

    for (uint256 i; i < length; ++i) {
      attachContext(ctxHashes[i], tokenIds[i], data[i]);
    }
  }
}
