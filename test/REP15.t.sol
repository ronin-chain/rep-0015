// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test, console } from "forge-std/Test.sol";
import { REP15 } from "@ronin/rep-0015/REP15.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ControllerMock } from "@ronin/rep-0015/mocks/ControllerMock.sol";

contract REP15Target is REP15 {
  constructor(string memory name, string memory symbol, uint64 maxDetachingDuration)
    ERC721(name, symbol)
    REP15(maxDetachingDuration)
  { }

  function mint(address to, uint256 tokenId) public {
    _mint(to, tokenId);
  }
}

contract REP15Test is Test {
  string constant NAME = "Ownership Delegation and Context for ERC-721";
  string constant SYMBOL = "REP15";
  uint64 constant MAX_DETACHING_DURATION = 3 days;

  REP15Target internal immutable target = new REP15Target(NAME, SYMBOL, MAX_DETACHING_DURATION);

  uint256 internal constant tokenId = 42;
  uint64 internal constant detachingDuration = 1 days;

  address internal immutable controllerEOA = makeAddr("controllerEOA");
  address internal immutable controllerSuccess = address(new ControllerMock(false));
  address internal immutable controllerFail = address(new ControllerMock(true));

  address[3] internal CONTROLLERS = [controllerEOA, controllerSuccess, controllerFail];

  uint256 internal constant FREE = 1 << 0;
  uint256 internal constant ATTACHED = 1 << 1;

  uint256 internal constant UNLOCKED = 1 << 2;
  uint256 internal constant LOCKED = 1 << 3;

  uint256 internal constant NOT_REQUESTED = 1 << 4;
  uint256 internal constant REQUESTED = 1 << 5;

  uint256 internal constant WAITING = 1 << 6;
  uint256 internal constant PASSED = 1 << 7;

  uint256 internal constant NONEXISTENT = 1 << 8;

  uint256 internal constant STATE_FREE = FREE;
  uint256 internal constant STATE_ATTACHED_UNLOCKED_NOT_REQUESTED = ATTACHED | UNLOCKED | NOT_REQUESTED;
  uint256 internal constant STATE_ATTACHED_LOCKED_NOT_REQUESTED = ATTACHED | LOCKED | NOT_REQUESTED;
  uint256 internal constant STATE_ATTACHED_LOCKED_REQUESTED_WAITING = ATTACHED | LOCKED | REQUESTED | WAITING;
  uint256 internal constant STATE_ATTACHED_LOCKED_REQUESTED_PASSED = ATTACHED | LOCKED | REQUESTED | PASSED;

  // possible states
  uint256[5] internal STATES = [
    STATE_FREE,
    STATE_ATTACHED_UNLOCKED_NOT_REQUESTED,
    STATE_ATTACHED_LOCKED_NOT_REQUESTED,
    STATE_ATTACHED_LOCKED_REQUESTED_WAITING,
    STATE_ATTACHED_LOCKED_REQUESTED_PASSED
  ];

  mapping(address controller => mapping(uint256 state => bytes32 ctxHash)) internal allContexts;

  function setUp() public virtual {
    vm.warp(vm.unixTime());
    target.mint(address(this), tokenId);
  }

  function _initializeContexts(uint256 substate) internal {
    uint256 usecaseId = 0;
    for (uint256 i = 0; i < CONTROLLERS.length; ++i) {
      for (uint256 j = 0; j < STATES.length; ++j) {
        address controller = CONTROLLERS[i];
        uint256 state = STATES[j];

        if (state & substate != substate) continue;

        bytes32 ctxHash = target.createContext(controller, detachingDuration, abi.encodePacked("usecase ", usecaseId++));
        allContexts[controller][state] = ctxHash;

        if (state & ATTACHED != 0) {
          target.attachContext(ctxHash, tokenId, "test-init");
        }

        if (state & LOCKED != 0) {
          vm.prank(controller);
          target.setContextLock(ctxHash, tokenId, true);
        }

        if (state & REQUESTED != 0) {
          uint256 current = block.timestamp;

          if (state & PASSED != 0) vm.warp(current - detachingDuration - 1);
          else vm.warp(current - detachingDuration + 1);

          target.requestDetachContext(ctxHash, tokenId, "");

          vm.warp(current);
        }
      }
    }
  }

  function _delegateTo(address delegatee) internal {
    target.startDelegateOwnership(tokenId, delegatee, uint64(block.timestamp + 2 days));
    vm.prank(delegatee);
    target.acceptOwnershipDelegation(tokenId);
  }
}
