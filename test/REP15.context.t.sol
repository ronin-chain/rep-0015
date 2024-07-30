// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { REP15Test, ControllerMock, console } from "./REP15.t.sol";
import { IREP15 } from "@ronin/rep-0015/interfaces/IREP15.sol";
import { IREP15Errors } from "@ronin/rep-0015/interfaces/IREP15Errors.sol";
import { IREP15ContextCallback } from "@ronin/rep-0015/interfaces/IREP15ContextCallback.sol";
import { IERC721Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract REP15ContextTest is REP15Test {
  address internal immutable delegatee = makeAddr("delegatee");

  address internal controller;
  bytes32 internal ctxHash;
  uint256 internal ctxIndex;

  function setUp() public virtual override {
    super.setUp();

    _initializeContexts(0);
  }

  modifier withContext(uint256 substate) {
    if (substate & NONEXISTENT != 0) {
      substate ^= NONEXISTENT;
      controller = address(this);
      ctxHash = keccak256("random ctxHash");
      _;
      if (substate == 0) return;
    }

    for (uint256 i = 0; i < CONTROLLERS.length; ++i) {
      controller = CONTROLLERS[i];
      for (uint256 j = 0; j < STATES.length; ++j) {
        if (STATES[j] & substate == substate) {
          ctxHash = allContexts[controller][STATES[j]];
          _;
          ++ctxIndex;
        }
      }
    }
  }

  modifier activateOwnershipDelegation() {
    _delegateTo(delegatee);
    _;
  }

  function testFuzz_createContext(uint64 detachingDuration) public {
    detachingDuration = detachingDuration % (MAX_DETACHING_DURATION + 1);

    vm.expectEmit(false, true, true, true, address(target));
    emit IREP15.ContextUpdated(bytes32(0), controllerEOA, detachingDuration);

    target.createContext(controllerEOA, detachingDuration, "newContext");
  }

  function test_createContext_RevertWhen_ContextAlreadyExists() public withContext(0) {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15ExistentContext.selector, ctxHash));

    target.createContext(address(this), detachingDuration, abi.encodePacked("usecase ", ctxIndex));
  }

  function test_createContext_RevertWhen_ControllerIsZero() public {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidController.selector, address(0)));

    target.createContext(address(0), detachingDuration, "newContext");
  }

  function test_createContext_RevertWhen_DetachingDurationExceedsMax() public {
    vm.expectRevert(
      abi.encodeWithSelector(IREP15Errors.REP15ExceededMaxDetachingDuration.selector, MAX_DETACHING_DURATION + 1)
    );

    target.createContext(address(this), MAX_DETACHING_DURATION + 1, "new context");
  }

  function testFuzz_updateContext(address newController, uint64 newDetachingDuration) public withContext(0) {
    vm.assume(newController != address(0));
    newDetachingDuration = newDetachingDuration % (MAX_DETACHING_DURATION + 1);

    vm.expectEmit(address(target));
    emit IREP15.ContextUpdated(ctxHash, newController, newDetachingDuration);

    vm.prank(controller);
    target.updateContext(ctxHash, newController, newDetachingDuration);
  }

  function test_updateContext_RevertWhen_CallerIsNotController() public withContext(0) {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidController.selector, address(this)));

    target.updateContext(ctxHash, address(this), detachingDuration);
  }

  function test_updateContext_RevertWhen_ContextIsNonexistent() public withContext(NONEXISTENT) {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentContext.selector, ctxHash));

    vm.prank(controller);
    target.updateContext(ctxHash, address(this), detachingDuration);
  }

  function test_updateContext_RevertWhen_NewControllerIsZero() public withContext(0) {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidController.selector, address(0)));

    vm.prank(controller);
    target.updateContext(ctxHash, address(0), detachingDuration);
  }

  function test_updateContext_RevertWhen_DetachingDurationExceedsMax() public withContext(0) {
    vm.expectRevert(
      abi.encodeWithSelector(IREP15Errors.REP15ExceededMaxDetachingDuration.selector, MAX_DETACHING_DURATION + 1)
    );

    vm.prank(controller);
    target.updateContext(ctxHash, address(this), MAX_DETACHING_DURATION + 1);
  }

  function test_attachContext() public withContext(FREE) {
    if (controller == controllerFail) return;

    vm.expectEmit(address(target));
    emit IREP15.ContextAttached(ctxHash, tokenId);

    if (controller == controllerSuccess) {
      vm.expectEmit(controllerSuccess);
      emit ControllerMock.OnAttached(ctxHash, tokenId, address(this), "attach data");
    }

    target.attachContext(ctxHash, tokenId, "attach data");
  }

  function test_attachContext_RevertWhen_CallerIsNotAuthorizedOwnershipManager_Owner() public withContext(FREE) {
    if (controller == controllerFail) return;

    address caller = address(uint160(address(this)) - 1);

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, caller, tokenId));

    vm.prank(caller);
    target.attachContext(ctxHash, tokenId, "attach data");
  }

  function test_attachContext_RevertWhen_CallerIsNotAuthorizedOwnershipManager_Delegatee()
    public
    activateOwnershipDelegation
    withContext(FREE)
  {
    if (controller == controllerFail) return;

    address caller = address(uint160(delegatee) - 1);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InsufficientApproval.selector, caller, delegatee));

    vm.prank(caller);
    target.attachContext(ctxHash, tokenId, "attach data");
  }

  function test_attachContext_RevertWhen_ContextIsNonexistent() public withContext(NONEXISTENT) {
    if (controller == controllerFail) return;

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentContext.selector, ctxHash));

    target.attachContext(ctxHash, tokenId, "attach data");
  }

  function test_attachContext_RevertWhen_ContextIsAlreadyAttached() public withContext(ATTACHED) {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15AlreadyAttachedContext.selector, ctxHash, tokenId));

    target.attachContext(ctxHash, tokenId, "attach data");
  }

  function test_attachContext_RevertWhen_ControllerRevert() public withContext(FREE) {
    if (controller != controllerFail) return;

    vm.expectRevert();

    target.attachContext(ctxHash, tokenId, "attach data");
  }

  function test_requestDetachContext_Unlocked() public withContext(UNLOCKED | NOT_REQUESTED) {
    vm.expectEmit(address(target));
    emit IREP15.ContextDetached(ctxHash, tokenId);

    if (controller == controllerSuccess) {
      vm.expectEmit(controllerSuccess);
      emit ControllerMock.OnExecDetachContext(ctxHash, tokenId, address(0), address(this), "request detach data");
    }

    target.requestDetachContext(ctxHash, tokenId, "request detach data");
  }

  function test_requestDetachContext_Locked() public withContext(LOCKED | NOT_REQUESTED) {
    vm.expectEmit(address(target));
    emit IREP15.ContextDetachmentRequested(ctxHash, tokenId);

    if (controller == controllerSuccess) {
      vm.expectEmit(controllerSuccess);
      emit ControllerMock.OnDetachRequested(ctxHash, tokenId, address(this), "request detach data");
    }

    target.requestDetachContext(ctxHash, tokenId, "request detach data");
  }

  function test_requestDetachContext_CallerIsController() public withContext(NOT_REQUESTED) {
    vm.expectEmit(address(target));
    emit IREP15.ContextDetached(ctxHash, tokenId);

    if (controller == controllerSuccess) {
      vm.expectEmit(controllerSuccess);
      emit ControllerMock.OnExecDetachContext(ctxHash, tokenId, address(0), controller, "request detach data");
    }

    vm.prank(controller);
    target.requestDetachContext(ctxHash, tokenId, "request detach data");
  }

  function test_requestDetachContext_RevertWhen_NotAttachedContext() public withContext(FREE | NONEXISTENT) {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentAttachedContext.selector, ctxHash, tokenId));

    target.requestDetachContext(ctxHash, tokenId, "request detach data");
  }

  function test_requestDetachContext_RevertWhen_AlreadyRequested() public withContext(REQUESTED) {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15RequestedForDetachment.selector, ctxHash, tokenId));

    target.requestDetachContext(ctxHash, tokenId, "request detach data");
  }

  function test_requestDetachContext_RevertWhen_CallIsNotAuthorizedOwnershipManager_Owner()
    public
    withContext(NOT_REQUESTED)
  {
    address caller = address(uint160(address(this)) - 1);

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, caller, tokenId));

    vm.prank(caller);
    target.requestDetachContext(ctxHash, tokenId, "request detach data");
  }

  function test_requestDetachContext_RevertWhen_CallIsNotAuthorizedOwnershipManager_Delegatee()
    public
    activateOwnershipDelegation
    withContext(NOT_REQUESTED)
  {
    address caller = address(uint160(delegatee) - 1);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InsufficientApproval.selector, caller, delegatee));

    vm.prank(caller);
    target.requestDetachContext(ctxHash, tokenId, "request detach data");
  }

  function test_execDetachContext() public withContext(PASSED) {
    vm.expectEmit(address(target));
    emit IREP15.ContextDetached(ctxHash, tokenId);

    if (controller == controllerSuccess) {
      vm.expectEmit(controllerSuccess);
      emit ControllerMock.OnExecDetachContext(ctxHash, tokenId, address(0), address(this), "exec detach data");
    }

    target.execDetachContext(ctxHash, tokenId, "exec detach data");
  }

  function test_execDetachContext_RevertWhen_CallerIsNotAuthorizedOwnershipManager_Owner() public withContext(PASSED) {
    address caller = address(uint160(address(this)) - 1);

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, caller, tokenId));

    vm.prank(caller);
    target.execDetachContext(ctxHash, tokenId, "exec detach data");
  }

  function test_execDetachContext_RevertWhen_CallerIsNotAuthorizedOwnershipManager_Delegatee()
    public
    activateOwnershipDelegation
    withContext(PASSED)
  {
    address caller = address(uint160(delegatee) - 1);

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InsufficientApproval.selector, caller, delegatee));

    vm.prank(caller);
    target.execDetachContext(ctxHash, tokenId, "exec detach data");
  }

  function test_execDetachContext_RevertWhen_NotRequested() public withContext(NOT_REQUESTED) {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NotRequestedForDetachment.selector, ctxHash, tokenId));

    target.execDetachContext(ctxHash, tokenId, "exec detach data");
  }

  function test_execDetachContext_RevertWhen_RequestedButNotPassed() public withContext(WAITING) {
    vm.expectRevert(
      abi.encodeWithSelector(
        IREP15Errors.REP15UnreadyForDetachment.selector,
        ctxHash,
        tokenId,
        uint64(block.timestamp),
        uint64(block.timestamp + 1)
      )
    );

    target.execDetachContext(ctxHash, tokenId, "exec detach data");
  }

  function test_execDetachContext_MustWaitForDetachingDurationAtTimeRequested_SuccessWhen_Passed() public {
    for (uint256 i = 0; i < CONTROLLERS.length; ++i) {
      controller = CONTROLLERS[i];
      for (uint256 j = 0; j < STATES.length; ++j) {
        if (STATES[j] & PASSED == PASSED) {
          ctxHash = allContexts[controller][STATES[j]];
          vm.prank(controller);
          target.updateContext(ctxHash, controller, detachingDuration * 2);
        }
      }
    }

    test_execDetachContext();
  }

  function test_execDetachContext_MustWaitForDetachingDurationAtTimeRequested_RevertWhen_Waiting() public {
    for (uint256 i = 0; i < CONTROLLERS.length; ++i) {
      controller = CONTROLLERS[i];
      for (uint256 j = 0; j < STATES.length; ++j) {
        if (STATES[j] & WAITING == WAITING) {
          ctxHash = allContexts[controller][STATES[j]];
          vm.prank(controller);
          target.updateContext(ctxHash, controller, detachingDuration / 2);
        }
      }
    }

    test_execDetachContext_RevertWhen_RequestedButNotPassed();
  }

  function testFuzz_setContextLock(bool locked) public withContext(NOT_REQUESTED) {
    vm.expectEmit(address(target));
    emit IREP15.ContextLockUpdated(ctxHash, tokenId, locked);

    vm.prank(controller);
    target.setContextLock(ctxHash, tokenId, locked);
  }

  function testFuzz_setContextLock_RevertWhen_ContextIsNonexistent(bool locked) public withContext(NONEXISTENT) {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentContext.selector, ctxHash));

    vm.prank(controller);
    target.setContextLock(ctxHash, tokenId, locked);
  }

  function testFuzz_setContextLock_RevertWhen_NotAttachedContext(bool locked) public withContext(FREE) {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentAttachedContext.selector, ctxHash, tokenId));

    vm.prank(controller);
    target.setContextLock(ctxHash, tokenId, locked);
  }

  function testFuzz_setContextLock_RevertWhen_Requested(bool locked) public withContext(REQUESTED) {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15RequestedForDetachment.selector, ctxHash, tokenId));

    vm.prank(controller);
    target.setContextLock(ctxHash, tokenId, locked);
  }

  function testFuzz_setContextLock_RevertWhen_CallerIsNotController(bool locked) public withContext(NOT_REQUESTED) {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidController.selector, address(this)));

    target.setContextLock(ctxHash, tokenId, locked);
  }

  function testFuzz_setContextUser(address user) public withContext(ATTACHED) {
    vm.assume(user != address(0));

    vm.expectEmit(address(target));
    emit IREP15.ContextUserAssigned(ctxHash, tokenId, user);

    vm.prank(controller);
    target.setContextUser(ctxHash, tokenId, user);
  }

  function testFuzz_setContextUser_RevertWhen_ContextIsNonexistent(address user) public withContext(NONEXISTENT) {
    vm.assume(user != address(0));

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentContext.selector, ctxHash));

    vm.prank(controller);
    target.setContextUser(ctxHash, tokenId, user);
  }

  function testFuzz_setContextUser_RevertWhen_NotAttachedContext(address user) public withContext(FREE) {
    vm.assume(user != address(0));

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentAttachedContext.selector, ctxHash, tokenId));

    vm.prank(controller);
    target.setContextUser(ctxHash, tokenId, user);
  }

  function testFuzz_setContextUser_RevertWhen_CallerIsNotController(address user) public withContext(ATTACHED) {
    vm.assume(user != address(0));

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidController.selector, address(this)));

    target.setContextUser(ctxHash, tokenId, user);
  }

  function test_maxDetachingDuration() public view {
    assertEq(target.maxDetachingDuration(), MAX_DETACHING_DURATION);
  }

  function test_getContext() public withContext(0) {
    (address actualController, uint64 actualDetachingDuration) = target.getContext(ctxHash);
    assertEq(actualController, controller);
    assertEq(actualDetachingDuration, detachingDuration);
  }

  function test_getContext_RevertWhen_ContextIsNonexistent() public withContext(NONEXISTENT) {
    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentContext.selector, ctxHash));

    target.getContext(ctxHash);
  }

  function testFuzz_isAttachedWithContext(bool attached) public withContext(attached ? ATTACHED : FREE) {
    assertEq(target.isAttachedWithContext(ctxHash, tokenId), attached);
  }

  function test_isAttachedWithContext_ReturnFalseWhen_ContextIsNonexistent() public {
    ctxHash = keccak256(abi.encodePacked("nonexistent context"));

    assertEq(target.isAttachedWithContext(ctxHash, tokenId), false);
  }

  function test_getContextUser() public withContext(0 | NONEXISTENT) {
    assertEq(target.getContextUser(ctxHash, tokenId), address(0));
  }

  function testFuzz_getContextUser(address user) public withContext(ATTACHED) {
    vm.assume(user != address(0));

    vm.prank(controller);
    target.setContextUser(ctxHash, tokenId, user);

    assertEq(target.getContextUser(ctxHash, tokenId), user);
  }

  function testFuzz_isTokenContextLocked(bool locked) public withContext(locked ? LOCKED : UNLOCKED) {
    assertEq(target.isTokenContextLocked(ctxHash, tokenId), locked);
  }

  function test_isTokenContextLocked_ReturnFalseWhen_NotAttachedContext() public withContext(FREE | NONEXISTENT) {
    assertEq(target.isTokenContextLocked(ctxHash, tokenId), false);
  }
}
