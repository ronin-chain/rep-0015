// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { REP15UpgradeableTest } from "./REP15Upgradeable.t.sol";
import { PausableUpgradeable } from "@openzeppelin-upgradeable-v4/security/PausableUpgradeable.sol";

contract REP15UpgradeablePausableTest is REP15UpgradeableTest {
  // A context in ATTACHED | UNLOCKED | NOT_REQUESTED state owned by controllerEOA,
  // used to supply a valid ctxHash for methods guarded by onlyController before whenNotPaused.
  bytes32 internal ctxHash;

  function setUp() public override {
    super.setUp();
    _initializeContexts(0);

    ctxHash = allContexts[controllerEOA][STATE_ATTACHED_UNLOCKED_NOT_REQUESTED];

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
    target.createContext(controllerEOA, detachingDuration, "new context");
  }

  function test_updateContext_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    vm.prank(controllerEOA);
    target.updateContext(ctxHash, controllerEOA, detachingDuration);
  }

  // attachContext has modifier order: onlyOwnershipManager(tokenId) → whenNotPaused.
  // Calling as address(this) (token owner) passes the ownership check, then hits the pause guard.
  function test_attachContext_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    target.attachContext(bytes32(0), tokenId, "");
  }

  function test_requestDetachContext_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    target.requestDetachContext(ctxHash, tokenId, "");
  }

  // execDetachContext has modifier order: onlyOwnershipManager(tokenId) → whenNotPaused.
  function test_execDetachContext_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    target.execDetachContext(bytes32(0), tokenId, "");
  }

  // setContextLock has modifier order: onlyController(ctxHash) → whenNotPaused.
  // Calling as the controller of ctxHash passes the controller check, then hits the pause guard.
  function test_setContextLock_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    vm.prank(controllerEOA);
    target.setContextLock(ctxHash, tokenId, true);
  }

  // setContextUser has modifier order: onlyController(ctxHash) → whenNotPaused.
  function test_setContextUser_RevertWhen_Paused() public {
    vm.expectRevert("Pausable: paused");
    vm.prank(controllerEOA);
    target.setContextUser(ctxHash, tokenId, makeAddr("user"));
  }
}
