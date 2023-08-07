// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IAggregatorV3} from "./interfaces/IAggregatorV3.sol";

/*
    @title SafeChainlinkLib checks if chainlink price feed is valid
*/
library SafeChainlinkLib {
    error SafeChainlinkLib__StablePrice();

    uint256 private constant TIMEOUT = 1 hours;

    /*
        @dev: if price feed is stable for 1 hours, revert. Stop the galaxy bank
    */
    function safeGetLatestPrice(IAggregatorV3 priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert SafeChainlinkLib__StablePrice();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
