// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {GalaxyUSD} from "../src/GalaxyUSD.sol";
import {GalaxyBank} from "../src/GalaxyBank.sol";
import "forge-std/Script.sol";

contract DeployGalaxyBank is Script {
    GalaxyBank bank;
    GalaxyUSD gusd;

    // 3 baisis points
    uint256 private constant FEE = 3;
    // todo: set treasure address
    address treasure = address(0);

    function setUp() public {
        uint256 deployerPrivateKey = vm.envUint("RUG_DEV_KEY");
        vm.startBroadcast(deployerPrivateKey);
        gusd = new GalaxyUSD(FEE,treasure);
        bank = new GalaxyBank(address(gusd));
        gusd.transferOwnership(address(bank));
        vm.stopBroadcast();
    }

    function run() public {
        vm.broadcast();
    }
}
