// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {GalaxyUSD} from "../src/GalaxyUSD.sol";
import {GalaxyBank} from "../src/GalaxyBank.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract TestGalaxyBank is Test {
    using FixedPointMathLib for uint256;

    uint256 private constant FEE = 3;

    MockV3Aggregator private btcPriceFeed;
    MockV3Aggregator private ethPriceFeed;
    MockV3Aggregator private gmxPriceFeed;
    MockV3Aggregator private arbPriceFeed;
    MockERC20 private btc;
    MockERC20 private eth;
    MockERC20 private gmx;
    MockERC20 private arb;

    address owner = address(42);
    address alice = address(43);
    address frank = address(44);
    address treasure = address(45);

    GalaxyBank bank;
    GalaxyUSD gusd;

    function setUp() public {
        vm.startPrank(owner);
        gusd = new GalaxyUSD(FEE,treasure);
        bank = new GalaxyBank(address(gusd));
        vm.stopPrank();
    }

    function initMockData() public {
        uint8 defaulDecimal = 8;
        uint256 btcPrice = 29000 * (10 ** defaulDecimal);
        btcPriceFeed = new MockV3Aggregator(defaulDecimal, int256(btcPrice));
        uint256 ethPrice = 1800 * (10 ** defaulDecimal);
        ethPriceFeed = new MockV3Aggregator(defaulDecimal, int256(ethPrice));
        uint256 gmxPrice = 51 * (10 ** defaulDecimal);
        gmxPriceFeed = new MockV3Aggregator(defaulDecimal, int256(gmxPrice));
        uint256 arbPrice = 2 * (10 ** defaulDecimal);
        arbPriceFeed = new MockV3Aggregator(defaulDecimal, int256(arbPrice));

        btc = new MockERC20("Bitcoin", "BTC", defaulDecimal, 1000000 * (10 ** defaulDecimal));
        eth = new MockERC20("Ethereum", "ETH", defaulDecimal, 1000000 * (10 ** defaulDecimal));
        gmx = new MockERC20("GMX", "GMX", defaulDecimal, 1000000 * (10 ** defaulDecimal));
        arb = new MockERC20("ARB", "ARB", defaulDecimal, 1000000 * (10 ** defaulDecimal));
    }

    function testCollateralTokensManager() public {
        vm.startPrank(owner);
        address[] memory tokenAddresses = new address[](4);
        tokenAddresses[0] = address(btc);
        tokenAddresses[1] = address(eth);
        tokenAddresses[2] = address(gmx);
        tokenAddresses[3] = address(arb);
        address[] memory priceFeedAddresses = new address[](4);
        priceFeedAddresses[0] = address(btcPriceFeed);
        priceFeedAddresses[1] = address(ethPriceFeed);
        priceFeedAddresses[2] = address(gmxPriceFeed);
        priceFeedAddresses[3] = address(arbPriceFeed);
        bank.addCollateralTokens(tokenAddresses, priceFeedAddresses);
        vm.stopPrank();
    }
}
