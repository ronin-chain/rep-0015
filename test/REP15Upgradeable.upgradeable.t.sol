// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { REP15UpgradeableTarget } from "./REP15Upgradeable.t.sol";
import { ERC1967Proxy } from "@openzeppelin-v4/proxy/ERC1967/ERC1967Proxy.sol";

contract REP15UpgradeableInitializerTest is Test {
  string constant NAME = "Ownership Delegation and Context for ERC-721";
  string constant SYMBOL = "REP15";

  function test_initialize_RevertWhen_CalledOnImplementation() public {
    REP15UpgradeableTarget impl = new REP15UpgradeableTarget();

    vm.expectRevert("Initializable: contract is already initialized");
    impl.initialize(NAME, SYMBOL);
  }

  function test_initialize_RevertWhen_AlreadyInitialized() public {
    REP15UpgradeableTarget impl = new REP15UpgradeableTarget();
    REP15UpgradeableTarget proxy = REP15UpgradeableTarget(
      address(new ERC1967Proxy(address(impl), abi.encodeCall(impl.initialize, (NAME, SYMBOL))))
    );

    vm.expectRevert("Initializable: contract is already initialized");
    proxy.initialize(NAME, SYMBOL);
  }

  function test_storageSlot() public pure {
    bytes32 expected =
      keccak256(abi.encode(uint256(keccak256("axieinfinity.storage.REP15Upgradeable")) - 1)) & ~bytes32(uint256(0xff));
    assertEq(expected, bytes32(0x2d8b96ed06e1e4e698120e91bb5a55b8ef8d39e3d6e06d21c184ee4f24dd6b00));
  }
}
