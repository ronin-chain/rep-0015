// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Initializable } from "@openzeppelin-upgradeable-v4/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "@openzeppelin-upgradeable-v4/security/PausableUpgradeable.sol";
import { REP15Upgradeable } from "../REP15Upgradeable.sol";

abstract contract REP15PausableUpgradeable is Initializable, REP15Upgradeable, PausableUpgradeable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function __REP15Pausable_init() internal onlyInitializing {
    __Pausable_init();
    __REP15Pausable_init_unchained();
  }

  function __REP15Pausable_init_unchained() internal onlyInitializing { }

  function _beforeOwnershipDelegation() internal virtual override {
    _requireNotPaused();
  }

  function _beforeTokenContext() internal virtual override {
    _requireNotPaused();
  }
}
