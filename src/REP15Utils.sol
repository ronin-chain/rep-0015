// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library REP15Utils {
  struct Delegation {
    address delegatee;
    uint64 until;
    bool delegated;
  }

  struct Context {
    bool active;
    address controller;
    uint64 detachingDuration;
  }

  struct TokenContext {
    bool attached;
    bool locked;
    address user;
    uint64 readyForDetachmentAt;
  }

  function isActive(Delegation storage self) internal view returns (bool) {
    return self.delegated && self.until > block.timestamp;
  }

  function isPending(Delegation storage self) internal view returns (bool) {
    return !self.delegated && self.until > block.timestamp;
  }

  function isExistent(Context storage self) internal view returns (bool) {
    return self.controller != address(0);
  }

  function isDeprecated(Context storage self) internal view returns (bool) {
    return !self.active && self.controller != address(0);
  }

  function hasRequestedForDetachment(TokenContext storage self) internal view returns (bool) {
    return self.readyForDetachmentAt > 0;
  }
}
