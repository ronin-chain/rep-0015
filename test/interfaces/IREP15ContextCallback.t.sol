// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IREP15ContextCallback } from "@ronin/rep-0015/interfaces/IREP15ContextCallback.sol";

contract IREP15ContextCallbackTest is Test {
  function test_interfaceId() public pure {
    assertEq(bytes32(type(IREP15ContextCallback).interfaceId), bytes32(bytes4(0xad0491f1)));
  }
}
