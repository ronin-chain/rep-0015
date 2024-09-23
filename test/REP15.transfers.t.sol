// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { REP15Test, REP15, ControllerMock } from "./REP15.t.sol";
import { IREP15Errors } from "@ronin/rep-0015/interfaces/IREP15Errors.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract REP15TransfersTest is REP15Test {
  address internal immutable owner = address(this);
  address internal immutable tokenApproved = makeAddr("tokenApproved");
  address internal immutable ownerOperator = makeAddr("ownerOperator");
  address internal immutable delegatee = makeAddr("delegatee");
  address internal immutable delegateeOperator = makeAddr("delegateeOperator");
  address internal immutable other = makeAddr("other");
  address internal caller;
  bool delegated;

  address[] controllers;
  bytes32[] ctxHashes;

  function setUp() public virtual override {
    super.setUp();

    vm.label(owner, "owner");

    target.approve(tokenApproved, tokenId);
    target.setApprovalForAll(ownerOperator, true);

    vm.prank(delegatee);
    target.setApprovalForAll(delegateeOperator, true);
  }

  modifier setUpContexts(uint256 substate) {
    _initializeContexts(substate);

    _setUpContexts(substate);

    _;
  }

  function _setUpContexts(uint256 substate) internal {
    for (uint256 i = 0; i < CONTROLLERS.length; ++i) {
      address controller = CONTROLLERS[i];
      for (uint256 j = 0; j < STATES.length; ++j) {
        if (STATES[j] & substate == substate) {
          controllers.push(controller);
          ctxHashes.push(allContexts[controller][STATES[j]]);
        }
      }
    }
  }

  modifier asAuthorizedOwnershipManager() {
    uint256 snapshotId = vm.snapshot();

    address[5] memory authorizedCallers = [owner, tokenApproved, ownerOperator, delegatee, delegateeOperator];

    for (uint256 i = 0; i < 5; ++i) {
      if (i == 3) {
        _delegateTo(delegatee);
        delegated = true;
        snapshotId = vm.snapshot();
      }

      caller = authorizedCallers[i];
      vm.prank(caller);
      _;

      assertTrue(vm.revertTo(snapshotId));
    }
  }

  modifier asUnauthorizedOwnershipManager() {
    uint256 snapshotId = vm.snapshot();

    address[7] memory unauthorizedCallers =
      [delegatee, delegateeOperator, other, owner, tokenApproved, ownerOperator, other];

    for (uint256 i = 0; i < 7; ++i) {
      if (i == 3) {
        _delegateTo(delegatee);
        delegated = true;
        snapshotId = vm.snapshot();
      }

      caller = unauthorizedCallers[i];
      vm.prank(caller);
      _;

      assertTrue(vm.revertTo(snapshotId));
    }
  }

  function test_transferFrom() public asAuthorizedOwnershipManager {
    vm.expectEmit(address(target));
    emit IERC721.Transfer(owner, other, tokenId);

    target.transferFrom(owner, other, tokenId);
  }

  // For easy testing, we test only for this specific implementation.
  // So the controllers should emit the event in LIFO order when the contexts are attached.
  // Other implementations may emit the event in a different order so that the test will fail. (*)
  function test_transferFrom_SuccessWhen_AttachedUnlockedContexts()
    public
    setUpContexts(UNLOCKED)
    asAuthorizedOwnershipManager
  {
    for (int256 i = int256(ctxHashes.length) - 1; i >= 0; --i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[uint256(i)], controllers[uint256(i)]);
      if (controller != controllerEOA) {
        vm.expectEmit(controller);
        emit ControllerMock.OnExecDetachContext(ctxHash, tokenId, address(0), caller, "");
      }
    }

    vm.expectEmit(address(target));
    emit IERC721.Transfer(owner, other, tokenId);

    target.transferFrom(owner, other, tokenId);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InactiveOwnershipDelegation.selector, tokenId));

    target.getOwnershipDelegatee(tokenId);
  }

  function test_transferFrom_SuccessWhen_DetachingDurationPassed()
    public
    setUpContexts(PASSED)
    asAuthorizedOwnershipManager
  {
    for (int256 i = int256(ctxHashes.length) - 1; i >= 0; --i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[uint256(i)], controllers[uint256(i)]);
      if (controller != controllerEOA) {
        vm.expectEmit(controller);
        emit ControllerMock.OnExecDetachContext(ctxHash, tokenId, address(0), caller, "");
      }
    }

    vm.expectEmit(address(target));
    emit IERC721.Transfer(owner, other, tokenId);

    target.transferFrom(owner, other, tokenId);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InactiveOwnershipDelegation.selector, tokenId));

    target.getOwnershipDelegatee(tokenId);
  }

  function test_transferFrom_RevertWhen_CallerIsUnauthorized() public asUnauthorizedOwnershipManager {
    if (delegated) {
      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InsufficientApproval.selector, caller, delegatee));
    } else {
      vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, caller, tokenId));
    }

    target.transferFrom(owner, other, tokenId);
  }

  function test_transferFrom_RevertWhen_ContextLockedAndNotRequested()
    public
    setUpContexts(NOT_REQUESTED)
    asAuthorizedOwnershipManager
  {
    vm.expectRevert(
      abi.encodeWithSelector(
        IREP15Errors.REP15NotRequestedForDetachment.selector, ctxHashes[ctxHashes.length - 1], tokenId
      )
    );

    target.transferFrom(owner, other, tokenId);
  }

  function test_transferFrom_RevertWhen_ContextRequestedButWaiting()
    public
    setUpContexts(WAITING)
    asAuthorizedOwnershipManager
  {
    vm.expectRevert(
      abi.encodeWithSelector(
        IREP15Errors.REP15UnreadyForDetachment.selector,
        ctxHashes[ctxHashes.length - 1],
        tokenId,
        uint64(block.timestamp),
        uint64(block.timestamp + 1)
      )
    );

    target.transferFrom(owner, other, tokenId);
  }
}
