// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test, console } from "forge-std/Test.sol";
import "@ronin/rep-0015/REP15.sol";

contract REP15Target is REP15 {
  constructor(string memory name, string memory symbol, uint64 maxDetachingDuration)
    ERC721(name, symbol)
    REP15(maxDetachingDuration)
  { }
}

contract REP15Test is Test {
  string constant name = "Ownership Delegation and Context for ERC-721";
  string constant symbol = "REP15";
  uint64 constant maxDetachingDuration = 1 days;

  REP15Target internal immutable rep15 = new REP15Target(name, symbol, maxDetachingDuration);

  function setUp() public virtual { }
}
