// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IAggregatorV3} from "./interfaces/IAggregatorV3.sol";
import {GalaxyUSD} from "./GalaxyUSD.sol";
import {SafeChainlinkLib} from "./SafeChainlinkLib.sol";

/* 
    @title: GalaxyBank
    @dev: GalaxyBank is a contract that allows users to deposit collateral and mint GalaxyUSD
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
    error GalaxyBank__BreaksHealthFactor();
    error GalaxyBank__HealthFactorIsNotBroken();
    error GalaxyBank__HealthFactorNotImproved();
    error GalaxyBank__DebtToCoverIsGreaterThanGusdMinted();
    error GalaxyBank__NotEnoughCollateral();
    error GalaxyBank__NotEnoughDebt();

    /*
    #########
    # EVENT #
    #########
    */
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    /*
    ############
    # LIBIRARY #
    ############
    */
    using SafeTransferLib for ERC20;
    using SafeChainlinkLib for IAggregatorV3;

    /*
    ############
    # CONSTANT #
    ############
    */
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;

    uint256 private constant LIQUIDATION_BONUS = 10;

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

    /*
    ###############
    # CONSTRUCTOR #
    ###############
    */
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

    /*
    ######################
    # INTERNAL FUNCTIONS #
    ######################
    */

    function _redeemCollateral(address from, address to, address collateral, uint256 amount) internal {
        if (collateralDeposited[from][collateral] < amount) {
            revert GalaxyBank__NotEnoughCollateral();
        }
        collateralDeposited[from][collateral] -= amount;
        emit CollateralRedeemed(from, to, collateral, amount);
        ERC20(collateral).safeTransfer(to, amount);
    }

    function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        internal
        // pure
        view
        returns (uint256)
    {
        if (totalDscMinted == 0) return 1e18;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * 1e18) / totalDscMinted;
    }

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
        uint256 tokenLength = collateralTokens.length;
        for (uint256 i; i < tokenLength;) {
            address token = collateralTokens[i];
            uint256 amount = collateralDeposited[user][token];
            totalCollateralValueInUsd += _getUsdValue(token, amount);
            unchecked {
                ++i;
            }
        }

        return totalCollateralValueInUsd;
    }

    function _getTokenAmountFromUsd(address token, uint256 usdAmount) internal view returns (uint256 tokenAmount) {
        IAggregatorV3 priceFeed = IAggregatorV3(tokenPriceFeed[token]);
        (, int256 price,,,) = priceFeed.safeGetLatestPrice();
        return usdAmount / uint256(price) * (10 ** priceFeed.decimals());
    }

    function _getUsdValue(address token, uint256 amount) internal view returns (uint256) {
        IAggregatorV3 priceFeed = IAggregatorV3(tokenPriceFeed[token]);
        (, int256 price,,,) = priceFeed.safeGetLatestPrice();
        // chainlink_price * token_amount * gusd_decimal/(price_feed_decimal*token_decimal)
        return ((uint256(price)) * amount * (10 ** gusd.decimals()))
            / (10 ** priceFeed.decimals() * (10 ** ERC20(token).decimals()));
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
        emit CollateralDeposited(msg.sender, collateral, amount);
        ERC20(collateral).transferFrom(msg.sender, address(this), amount);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    /*
        @dev: check if the health factor is broken, if it is, revert the transaction
    */
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert GalaxyBank__BreaksHealthFactor();
        }
    }

    /*
        @dev: low leve function to mint DSC, need parameter validation before call this
    */
    function _safeMint(uint256 amount) internal {
        gusdMinted[msg.sender] += amount;
        _revertIfHealthFactorIsBroken(msg.sender);
        gusd.mint(msg.sender, amount);
    }

    function _burn(uint256 amount) internal {
        if (gusdMinted[msg.sender] < amount) {
            revert GalaxyBank__NotEnoughDebt();
        }
        gusdMinted[msg.sender] -= amount;
        // gusd will check the balance
        gusd.burn(msg.sender, amount);
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

    function depositCollateralAndMint(address collateral, uint256 amount, uint256 gusdAmount)
        external
        nonReentrant
        moreThanZero(amount)
        onlySupportedCollateral(collateral)
    {
        _depositCollateral(collateral, amount);
        _safeMint(gusdAmount);
    }

    function depositCollateral(address collateral, uint256 amount)
        external
        nonReentrant
        moreThanZero(amount)
        onlySupportedCollateral(collateral)
    {
        _depositCollateral(collateral, amount);
    }

    function mintGusd(uint256 amount) external nonReentrant moreThanZero(amount) {
        _safeMint(amount);
    }

    function redeemCollateral(address collateral, uint256 amount)
        external
        moreThanZero(amount)
        onlySupportedCollateral(collateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, collateral, amount);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateralForGusd(address collateral, uint256 amount, uint256 burnGusdAmount)
        external
        moreThanZero(amount)
        moreThanZero(burnGusdAmount)
    {
        _redeemCollateral(msg.sender, address(this), collateral, amount);
        _burn(burnGusdAmount);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burn(uint256 amount) external moreThanZero(amount) {
        _burn(amount);
    }

    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert GalaxyBank__HealthFactorIsNotBroken();
        }

        uint256 tokenAmount = _getTokenAmountFromUsd(collateral, debtToCover);

        uint256 bonusCollateral = (tokenAmount * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 totalCollateralToRedeem = tokenAmount + bonusCollateral;

        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);

        // burn gusd from msg.sender, and reduce the debt of the user
        if (gusdMinted[user] < debtToCover) {
            revert GalaxyBank__DebtToCoverIsGreaterThanGusdMinted();
        }
        gusd.burn(msg.sender, debtToCover);
        gusdMinted[user] -= debtToCover;

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert GalaxyBank__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

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
