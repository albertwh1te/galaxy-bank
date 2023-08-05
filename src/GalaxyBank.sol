// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IAggregatorV3} from "./interfaces/IAggregatorV3.sol";
import {GalaxyUSD} from "./GalaxyUSD.sol";

/* 
    TODO: implement me
*/
contract GalaxyBank is Owned, ReentrancyGuard {
    /*
    #########
    # ERROR #
    #########
    */
    error GalaxyBank__NeedsMoreThanZero();
    error GalaxyBank__LengthMismatch();
    error GalaxyBank__CollateralNotSupported();

    /*
    ############
    # LIBIRARY #
    ############
    */
    using SafeTransferLib for ERC20;

    /*
    ###################
    # PUBLIC VARIABLE #
    ###################
    */
    mapping(address token => address priceFeed) private tokenPriceFeed;

    /*
    #####################
    # PRIVATE VARIABLES #
    #####################
    */
    GalaxyUSD private immutable galaxyUSD;

    constructor(address _galaxyUsd) Owned(msg.sender) {
        galaxyUSD = GalaxyUSD(_galaxyUsd);
    }

    /*
    ############
    # MODIFIER #
    ############
    */

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert GalaxyBank__NeedsMoreThanZero();
        }
        _;
    }

    modifier onlySupportedCollateral(address collateral) {
        if (tokenPriceFeed[collateral] == address(0)) {
            revert GalaxyBank__CollateralNotSupported();
        }
        _;
    }

    /*
    ######################
    # INTERNAL FUNCTIONX #
    ######################
    */

    /*
    ######################
    # EXTERNAL FUNCTIONS #
    ######################
    */
    function addCollateralTokens(address[] memory tokenAddresses, address[] memory priceFeedAddresses)
        external
        onlyOwner
    {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert GalaxyBank__LengthMismatch();
        }
        for (uint256 index; index < tokenAddresses.length; index++) {
            tokenPriceFeed[tokenAddresses[index]] = priceFeedAddresses[index];
        }
    }

    function removeCollateralTokens(address collateral) external onlyOwner {
        delete tokenPriceFeed[collateral];
    }
}
