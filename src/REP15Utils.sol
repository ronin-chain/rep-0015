// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library REP15Utils {
  struct Delegation {
    address delegatee;
    uint64 until;
    bool delegated;
  }

  struct Context {
    address controller;
    uint64 detachingDuration;
  }

  struct TokenContext {
    bool attached;
    bool locked;
    address user;
    uint64 readyForDetachmentAt;
  }

  /// @dev Checks if the delegation is active
  function isActive(Delegation storage self) internal view returns (bool) {
    return self.delegated && self.until > block.timestamp;
  }

  /// @dev Checks if the delegation is pending
  function isPending(Delegation storage self) internal view returns (bool) {
    return !self.delegated && self.until > block.timestamp;
  }

  /// @dev Checks if the context is existent
  function isExistent(Context storage self) internal view returns (bool) {
    return self.controller != address(0);
  }

  /// @dev Checks if the token context is requested for detachment
  function hasRequestedForDetachment(TokenContext storage self) internal view returns (bool) {
    return self.readyForDetachmentAt > 0;
  }
}
