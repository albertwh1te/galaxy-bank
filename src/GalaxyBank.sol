// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// TODO: delete log
import "forge-std/console.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IAggregatorV3} from "./interfaces/IAggregatorV3.sol";
import {GalaxyUSD} from "./GalaxyUSD.sol";
import {SafeChainlinkLib} from "./SafeChainlinkLib.sol";

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
    using SafeChainlinkLib for IAggregatorV3;

    /*
    ###################
    # PUBLIC VARIABLE #
    ###################
    */

    /*
    #####################
    # PRIVATE VARIABLES #
    #####################
    */

    GalaxyUSD private immutable gusd;
    address[] private collateralTokens;
    mapping(address token => address priceFeed) private tokenPriceFeed;
    mapping(address user => mapping(address token => uint256 amount)) private collateralDeposited;
    mapping(address user => uint256 gusdMinetedAmount) private gusdMinted;

    constructor(address _galaxyUsd) Owned(msg.sender) {
        gusd = GalaxyUSD(_galaxyUsd);
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

    // TODO: implement below functions
    /*
    ######################
    # INTERNAL FUNCTIONX #
    ######################
    */

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        internal
    {}

    function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {}

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = gusdMinted[user];
        collateralValueInUsd = _getAccountCollateralValue(user);
    }

    function _getAccountCollateralValue(address user) internal view returns (uint256 totalCollateralValueInUsd) {
        // loop through each collateral token, get the amount they have deposited, and map it to
        // the price, to get the USD value
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            uint256 amount = collateralDeposited[user][token];
            totalCollateralValueInUsd += _getUsdValue(token, amount);
            console.log("amount", amount, "totalCollateralValueInUsd", totalCollateralValueInUsd);
        }
        return totalCollateralValueInUsd;
    }

    function _getUsdValue(address token, uint256 amount) internal view returns (uint256) {
        IAggregatorV3 priceFeed = IAggregatorV3(tokenPriceFeed[token]);
        (, int256 price,,,) = priceFeed.safeGetLatestPrice();
        uint256 addtionalFeedPrecision = ERC20(token).decimals() - priceFeed.decimals();
        // if price feed percision is 8, and erc20 is 18, then we need to multiply by 10 ** (18-8) = 10 ** 10
        // price * 1e10(price feed percision, already have) * 108(addtionalFeedPrecision) * amount / 1e18(erc20 percision)
        return ((uint256(price) * (10 ** addtionalFeedPrecision)) * amount) / (10 ** ERC20(token).decimals());
    }

    function _removeTokenFromCollateralList(address token) internal {
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            if (collateralTokens[i] == token) {
                collateralTokens[i] = collateralTokens[collateralTokens.length - 1];
                collateralTokens.pop();
                break;
            }
        }
    }

    /* 
        @dev: low level function to deposit collateral, no parameter validation
    */
    function _depositCollateral(address collateral, uint256 amount) internal {
        collateralDeposited[msg.sender][collateral] += amount;
        ERC20(collateral).transferFrom(msg.sender, address(this), amount);
    }

    /*
        @dev: low leve function to mint DSC, no parameter validation
    */
    function safeMint(uint256 amount) internal {
        gusdMinted[msg.sender] += amount;
        // TODO: add health factor check
        // _revertIfHealthFactorIsBroken(msg.sender);
        gusd.mint(msg.sender, amount);
    }

    /*
    ######################
    # EXTERNAL FUNCTIONS #
    ######################
    */

    /*
    ########################
    # ADMIN ONLY FUNCTIONS #
    ########################
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
            collateralTokens.push(tokenAddresses[index]);
        }
    }

    function removeCollateralTokens(address collateral) external onlyOwner {
        delete tokenPriceFeed[collateral];
        _removeTokenFromCollateralList(collateral);
    }

    /*
    ##################
    # USER FUNCTIONS #
    ##################
    */

    function depositCollateralAndMint(address tokenCollateralAddress, uint256 amountCollateral, uint256 gusdAmount)
        external
    {
        _depositCollateral(tokenCollateralAddress, amountCollateral);
        gusd.mint(msg.sender, gusdAmount);
    }

    function depositCollateral(address collateral, uint256 amount)
        external
        nonReentrant
        moreThanZero(amount)
        onlySupportedCollateral(collateral)
    {
        _depositCollateral(collateral, amount);
    }

    function redeemCollateralForGusd(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        // gusd.burn(msg.sender,);
    }

    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {}

    /*
    #################
    # VIEW FUNCTION #
    #################
    */

    function getAccountInformation(address _user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(_user);
    }

    function getColleralTokens() external view returns (address[] memory) {
        return collateralTokens;
    }
}
