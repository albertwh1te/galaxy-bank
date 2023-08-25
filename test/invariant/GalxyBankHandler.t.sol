// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {GalaxyBank} from "../../src/GalaxyBank.sol";
import {GalaxyUSD} from "../../src/GalaxyUSD.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {Test} from "forge-std/Test.sol";

contract GalaxyBankHandler is Test {
    GalaxyUSD gusd;
    GalaxyBank bank;
    MockERC20[] tokens;

    address alice = address(43);

    constructor(address _gusd, address _bank, MockERC20[] memory _tokens) {
        gusd = GalaxyUSD(_gusd);
        bank = GalaxyBank(_bank);
        tokens = _tokens;
    }

    // function depositCollateral(uint8 collateralIndex, uint256 collaterlAmount) public {
    //     vm.startPrank(msg.sender);
    //     collaterlAmount = bound(collaterlAmount, 1, type(uint96).max);
    //     MockERC20 token = _getTokenCollateralToken(collateralIndex);
    //     _depositCollaterl(token, collaterlAmount);
    //     console.log("depositCollateral success, collaterlAmount: ", collaterlAmount);
    //     vm.stopPrank();
    // }

    function mintGusd(uint8 collateralIndex, uint256 collaterlAmount) public {
        vm.startPrank(msg.sender);
        collaterlAmount = bound(collaterlAmount, 10000, type(uint96).max);
        MockERC20 token = _getTokenCollateralToken(collateralIndex);
        _depositCollaterl(token, collaterlAmount);

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = bank.getAccountInformation(msg.sender);
        console.log("collateralValueInUsd", collateralValueInUsd);
        console.log("totalDscMinted", totalDscMinted);
        // max mint half of the collateral value
        uint256 mintAmount = (collateralValueInUsd - totalDscMinted * 2) / 2;
        console.log("mintAmount", mintAmount);
        bank.mintGusd(mintAmount);
        console.log("mintGusd success, mintAmount: ", mintAmount);
        vm.stopPrank();
    }

    function _depositCollaterl(MockERC20 token, uint256 collaterlAmount) internal {
        token.mint(msg.sender, collaterlAmount);
        token.approve(address(bank), collaterlAmount);
        bank.depositCollateral(address(token), collaterlAmount);
    }

    function _getTokenCollateralToken(uint8 collateralIndex) internal view returns (MockERC20 token) {
        token = tokens[collateralIndex % tokens.length];
    }
}
