// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {GalaxyUSD} from "../src/GalaxyUSD.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract CounterTest is Test {
    using FixedPointMathLib for uint256;

    GalaxyUSD private gusd;
    uint256 private constant FEE = 3;
    uint256 private constant RATIO = 1e4;

    address owner = address(42);
    address alice = address(43);
    address frank = address(44);
    address treasure = address(45);

    function setUp() public {
        vm.startPrank(owner);
        gusd = new GalaxyUSD(FEE,treasure);
        vm.stopPrank();
    }

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

    function testBurn() public {
        console.log("start testBurn");
        vm.startPrank(owner);
        uint256 mintAmount = 500000 * 10e18;
        gusd.mint(alice, mintAmount);
        uint256 balance = gusd.balanceOf(alice);
        uint256 burnAmount = 200000 * 10e18;
        gusd.burn(alice, burnAmount);
        uint256 afterBalance = gusd.balanceOf(alice);
        assertEq(afterBalance, balance - burnAmount);
        vm.stopPrank();

        // burn should reverted if caller is not owner
        vm.startPrank(alice);
        vm.expectRevert();
        gusd.burn(alice, burnAmount);
    }

    function testTransfer() public {
        console.log("start testTransfer");
        uint256 mintAmount = 500000 * 1e18;
        vm.startPrank(owner);
        gusd.mint(alice, mintAmount);
        vm.stopPrank();
        uint256 aliceBeforeBalance = gusd.balanceOf(alice);
        assertEq(aliceBeforeBalance, mintAmount);

        console.log("start first transfer");
        uint256 transferAmount = 100000 * 1e18;
        vm.startPrank(alice);
        gusd.transfer(frank, transferAmount);

        uint256 transferFee = transferAmount.mulDivDown(FEE, RATIO);
        uint256 treasureBalance = gusd.balanceOf(treasure);
        assertEq(treasureBalance, transferFee);
        assertEq(gusd.balanceOf(alice), aliceBeforeBalance - transferAmount);
        assertEq(gusd.balanceOf(frank), transferAmount - transferFee);
        vm.stopPrank();

        console.log("start second transfer");

        uint256 secondTransferAmount = 10000 * 1e18;
        vm.startPrank(frank);
        gusd.approve(alice, secondTransferAmount);
        vm.stopPrank();
        vm.startPrank(alice);
        uint256 frankBalanceBefore = gusd.balanceOf(frank);
        uint256 aliceBalanceBefore = gusd.balanceOf(alice);

        gusd.transferFrom(frank, alice, secondTransferAmount);

        assertEq(gusd.balanceOf(treasure), treasureBalance + secondTransferAmount.mulDivDown(FEE, RATIO));

        uint256 aliceBalanceAfter = gusd.balanceOf(alice);
        uint256 frankBalanceAfter = gusd.balanceOf(frank);
        assertEq(
            aliceBalanceAfter, aliceBalanceBefore + secondTransferAmount - secondTransferAmount.mulDivDown(FEE, RATIO)
        );
        assertEq(frankBalanceAfter, frankBalanceBefore - secondTransferAmount);
    }
}
