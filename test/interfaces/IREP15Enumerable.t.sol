// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IREP15Enumerable } from "@ronin/rep-0015/interfaces/IREP15Enumerable.sol";

contract IREP15EnumerableTest is Test {
  function test_interfaceId() public pure {
    assertEq(bytes32(type(IREP15Enumerable).interfaceId), bytes32(bytes4(0xcebf44b7)));
  }
}
