// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IREP15 } from "@ronin/rep-0015/interfaces/IREP15.sol";

contract IREP15Test is Test {
  function test_interfaceId() public pure {
    assertEq(bytes32(type(IREP15).interfaceId), bytes32(bytes4(0xba63ebbb)));
  }
}
