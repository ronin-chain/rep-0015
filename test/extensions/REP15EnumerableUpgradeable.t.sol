// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin-v4/proxy/ERC1967/ERC1967Proxy.sol";
import { REP15Upgradeable, REP15EnumerableUpgradeable } from "@ronin/rep-0015/extensions/REP15EnumerableUpgradeable.sol";

contract REP15EnumerableUpgradeableTarget is REP15EnumerableUpgradeable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(string memory name, string memory symbol) public initializer {
    __ERC721_init(name, symbol);
    __Pausable_init();
  }

  function mint(address to, uint256 tokenId) public {
    _mint(to, tokenId);
  }

  function maxDetachingDuration() public pure override returns (uint64) {
    return 3 days;
  }
}

contract REP15EnumerableUpgradeableTest is Test {
  string constant NAME = "Ownership Delegation and Context for ERC-721";
  string constant SYMBOL = "REP15";
  uint64 constant DETACHING_DURATION = 1 days;

  REP15EnumerableUpgradeableTarget private target;

  bytes32[] internal allContexts;
  address internal immutable controller0 = makeAddr("controller0");
  address internal immutable controller1 = makeAddr("controller1");
  uint256 internal constant tokenId = 42;

  function setUp() public {
    REP15EnumerableUpgradeableTarget impl = new REP15EnumerableUpgradeableTarget();
    target = REP15EnumerableUpgradeableTarget(
      address(new ERC1967Proxy(address(impl), abi.encodeCall(impl.initialize, (NAME, SYMBOL))))
    );

    allContexts.push(target.createContext(controller0, DETACHING_DURATION, "usecase 0"));
    allContexts.push(target.createContext(controller1, DETACHING_DURATION / 2, "usecase 1"));
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

  function test_getContext_RevertWhen_IndexIsOutOfBounds() public {
    vm.expectRevert(
      abi.encodeWithSelector(REP15EnumerableUpgradeable.REP15OutOfBoundsContextIndex.selector, uint256(3))
    );

    target.getContext(uint256(3));
  }

  function test_getContextCount() public view {
    assertEq(target.getContextCount(), 3);
  }

  function test_getAttachedContext() public view {
    assertEq(target.getAttachedContext(tokenId, uint256(0)), allContexts[0]);
    assertEq(target.getAttachedContext(tokenId, uint256(1)), allContexts[1]);
  }

  function test_getAttachedContext_RevertWhen_IndexIsOutOfBounds() public {
    vm.expectRevert(
      abi.encodeWithSelector(REP15EnumerableUpgradeable.REP15OutOfBoundsContextIndex.selector, uint256(2))
    );

    target.getAttachedContext(tokenId, uint256(2));
  }

  function test_getAttachedContextCount() public view {
    assertEq(target.getAttachedContextCount(tokenId), 2);
  }
}
