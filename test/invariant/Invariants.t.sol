// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {GalaxyBankHandler} from "./GalxyBankHandler.t.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {GalaxyBank} from "../../src/GalaxyBank.sol";
import {GalaxyUSD} from "../../src/GalaxyUSD.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IAggregatorV3} from "../../src/interfaces/IAggregatorV3.sol";
import {SafeChainlinkLib} from "../../src/SafeChainlinkLib.sol";

contract Invariants is StdInvariant, Test {
    using SafeChainlinkLib for IAggregatorV3;

    GalaxyUSD gusd;
    GalaxyBank bank;
    GalaxyBankHandler handler;
    MockV3Aggregator private btcPriceFeed;
    MockV3Aggregator private ethPriceFeed;
    MockV3Aggregator private gmxPriceFeed;
    MockV3Aggregator private arbPriceFeed;
    MockERC20 private btc;
    MockERC20 private eth;
    uint256 BTC_START_PRICE = 3139151000000;
    uint256 ETH_START_PRICE = 184165000000;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;

    MockERC20[] private tokens;

    mapping(address token => address priceFeed) tokenPriceFeed;

    uint256 private constant FEE = 3;
    address owner = address(42);
    address alice = address(43);
    address frank = address(44);
    address treasure = address(45);

    function setUp() public {
        vm.startPrank(owner);
        gusd = new GalaxyUSD(FEE,treasure);
        bank = new GalaxyBank(address(gusd));
        gusd.transferOwnership(address(bank));
        initMockData();
        vm.stopPrank();
        _addCommonColleralTokens();

        handler = new GalaxyBankHandler(address(gusd),address(bank),tokens);
        targetContract(address(handler));
    }

    function initMockData() public {
        uint8 chainlinkDefaulDecimal = 8;
        uint256 btcPrice = BTC_START_PRICE;
        btcPriceFeed = new MockV3Aggregator(chainlinkDefaulDecimal, int256(btcPrice));
        uint256 ethPrice = ETH_START_PRICE;
        ethPriceFeed = new MockV3Aggregator(chainlinkDefaulDecimal, int256(ethPrice));

        uint8 defaulDecimal = 18;
        btc = new MockERC20("Bitcoin", "BTC", defaulDecimal, 1000000 * (10 ** defaulDecimal));
        eth = new MockERC20("Ethereum", "ETH", defaulDecimal, 1000000 * (10 ** defaulDecimal));

        tokenPriceFeed[address(btc)] = address(btcPriceFeed);
        tokenPriceFeed[address(eth)] = address(ethPriceFeed);
        tokens.push(btc);
        tokens.push(eth);
    }

    function _addCommonColleralTokens() internal {
        vm.startPrank(owner);
        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(btc);
        tokenAddresses[1] = address(eth);
        address[] memory priceFeedAddresses = new address[](2);
        priceFeedAddresses[0] = address(btcPriceFeed);
        priceFeedAddresses[1] = address(ethPriceFeed);
        bank.addCollateralTokens(tokenAddresses, priceFeedAddresses);
        vm.stopPrank();
    }

    function invariant_protocolMustBeSolvent() public {
        console.log("start ");
        uint256 protocolTotalAssetsUsd = 0;
        // cache length for gas saving
        uint256 tokenLength = tokens.length;

        for (uint256 index = 0; index < tokenLength; index++) {
            MockERC20 token = tokens[index];
            console.log("token: ", address(token));
            IAggregatorV3 priceFeed = IAggregatorV3(tokenPriceFeed[address(token)]);
            (, int256 price,,,) = priceFeed.safeGetLatestPrice();

            // console.log("price:", uint256(price));
            uint256 tokenAmount = token.balanceOf(address(bank));

            uint256 tokenValues =
                uint256(price) * tokenAmount * gusd.decimals() / (priceFeed.decimals() * priceFeed.decimals());

            console.log("tokenValues: %s", tokenAmount);

            protocolTotalAssetsUsd += tokenValues;
        }

        console.log("protocolTotalAssets: %s", protocolTotalAssetsUsd);

        uint256 protocolTotalLiabilities = gusd.totalSupply();
        console.log("protocolTotalLiabilities: %s", protocolTotalLiabilities);

        uint256 collateralAdjustedForThreshold = protocolTotalAssetsUsd * LIQUIDATION_THRESHOLD / LIQUIDATION_PRECISION;
        uint256 protocolHealthFactorInPercent;
        if (protocolTotalLiabilities > 0) {
            protocolHealthFactorInPercent = collateralAdjustedForThreshold * 100 / protocolTotalLiabilities;
        } else {
            protocolHealthFactorInPercent = 100;
        }

        console.log("protocolHealthFactor", protocolHealthFactorInPercent);

        assertGe(protocolTotalAssetsUsd, protocolTotalLiabilities);

        assertGe(protocolHealthFactorInPercent, 100);
    }
}
