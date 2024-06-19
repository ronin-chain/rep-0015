pragma solidity ^0.8.26;

import { Test, console } from "forge-std/Test.sol";
import "./REP15.t.sol";
import { IREP15 } from "@ronin/rep-0015/interfaces/IREP15.sol";
import { IREP15Errors } from "@ronin/rep-0015/interfaces/IREP15Errors.sol";
import { IERC721Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IREP15ContextCallback } from "@ronin/rep-0015/interfaces/IREP15ContextCallback.sol";

contract REP15ContextTest is REP15Test {
  address internal immutable delegatee = makeAddr("delegatee");

  function testFuzz_createContext(address controller, uint64 detachingDuration) public {
    vm.assume(controller != address(0));
    detachingDuration = detachingDuration % (MAX_DETACHING_DURATION + 1);

    vm.expectEmit(false, true, true, true, address(target));
    emit IREP15.ContextUpdated(bytes32(0), controller, detachingDuration);

    target.createContext(controller, detachingDuration, "newContext");
  }

  function test_createContext_RevertWhen_ContextAlreadyExists() public {
    (bytes32[] memory ctxHashes,) = _getContexts(0, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15ExistentContext.selector, ctxHash));

      target.createContext(address(this), detachingDuration, abi.encodePacked("usecase ", i));
    }
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

  function testFuzz_updateContext(address newController, uint64 newDetachingDuration) public {
    vm.assume(newController != address(0));
    newDetachingDuration = newDetachingDuration % (MAX_DETACHING_DURATION + 1);

    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectEmit(address(target));
      emit IREP15.ContextUpdated(ctxHash, newController, newDetachingDuration);

      vm.prank(controller);
      target.updateContext(ctxHash, newController, newDetachingDuration);
    }
  }

  function test_updateContext_RevertWhen_CallerIsNotController() public {
    (bytes32[] memory ctxHashes,) = _getContexts(ACTIVE, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidController.selector, address(this)));

      target.updateContext(ctxHash, address(this), detachingDuration);
    }
  }

  function test_updateContext_RevertWhen_ContextIsNonexistentOrDeprecated() public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(DEPRECATED, true);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InactiveContext.selector, ctxHash));

      vm.prank(controller);
      target.updateContext(ctxHash, address(this), detachingDuration);
    }
  }

  function test_updateContext_RevertWhen_NewControllerIsZero() public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidController.selector, address(0)));

      vm.prank(controller);
      target.updateContext(ctxHash, address(0), detachingDuration);
    }
  }

  function test_updateContext_RevertWhen_DetachingDurationExceedsMax() public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectRevert(
        abi.encodeWithSelector(IREP15Errors.REP15ExceededMaxDetachingDuration.selector, MAX_DETACHING_DURATION + 1)
      );

      vm.prank(controller);
      target.updateContext(ctxHash, address(this), MAX_DETACHING_DURATION + 1);
    }
  }

  function test_deprecateContext() public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectEmit(address(target));
      emit IREP15.ContextDeprecated(ctxHash);

      vm.prank(controller);
      target.deprecateContext(ctxHash);
    }
  }

  function test_deprecateContext_RevertWhen_CallerIsNotController() public {
    (bytes32[] memory ctxHashes,) = _getContexts(ACTIVE, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidController.selector, address(this)));

      target.deprecateContext(ctxHash);
    }
  }

  function test_deprecateContext_RevertWhen_ContextIsNonexistentOrDeprecated() public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(DEPRECATED, true);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InactiveContext.selector, ctxHash));

      vm.prank(controller);
      target.deprecateContext(ctxHash);
    }
  }

  function test_attachContext() public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE | FREE, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectEmit(address(target));
      emit IREP15.ContextAttached(ctxHash, tokenId);

      if (controller == controllerSuccess) {
        vm.expectEmit(controllerSuccess);
        emit ControllerMock.OnAttached(ctxHash, tokenId, address(this), "attach data");
      }

      target.attachContext(ctxHash, tokenId, "attach data");
    }
  }

  function test_attachContext_RevertWhen_CallerIsNotAuthorizedOwnershipManager_Owner() public {
    (bytes32[] memory ctxHashes,) = _getContexts(ACTIVE | FREE, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];
      address caller = address(uint160(address(this)) - 1);

      vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, caller, tokenId));

      vm.prank(caller);
      target.attachContext(ctxHash, tokenId, "attach data");
    }
  }

  function test_attachContext_RevertWhen_CallerIsNotAuthorizedOwnershipManager_Delegatee() public {
    _delegateTo(delegatee);

    (bytes32[] memory ctxHashes,) = _getContexts(ACTIVE | FREE, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];
      address caller = address(uint160(delegatee) - 1);

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InsufficientApproval.selector, caller, tokenId));

      vm.prank(caller);
      target.attachContext(ctxHash, tokenId, "attach data");
    }
  }

  function test_attachContext_RevertWhen_ContextIsNonexistentOrDeprecated() public {
    (bytes32[] memory ctxHashes,) = _getContexts(DEPRECATED, true);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InactiveContext.selector, ctxHash));

      target.attachContext(ctxHash, tokenId, "attach data");
    }
  }

  function test_attachContext_RevertWhen_ContextIsAlreadyAttached() public {
    (bytes32[] memory ctxHashes,) = _getContexts(ACTIVE | ATTACHED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15AlreadyAttachedContext.selector, ctxHash, tokenId));

      target.attachContext(ctxHash, tokenId, "attach data");
    }
  }

  function test_requestDetachContext_Unlocked() public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(UNLOCKED | NOT_REQUESTED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectEmit(address(target));
      emit IREP15.ContextDetached(ctxHash, tokenId);

      if (controller == controllerSuccess) {
        vm.expectEmit(controllerSuccess);
        emit ControllerMock.OnExecDetachContext(ctxHash, tokenId, address(this), "request detach data");
      }

      target.requestDetachContext(ctxHash, tokenId, "request detach data");
    }
  }

  function test_requestDetachContext_Locked() public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(LOCKED | NOT_REQUESTED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectEmit(address(target));
      emit IREP15.ContextDetachmentRequested(ctxHash, tokenId);

      if (controller == controllerSuccess) {
        vm.expectEmit(controllerSuccess);
        emit ControllerMock.OnDetachRequested(ctxHash, tokenId, address(this), "request detach data");
      }

      target.requestDetachContext(ctxHash, tokenId, "request detach data");
    }
  }

  function test_requestDetachContext_RevertWhen_NotAttachedContext() public {
    (bytes32[] memory ctxHashes,) = _getContexts(FREE, true);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentAttachedContext.selector, ctxHash, tokenId));

      target.requestDetachContext(ctxHash, tokenId, "request detach data");
    }
  }

  function test_requestDetachContext_RevertWhen_AlreadyRequested() public {
    (bytes32[] memory ctxHashes,) = _getContexts(REQUESTED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15RequestedForDetachment.selector, ctxHash, tokenId));

      target.requestDetachContext(ctxHash, tokenId, "request detach data");
    }
  }

  function test_requestDetachContext_RevertWhen_CallIsNotAuthorizedOwnershipManager_Owner() public {
    (bytes32[] memory ctxHashes,) = _getContexts(NOT_REQUESTED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];
      address caller = address(uint160(address(this)) - 1);

      vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, caller, tokenId));

      vm.prank(caller);
      target.requestDetachContext(ctxHash, tokenId, "request detach data");
    }
  }

  function test_requestDetachContext_RevertWhen_CallIsNotAuthorizedOwnershipManager_Delegatee() public {
    _delegateTo(delegatee);

    (bytes32[] memory ctxHashes,) = _getContexts(NOT_REQUESTED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];
      address caller = address(uint160(delegatee) - 1);

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InsufficientApproval.selector, caller, tokenId));

      vm.prank(caller);
      target.requestDetachContext(ctxHash, tokenId, "request detach data");
    }
  }

  function test_execDetachContext() public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(PASSED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectEmit(address(target));
      emit IREP15.ContextDetached(ctxHash, tokenId);

      if (controller == controllerSuccess) {
        vm.expectEmit(controllerSuccess);
        emit ControllerMock.OnExecDetachContext(ctxHash, tokenId, address(this), "exec detach data");
      }

      target.execDetachContext(ctxHash, tokenId, "exec detach data");
    }
  }

  function test_execDetachContext_RevertWhen_CallerIsNotAuthorizedOwnershipManager_Owner() public {
    (bytes32[] memory ctxHashes,) = _getContexts(PASSED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];
      address caller = address(uint160(address(this)) - 1);

      vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, caller, tokenId));

      vm.prank(caller);
      target.execDetachContext(ctxHash, tokenId, "exec detach data");
    }
  }

  function test_execDetachContext_RevertWhen_CallerIsNotAuthorizedOwnershipManager_Delegatee() public {
    _delegateTo(delegatee);

    (bytes32[] memory ctxHashes,) = _getContexts(PASSED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];
      address caller = address(uint160(delegatee) - 1);

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InsufficientApproval.selector, caller, tokenId));

      vm.prank(caller);
      target.execDetachContext(ctxHash, tokenId, "exec detach data");
    }
  }

  function test_execDetachContext_RevertWhen_NotRequested() public {
    (bytes32[] memory ctxHashes,) = _getContexts(NOT_REQUESTED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NotRequestedForDetachment.selector, ctxHash, tokenId));

      target.execDetachContext(ctxHash, tokenId, "exec detach data");
    }
  }

  function test_execDetachContext_RevertWhen_RequestedButNotPassed() public {
    (bytes32[] memory ctxHashes,) = _getContexts(WAITING, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];

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
  }

  function test_execDetachContext_MustWaitForDetachingDurationAtTimeRequested() public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE | PASSED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.prank(controller);
      target.updateContext(ctxHash, controller, detachingDuration * 2);
    }
    test_execDetachContext();
  }

  function test_execDetachContext_MustWaitForDetachingDurationAtTimeRequested_Revert() public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE | WAITING, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.prank(controller);
      target.updateContext(ctxHash, controller, detachingDuration / 2);
    }
    test_execDetachContext_RevertWhen_RequestedButNotPassed();
  }

  function testFuzz_setContextLock(bool locked) public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE | NOT_REQUESTED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectEmit(address(target));
      emit IREP15.ContextLockUpdated(ctxHash, tokenId, locked);

      vm.prank(controller);
      target.setContextLock(ctxHash, tokenId, locked);
    }
  }

  function testFuzz_setContextLock_RevertWhen_ContextIsNonexistentOrDeprecated(bool locked) public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(DEPRECATED, true);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InactiveContext.selector, ctxHash));

      vm.prank(controller);
      target.setContextLock(ctxHash, tokenId, locked);
    }
  }

  function testFuzz_setContextLock_RevertWhen_NotAttachedContext(bool locked) public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE | FREE, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentAttachedContext.selector, ctxHash, tokenId));

      vm.prank(controller);
      target.setContextLock(ctxHash, tokenId, locked);
    }
  }

  function testFuzz_setContextLock_RevertWhen_Requested(bool locked) public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE | REQUESTED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15RequestedForDetachment.selector, ctxHash, tokenId));

      vm.prank(controller);
      target.setContextLock(ctxHash, tokenId, locked);
    }
  }

  function testFuzz_setContextLock_RevertWhen_CallerIsNotController(bool locked) public {
    (bytes32[] memory ctxHashes,) = _getContexts(ACTIVE | NOT_REQUESTED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidController.selector, address(this)));

      target.setContextLock(ctxHash, tokenId, locked);
    }
  }

  function testFuzz_setContextUser(address user) public {
    vm.assume(user != address(0));

    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE | ATTACHED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectEmit(address(target));
      emit IREP15.ContextUserAssigned(ctxHash, tokenId, user);

      vm.prank(controller);
      target.setContextUser(ctxHash, tokenId, user);
    }
  }

  function testFuzz_setContextUser_RevertWhen_ContextIsNonexistentOrDeprecated(address user) public {
    vm.assume(user != address(0));

    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(DEPRECATED, true);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InactiveContext.selector, ctxHash));

      vm.prank(controller);
      target.setContextUser(ctxHash, tokenId, user);
    }
  }

  function testFuzz_setContextUser_RevertWhen_NotAttachedContext(address user) public {
    vm.assume(user != address(0));

    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE | FREE, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentAttachedContext.selector, ctxHash, tokenId));

      vm.prank(controller);
      target.setContextUser(ctxHash, tokenId, user);
    }
  }

  function test_setContextUser_RevertWhen_NewUserIsZero() public {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE | ATTACHED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (bytes32 ctxHash, address controller) = (ctxHashes[i], controllers[i]);

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidContextUser.selector, address(0)));

      vm.prank(controller);
      target.setContextUser(ctxHash, tokenId, address(0));
    }
  }

  function testFuzz_setContextUser_RevertWhen_CallerIsNotController(address user) public {
    vm.assume(user != address(0));

    (bytes32[] memory ctxHashes,) = _getContexts(ACTIVE | ATTACHED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      bytes32 ctxHash = ctxHashes[i];

      vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15InvalidController.selector, address(this)));

      target.setContextUser(ctxHash, tokenId, user);
    }
  }

  function test_maxDetachingDuration() public view {
    assertEq(target.maxDetachingDuration(), MAX_DETACHING_DURATION);
  }

  function test_getContext() public view {
    (bytes32[] memory ctxHashes, address[] memory controllers) = _getContexts(ACTIVE, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (address controller, uint64 detachingDuration_, bool deprecated) = target.getContext(ctxHashes[i]);
      assertEq(controller, controllers[i]);
      assertEq(detachingDuration_, detachingDuration);
      assertEq(deprecated, false);
    }

    (ctxHashes, controllers) = _getContexts(DEPRECATED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      (address controller, uint64 detachingDuration_, bool deprecated) = target.getContext(ctxHashes[i]);
      assertEq(controller, controllers[i]);
      assertEq(detachingDuration_, detachingDuration);
      assertEq(deprecated, true);
    }
  }

  function test_getContext_RevertWhen_ContextIsNonexistent() public {
    bytes32 ctxHash = keccak256(abi.encodePacked("nonexistent context"));

    vm.expectRevert(abi.encodeWithSelector(IREP15Errors.REP15NonexistentContext.selector, ctxHash));

    target.getContext(ctxHash);
  }

  function testFuzz_isAttachedWithContext(bool attached) public view {
    (bytes32[] memory ctxHashes,) = _getContexts(attached ? ATTACHED : FREE, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      assertEq(target.isAttachedWithContext(ctxHashes[i], tokenId), attached);
    }
  }

  function test_isAttachedWithContext_ReturnFalseWhen_ContextIsNonexistent() public view {
    bytes32 ctxHash = keccak256(abi.encodePacked("nonexistent context"));

    assertEq(target.isAttachedWithContext(ctxHash, tokenId), false);
  }

  function test_getContextUser() public {
    (bytes32[] memory ctxHashes,) = _getContexts(0, true);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      assertEq(target.getContextUser(ctxHashes[i], tokenId), address(0));
    }

    testFuzz_setContextUser(address(this));

    (ctxHashes,) = _getContexts(ACTIVE | ATTACHED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      assertEq(target.getContextUser(ctxHashes[i], tokenId), address(this));
    }
  }

  function testFuzz_isTokenContextLocked(bool locked) public view {
    (bytes32[] memory ctxHashes,) = _getContexts(locked ? LOCKED : UNLOCKED, false);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      assertEq(target.isTokenContextLocked(ctxHashes[i], tokenId), locked);
    }
  }

  function test_isTokenContextLocked_ReturnFalseWhen_NotAttachedContext() public view {
    (bytes32[] memory ctxHashes,) = _getContexts(FREE, true);
    for (uint256 i = 0; i < ctxHashes.length; ++i) {
      assertEq(target.isTokenContextLocked(ctxHashes[i], tokenId), false);
    }
  }
}
