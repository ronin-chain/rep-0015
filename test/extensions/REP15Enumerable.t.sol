// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@ronin/rep-0015/extensions/REP15Enumerable.sol";

contract REP15EnumerableTarget is REP15Enumerable {
  constructor(string memory name, string memory symbol, uint64 detachingDuration)
    ERC721(name, symbol)
    REP15(detachingDuration)
  { }

  function mint(address to, uint256 tokenId) public {
    _mint(to, tokenId);
  }
}

contract REP15EnumerableTest is Test {
  string constant name = "Ownership Delegation and Context for ERC-721";
  string constant symbol = "REP15";
  uint64 constant detachingDuration = 1 days;

  REP15EnumerableTarget private immutable target = new REP15EnumerableTarget(name, symbol, detachingDuration);

  bytes32[] internal allContexts;
  address internal immutable controller0 = makeAddr("controller0");
  address internal immutable controller1 = makeAddr("controller1");
  uint256 internal constant tokenId = 42;

  function setUp() public {
    allContexts.push(target.createContext(controller0, detachingDuration, "usecase 0"));
    allContexts.push(target.createContext(controller1, detachingDuration / 2, "usecase 1"));
    allContexts.push(target.createContext(controller0, 0, "usecase 2"));

    target.mint(address(this), tokenId);
    target.attachContext(allContexts[0], tokenId, "");
    target.attachContext(allContexts[1], tokenId, "");
  }

  function test_getContext() public view {
    assertEq(target.getContext(uint256(0)), allContexts[0]);
    assertEq(target.getContext(uint256(1)), allContexts[1]);
    assertEq(target.getContext(uint256(2)), allContexts[2]);
  }

  function test_getContextCount() public view {
    assertEq(target.getContextCount(), 3);
  }

  function test_getAttachedContext() public view {
    assertEq(target.getAttachedContext(tokenId, uint256(0)), allContexts[0]);
    assertEq(target.getAttachedContext(tokenId, uint256(1)), allContexts[1]);
  }

  function test_getAttachedContextCount() public view {
    assertEq(target.getAttachedContextCount(tokenId), 2);
  }
}
