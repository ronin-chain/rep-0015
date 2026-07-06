// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin-v4/proxy/ERC1967/ERC1967Proxy.sol";
import { REP15PausableUpgradeable } from "@ronin/rep-0015/extensions/REP15PausableUpgradeable.sol";
import { ControllerMock } from "@ronin/rep-0015/mocks/ControllerMock.sol";

contract REP15PausableUpgradeableTarget is REP15PausableUpgradeable {
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

  function pause() public {
    _pause();
  }

  function unpause() public {
    _unpause();
  }

  function maxDetachingDuration() public pure override returns (uint64) {
    return 3 days;
  }
}

contract REP15UpgradeablePausableTest is Test {
  string constant NAME = "Ownership Delegation and Context for ERC-721";
  string constant SYMBOL = "REP15";
  uint64 constant DETACHING_DURATION = 1 days;

  REP15PausableUpgradeableTarget internal target;

  uint256 internal constant tokenId = 42;

  address internal immutable controllerEOA = makeAddr("controllerEOA");
  address internal immutable controllerSuccess = address(new ControllerMock(false));

  // A context in ATTACHED | UNLOCKED | NOT_REQUESTED state owned by controllerEOA,
  // used to supply a valid ctxHash for methods guarded by onlyController before whenNotPaused.
  bytes32 internal ctxHash;

  function setUp() public {
    vm.warp(vm.unixTime());

    REP15PausableUpgradeableTarget impl = new REP15PausableUpgradeableTarget();
    target = REP15PausableUpgradeableTarget(
      address(new ERC1967Proxy(address(impl), abi.encodeCall(impl.initialize, (NAME, SYMBOL))))
    );

    target.mint(address(this), tokenId);
    ctxHash = target.createContext(controllerEOA, DETACHING_DURATION, "usecase 0");
    target.attachContext(ctxHash, tokenId, "test-init");

    target.pause();
  }

  function test_startDelegateOwnership_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    target.startDelegateOwnership(tokenId, makeAddr("delegatee"), uint64(block.timestamp + 1));
  }

  function test_acceptOwnershipDelegation_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    target.acceptOwnershipDelegation(tokenId);
  }

  function test_stopOwnershipDelegation_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    target.stopOwnershipDelegation(tokenId);
  }

  function test_createContext_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    target.createContext(controllerEOA, DETACHING_DURATION, "new context");
  }

  function test_updateContext_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    vm.prank(controllerEOA);
    target.updateContext(ctxHash, controllerEOA, DETACHING_DURATION);
  }

  // attachContext has modifier order: onlyOwnershipManager(tokenId) → _beforeTokenContext hook.
  // Calling as address(this) (token owner) passes the ownership check, then hits the pause guard.
  function test_attachContext_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    target.attachContext(bytes32(0), tokenId, "");
  }

  function test_requestDetachContext_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    target.requestDetachContext(ctxHash, tokenId, "");
  }

  // execDetachContext has modifier order: onlyOwnershipManager(tokenId) → _beforeTokenContext hook.
  function test_execDetachContext_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    target.execDetachContext(bytes32(0), tokenId, "");
  }

  // setContextLock has modifier order: onlyController(ctxHash) → _beforeTokenContext hook.
  // Calling as the controller of ctxHash passes the controller check, then hits the pause guard.
  function test_setContextLock_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    vm.prank(controllerEOA);
    target.setContextLock(ctxHash, tokenId, true);
  }

  // setContextUser has modifier order: onlyController(ctxHash) → _beforeTokenContext hook.
  function test_setContextUser_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    vm.prank(controllerEOA);
    target.setContextUser(ctxHash, tokenId, makeAddr("user"));
  }

  function test_transferFrom_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    target.transferFrom(address(this), makeAddr("recipient"), tokenId);
  }
}
