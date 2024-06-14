// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { ERC721, REP15 } from "src/REP15.sol";

contract REP15Target is REP15 {
  constructor(string memory name, string memory symbol, uint64 detachingDuration)
    ERC721(name, symbol)
    REP15(detachingDuration)
  { }
}

contract REP15Test is Test {
  string constant name = "Ownership Delegation and Context for ERC-721";
  string constant symbol = "REP15";
  uint64 constant detachingDuration = 1 days;

  REP15Target private immutable rep15 = new REP15Target(name, symbol, detachingDuration);

  function setUp() public { }

  function test_symbol() public view {
    assertEq(rep15.symbol(), symbol);
  }
}
