// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {GalaxyUSD} from "../src/GalaxyUSD.sol";

contract CounterTest is Test {
    GalaxyUSD private gusd;
    uint256 private constant FEE = 3;

    address owner = address(42);
    address alice = address(43);
    address frank = address(44);

    function setUp() public {
        vm.startPrank(owner);
        gusd = new GalaxyUSD(FEE);
        vm.stopPrank();
    }

    // TODO: make it to invariant test
    function testMint() public {
        vm.startPrank(owner);
        console.log("start testMint");
        uint256 mintAmount = 100000 * 10e18;
        console.log("mintAmount: ", mintAmount);
        gusd.mint(alice, mintAmount);
        uint256 balance = gusd.balanceOf(alice);
        assertEq(balance, mintAmount);
        console.log("end testMint, balance: ", balance);
        vm.stopPrank();
    }

    function testMintFailed() public {
        console.log("start testMintFailed");
        vm.startPrank(frank);
        uint256 mintAmount = 100000 * 10e18;
        vm.expectRevert();
        gusd.mint(alice, mintAmount);
    }
}
