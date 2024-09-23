// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { REP15Test } from "./REP15.t.sol";
import { IREP15 } from "@ronin/rep-0015/interfaces/IREP15.sol";
import { IREP15Errors } from "@ronin/rep-0015/interfaces/IREP15Errors.sol";
import { IERC721Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract REP15OwnershipDelegationTest is REP15Test {
  address internal immutable delegatee = makeAddr("delegatee");
  address internal immutable operator = makeAddr("operator");
  address internal immutable approved = makeAddr("approved");
  address internal immutable delegateeOperator = makeAddr("delegateeOperator");
  address internal immutable other = makeAddr("other");
  uint64 internal immutable delegatingDuration = 5 days;
  uint256 internal immutable nonexistentTokenId = 13;

  function setUp() public override {
    super.setUp();

    target.approve(approved, tokenId);
    target.setApprovalForAll(operator, true);

    vm.prank(delegatee);
    target.setApprovalForAll(delegateeOperator, true);

    assertGt(
      detachingDuration,
      10 * uint64(type(uint8).max),
      "detachingDuration must be greater than accumulated gap of all tests"
    );
  }

  function test_startDelegateOwnership() public returns (uint64 until) {
    until = uint64(block.timestamp + delegatingDuration);

    vm.expectEmit(address(target));
    emit IREP15.OwnershipDelegationStarted(tokenId, delegatee, until);

    target.startDelegateOwnership(tokenId, delegatee, until);
  }

  function testFuzz_startDelegateOwnership_SuccessWhen_ReplacePendingDelegation(uint8 gapSinceStarted) public {
    test_startDelegateOwnership();

    vm.warp(block.timestamp + gapSinceStarted);

    test_startDelegateOwnership();
  }

  function testFuzz_startDelegateOwnership_SuccessWhen_PreviousOwnershipDelegationStopped(
    uint8 gapSinceStarted,
    uint8 gapSinceAccepted,
    uint8 gapSinceStopped
  ) public {
    testFuzz_stopOwnershipDelegation(gapSinceStarted, gapSinceAccepted);

    vm.warp(block.timestamp + gapSinceStopped);

    test_startDelegateOwnership();
  }

  function testFuzz_startDelegateOwnership_SuccessWhen_PreviousOwnershipDelegationExpired(
    uint8 gapSinceStarted,
    uint8 gapSinceExpired
  ) public {
    uint64 until = testFuzz_acceptOwnershipDelegation(gapSinceStarted);

    vm.warp(until + gapSinceExpired);

    test_startDelegateOwnership();
  }

  function test_startDelegateOwnership_SuccessWhen_CallerIsApproved() public {
    vm.prank(approved);
    test_startDelegateOwnership();
  }

  function test_startDelegateOwnership_SuccessWhen_CallerIsOperator() public {
    vm.prank(operator);
    test_startDelegateOwnership();
  }

  function testFuzz_startDelegateOwnership_RevertWhen_AlreadyDelegatedOwnership(
    uint8 gapSinceStarted,
    uint8 gapSinceAccepted
  ) public {
    uint64 until = testFuzz_acceptOwnershipDelegation(gapSinceStarted);

    vm.warp(block.timestamp + gapSinceAccepted);

    vm.expectRevert(
      abi.encodeWithSelector(IREP15Errors.REP15AlreadyDelegatedOwnership.selector, tokenId, delegatee, until)
    );
    target.startDelegateOwnership(tokenId, delegatee, uint64(block.timestamp + delegatingDuration));
  }

  function test_startDelegateOwnership_RevertWhen_CallerIsNotAuthorizedByOwner() public {
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, other, tokenId));

    vm.prank(other);
    target.startDelegateOwnership(tokenId, delegatee, uint64(block.timestamp + delegatingDuration));
  }

  function testFuzz_startDelegateOwnership_RevertWhen_ExpiryTimeIsNotInTheFuture(uint8 secondsPassed) public {
    uint64 invalidUntil = uint64(block.timestamp - secondsPassed);
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidDelegationExpiration.selector, invalidUntil));

    target.startDelegateOwnership(tokenId, delegatee, invalidUntil);
  }

  function test_startDelegateOwnership_RevertWhen_DelegateeIsOwnerOrZero() public {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidDelegatee.selector, address(this)));
    target.startDelegateOwnership(tokenId, address(this), uint64(block.timestamp + delegatingDuration));

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidDelegatee.selector, address(0)));
    target.startDelegateOwnership(tokenId, address(0), uint64(block.timestamp + delegatingDuration));
  }

  function test_startDelegateOwnership_RevertWhen_TokenIsNonexistent() public {
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, nonexistentTokenId));
    target.startDelegateOwnership(nonexistentTokenId, delegatee, uint64(block.timestamp + delegatingDuration));
  }

  function testFuzz_acceptOwnershipDelegation(uint8 gapSinceStarted) public returns (uint64 until) {
    until = test_startDelegateOwnership();

    vm.warp(block.timestamp + gapSinceStarted);

    vm.expectEmit(address(target));
    emit IREP15.OwnershipDelegationAccepted(tokenId, delegatee, until);

    vm.prank(delegatee);
    target.acceptOwnershipDelegation(tokenId);
  }

  function testFuzz_acceptOwnershipDelegation_SuccessWhen_CallerIsOperatorOfDelegatee(uint8 gapSinceStarted) public {
    uint64 until = test_startDelegateOwnership();

    vm.warp(block.timestamp + gapSinceStarted);

    vm.expectEmit(address(target));
    emit IREP15.OwnershipDelegationAccepted(tokenId, delegatee, until);

    vm.prank(delegateeOperator);
    target.acceptOwnershipDelegation(tokenId);
  }

  function test_acceptOwnershipDelegation_RevertWhen_NotStartedOwnershipDelegation() public {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentPendingOwnershipDelegation.selector, tokenId));
    target.acceptOwnershipDelegation(tokenId);

    vm.expectRevert(
      abi.encodeWithSelector(IREP15Errors.REP15NonexistentPendingOwnershipDelegation.selector, nonexistentTokenId)
    );
    target.acceptOwnershipDelegation(nonexistentTokenId);
  }

  function testFuzz_acceptOwnershipDelegation_RevertWhen_ExpiryTimeIsNotInTheFuture(uint8 secondsPassed) public {
    uint64 until = test_startDelegateOwnership();

    vm.warp(until + secondsPassed);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentPendingOwnershipDelegation.selector, tokenId));
    target.acceptOwnershipDelegation(tokenId);
  }

  function testFuzz_acceptOwnershipDelegation_RevertWhen_CallerIsNotAuthorizedDelegatee(uint8 gapSinceStarted) public {
    test_startDelegateOwnership();

    vm.warp(block.timestamp + gapSinceStarted);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InsufficientApproval.selector, other, delegatee));

    vm.prank(other);
    target.acceptOwnershipDelegation(tokenId);
  }

  function testFuzz_stopOwnershipDelegation(uint8 gapSinceStarted, uint8 gapSinceAccepted) public {
    testFuzz_acceptOwnershipDelegation(gapSinceStarted);

    vm.warp(block.timestamp + gapSinceAccepted);

    vm.expectEmit(address(target));
    emit IREP15.OwnershipDelegationStopped(tokenId, delegatee);

    vm.prank(delegatee);
    target.stopOwnershipDelegation(tokenId);
  }

  function testFuzz_stopOwnershipDelegation_SuccessWhen_CallerIsOperatorOfDelegatee(
    uint8 gapSinceStarted,
    uint8 gapSinceAccepted
  ) public {
    testFuzz_acceptOwnershipDelegation(gapSinceStarted);

    vm.warp(block.timestamp + gapSinceAccepted);

    vm.expectEmit(address(target));
    emit IREP15.OwnershipDelegationStopped(tokenId, delegatee);

    vm.prank(delegateeOperator);
    target.stopOwnershipDelegation(tokenId);
  }

  function testFuzz_stopOwnershipDelegation_RevertWhen_NotAcceptedOwnershipDelegation(uint8 gapSinceStarted) public {
    test_startDelegateOwnership();

    vm.warp(block.timestamp + gapSinceStarted);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InactiveOwnershipDelegation.selector, tokenId));

    vm.prank(delegatee);
    target.stopOwnershipDelegation(tokenId);
  }

  function testFuzz_stopOwnershipDelegation_RevertWhen_ExpiryTimeIsNotInTheFuture(
    uint8 gapSinceStarted,
    uint8 secondsPassed
  ) public {
    uint64 until = testFuzz_acceptOwnershipDelegation(gapSinceStarted);

    vm.warp(until + secondsPassed);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InactiveOwnershipDelegation.selector, tokenId));

    vm.prank(delegatee);
    target.stopOwnershipDelegation(tokenId);
  }

  function testFuzz_stopOwnershipDelegation_RevertWhen_CallerIsNotAuthorizedDelegatee(
    uint8 gapSinceStarted,
    uint8 gapSinceAccepted
  ) public {
    testFuzz_acceptOwnershipDelegation(gapSinceStarted);

    vm.warp(block.timestamp + gapSinceAccepted);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InsufficientApproval.selector, other, delegatee));

    vm.prank(other);
    target.stopOwnershipDelegation(tokenId);
  }

  function test_getOwnershipManager_ReturnOwnerWhen_NotDelegatedOwnership() public view {
    assertEq(target.getOwnershipManager(tokenId), address(this));
  }

  function testFuzz_getOwnershipManager_ReturnOwnerWhen_OwnershipDelegationExpired(
    uint8 gapSinceStarted,
    uint8 secondsPassed
  ) public {
    uint64 until = testFuzz_acceptOwnershipDelegation(gapSinceStarted);

    vm.warp(until + secondsPassed);

    assertEq(target.getOwnershipManager(tokenId), address(this));
  }

  function testFuzz_getOwnershipManager_ReturnOwnerWhen_OwnershipDelegationStopped(
    uint8 gapSinceStarted,
    uint8 gapSinceAccepted
  ) public {
    testFuzz_stopOwnershipDelegation(gapSinceStarted, gapSinceAccepted);

    assertEq(target.getOwnershipManager(tokenId), address(this));
  }

  function testFuzz_getOwnershipManager_ReturnDelegateeWhen_DelegatedOwnership(
    uint8 gapSinceStarted,
    uint8 gapSinceAccepted
  ) public {
    testFuzz_acceptOwnershipDelegation(gapSinceStarted);

    vm.warp(block.timestamp + gapSinceAccepted);

    assertEq(target.getOwnershipManager(tokenId), delegatee);
  }

  function testFuzz_getOwnershipDelegatee(uint8 gapSinceStarted, uint8 gapSinceAccepted) public {
    uint64 until = testFuzz_acceptOwnershipDelegation(gapSinceStarted);

    vm.warp(block.timestamp + gapSinceAccepted);

    (address actualDelegatee, uint64 actualUntil) = target.getOwnershipDelegatee(tokenId);
    assertEq(actualDelegatee, delegatee);
    assertEq(actualUntil, until);
  }

  function test_getOwnershipDelegatee_RevertWhen_NotDelegatedOwnership() public {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InactiveOwnershipDelegation.selector, tokenId));

    (address actualDelegatee, uint64 actualUntil) = target.getOwnershipDelegatee(tokenId);
    assertEq(actualDelegatee, address(0));
    assertEq(actualUntil, 0);
  }

  function testFuzz_getOwnershipDelegatee_RevertWhen_OwnershipDelegationExpired(
    uint8 gapSinceStarted,
    uint8 secondsPassed
  ) public {
    uint64 until = testFuzz_acceptOwnershipDelegation(gapSinceStarted);

    vm.warp(until + secondsPassed);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InactiveOwnershipDelegation.selector, tokenId));

    (address actualDelegatee, uint64 actualUntil) = target.getOwnershipDelegatee(tokenId);
    assertEq(actualDelegatee, address(0));
    assertEq(actualUntil, 0);
  }

  function testFuzz_getOwnershipDelegatee_RevertWhen_OwnershipDelegationStopped(
    uint8 gapSinceStarted,
    uint8 gapSinceAccepted
  ) public {
    testFuzz_stopOwnershipDelegation(gapSinceStarted, gapSinceAccepted);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InactiveOwnershipDelegation.selector, tokenId));

    (address actualDelegatee, uint64 actualUntil) = target.getOwnershipDelegatee(tokenId);
    assertEq(actualDelegatee, address(0));
    assertEq(actualUntil, 0);
  }

  function test_pendingOwnershipDelegatee() public {
    uint64 until = test_startDelegateOwnership();

    (address actualDelegatee, uint64 actualUntil) = target.pendingOwnershipDelegatee(tokenId);
    assertEq(actualDelegatee, delegatee);
    assertEq(actualUntil, until);
  }

  function test_pendingOwnershipDelegatee_RevertWhen_NotStartedOwnershipDelegation() public {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentPendingOwnershipDelegation.selector, tokenId));

    (address actualDelegatee, uint64 actualUntil) = target.pendingOwnershipDelegatee(tokenId);
    assertEq(actualDelegatee, address(0));
    assertEq(actualUntil, 0);
  }

  function testFuzz_pendingOwnershipDelegatee_RevertWhen_PendingOwnershipDelegationExpired(uint8 secondsPassed) public {
    uint64 until = test_startDelegateOwnership();

    vm.warp(until + secondsPassed);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentPendingOwnershipDelegation.selector, tokenId));

    (address actualDelegatee, uint64 actualUntil) = target.pendingOwnershipDelegatee(tokenId);
    assertEq(actualDelegatee, address(0));
    assertEq(actualUntil, 0);
  }

  function testFuzz_pendingOwnershipDelegatee_RevertWhen_AlreadyAcceptedOwnershipDelegation(
    uint8 gapSinceStarted,
    uint8 gapSinceAccepted
  ) public {
    testFuzz_acceptOwnershipDelegation(gapSinceStarted);

    vm.warp(block.timestamp + gapSinceAccepted);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentPendingOwnershipDelegation.selector, tokenId));

    (address actualDelegatee, uint64 actualUntil) = target.pendingOwnershipDelegatee(tokenId);
    assertEq(actualDelegatee, address(0));
    assertEq(actualUntil, 0);
  }
}
