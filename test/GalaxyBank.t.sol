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
    // 18 - 8(from chainlink precision)
    uint256 private constant defaulAddtionalDecimals = 10;

    uint256 BTC_START_PRICE = 3139151000000;
    uint256 ETH_START_PRICE = 184165000000;

    uint8 CHAINLINK_DEFAUL_DECIMAL = 8;

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
        gusd.transferOwnership(address(bank));
        initMockData();
        vm.stopPrank();
    }

    function initMockData() public {
        uint8 chainlinkDefaulDecimal = 8;
        uint256 btcPrice = BTC_START_PRICE;
        btcPriceFeed = new MockV3Aggregator(chainlinkDefaulDecimal, int256(btcPrice));
        uint256 ethPrice = ETH_START_PRICE;
        ethPriceFeed = new MockV3Aggregator(chainlinkDefaulDecimal, int256(ethPrice));
        uint256 gmxPrice = 51 * (10 ** chainlinkDefaulDecimal);
        gmxPriceFeed = new MockV3Aggregator(chainlinkDefaulDecimal, int256(gmxPrice));
        uint256 arbPrice = 2 * (10 ** chainlinkDefaulDecimal);
        arbPriceFeed = new MockV3Aggregator(chainlinkDefaulDecimal, int256(arbPrice));

        uint8 defaulDecimal = 18;
        btc = new MockERC20("Bitcoin", "BTC", defaulDecimal, 1000000 * (10 ** defaulDecimal));
        eth = new MockERC20("Ethereum", "ETH", defaulDecimal, 1000000 * (10 ** defaulDecimal));
        gmx = new MockERC20("GMX", "GMX", defaulDecimal, 1000000 * (10 ** defaulDecimal));
        arb = new MockERC20("ARB", "ARB", defaulDecimal, 1000000 * (10 ** defaulDecimal));
    }

    function _addCommonColleralTokens() internal {
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

        address[] memory tokens = bank.getColleralTokens();
        assertEq(tokens.length, tokenAddresses.length);
        console.log(tokens.length);

        bank.removeCollateralTokens(address(btc));
        tokens = bank.getColleralTokens();
        assertEq(tokens.length, tokenAddresses.length - 1);

        bank.removeCollateralTokens(address(eth));
        tokens = bank.getColleralTokens();
        assertEq(tokens.length, tokenAddresses.length - 2);

        bank.removeCollateralTokens(address(gmx));
        tokens = bank.getColleralTokens();
        assertEq(tokens.length, tokenAddresses.length - 3);

        bank.removeCollateralTokens(address(arb));
        tokens = bank.getColleralTokens();
        assertEq(tokens.length, tokenAddresses.length - 4);

        // add again
        bank.addCollateralTokens(tokenAddresses, priceFeedAddresses);
        tokens = bank.getColleralTokens();
        assertEq(tokens.length, tokenAddresses.length);
    }

    function testdepositCollateral() public {
        _addCommonColleralTokens();
        vm.startPrank(frank);
        btc.mint(frank, 10 * 1e18);
        btc.approve(address(bank), 10 * 1e18);
        uint256 bankBalanceBefore = btc.balanceOf(address(bank));
        console.log("bankBalanceBefore", bankBalanceBefore);
        uint256 amount = 10 * 1e18;
        bank.depositCollateral(address(btc), amount);
        assertEq(btc.balanceOf(frank), 0);
        assertEq(btc.balanceOf(address(bank)), 10 * 1e18 + bankBalanceBefore);
        (uint256 usdMinted, uint256 collateral) = bank.getAccountInformation(frank);
        console.log("usdMinted", usdMinted, "collateral", collateral);
        assertEq(usdMinted, 0);
        uint256 btcPrice = BTC_START_PRICE;
        assertEq(collateral, amount * btcPrice * 1e18 / ((10 ** CHAINLINK_DEFAUL_DECIMAL) * 1e18));
        vm.stopPrank();
    }

    function testdepositCollateralAndMint() public {
        uint256 amount = 10 * 1e18;
        uint256 mintAmount = 150000 * 1e18;
        _addCommonColleralTokens();
        vm.startPrank(frank);
        btc.mint(frank, amount);
        btc.approve(address(bank), amount);
        uint256 bankBalanceBefore = btc.balanceOf(address(bank));
        bank.depositCollateralAndMint(address(btc), amount, mintAmount);
        assertEq(btc.balanceOf(frank), 0);
        assertEq(btc.balanceOf(address(bank)), 10 * 1e18 + bankBalanceBefore);
        assertEq(gusd.balanceOf(frank), mintAmount);

        // revert if breaks health factor
        vm.expectRevert(GalaxyBank.GalaxyBank__BreaksHealthFactor.selector);
        bank.mintGusd(mintAmount);

        // deposit more to mint more
        btc.mint(frank, amount);
        btc.approve(address(bank), amount);
        bank.depositCollateral(address(btc), amount);
        bank.mintGusd(mintAmount / 2);
        assertEq(gusd.balanceOf(frank), mintAmount + mintAmount / 2);
        bank.mintGusd(mintAmount / 2);
        assertEq(gusd.balanceOf(frank), mintAmount + mintAmount);

        // revert if breaks health factor
        vm.expectRevert(GalaxyBank.GalaxyBank__BreaksHealthFactor.selector);
        bank.mintGusd(mintAmount);

        vm.stopPrank();
    }

    function testRedeemCollateral() public {
        uint256 amount = 10 * 1e18;
        _addCommonColleralTokens();
        vm.startPrank(frank);
        btc.mint(frank, amount);
        btc.approve(address(bank), amount);
        uint256 bankBalanceBefore = btc.balanceOf(address(bank));

        console.log(btc.balanceOf(frank));
        bank.depositCollateral(address(btc), amount);

        assertEq(btc.balanceOf(frank), 0);
        assertEq(btc.balanceOf(address(bank)), 10 * 1e18 + bankBalanceBefore);

        bank.redeemCollateral(address(btc), amount);

        assertEq(btc.balanceOf(frank), amount);
        assertEq(btc.balanceOf(address(bank)), bankBalanceBefore);

        vm.stopPrank();
    }

    function testRedeemCollaterForGUSD() public {
        uint256 amount = 10 * 1e18;
        uint256 mintAmount = 150000 * 1e18;

        _addCommonColleralTokens();
        vm.startPrank(frank);
        btc.mint(frank, amount);
        btc.approve(address(bank), amount);
        uint256 bankBalanceBefore = btc.balanceOf(address(bank));

        console.log(btc.balanceOf(frank));
        bank.depositCollateral(address(btc), amount);

        assertEq(btc.balanceOf(frank), 0);
        assertEq(btc.balanceOf(address(bank)), 10 * 1e18 + bankBalanceBefore);

        bank.mintGusd(mintAmount);
        assertEq(gusd.balanceOf(frank), mintAmount);

        bank.redeemCollateralForGusd(address(btc), amount, mintAmount);

        vm.expectRevert(GalaxyBank.GalaxyBank__NotEnoughCollateral.selector);
        bank.redeemCollateral(address(btc), amount);

        vm.stopPrank();
    }

    function testLiquidate() public {
        uint256 amount = 10 * 1e18;
        uint256 mintAmount = 150000 * 1e18;

        _addCommonColleralTokens();

        vm.startPrank(frank);
        btc.mint(frank, amount);
        btc.approve(address(bank), amount);
        bank.depositCollateral(address(btc), amount);
        bank.mintGusd(mintAmount);
        vm.stopPrank();

        // update price
        uint8 chainlinkDefaulDecimal = 8;
        uint256 btcPrice = 2839151000000;
        btcPriceFeed.updateAnswer(int256(btcPrice));

        vm.startPrank(alice);
        btc.mint(alice, amount * 10);
        btc.approve(address(bank), amount * 10);
        bank.depositCollateral(address(btc), amount * 10);
        bank.mintGusd(mintAmount * 2);
        bank.liquidate(address(btc), frank, mintAmount);
        vm.stopPrank();
    }
}
