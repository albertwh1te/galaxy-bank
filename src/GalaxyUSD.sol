// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

/* 
    @title GalaxyUSD is a stablecoin, issued by Galaxy Bank, with the aim of maintaining a peg to the U.S. dollar.
*/
contract GalaxyUSD is ERC20, Owned {
    using FixedPointMathLib for uint256;

    error GalaxyUSD__NotEnoughBalance();
    error GalaxyUSD__NeedMoreThanZero();

    /*
    ###################
    # PUBLIC VARIABLE #
    ###################
    */
    uint256 private fee;
    uint256 private constant RATIO = 1e4;
    address private treasure;

    constructor(uint256 _fee, address _treasure) ERC20("Galaxy USD", "GUSD", 18) Owned(msg.sender) {
        fee = _fee;
        treasure = _treasure;
    }

    //////////////////
    // Modifiers    //
    //////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert GalaxyUSD__NeedMoreThanZero();
        }
        _;
    }

    /*
    ######################
    # INTERNAL FUNCTIONS #
    ######################
    */

    function _getFee(address from, uint256 amount) internal view returns (uint256 newAmount, uint256 feeAmount) {
        uint256 balance = balanceOf[from];
        if (balance < amount) {
            revert GalaxyUSD__NotEnoughBalance();
        }

        feeAmount = amount.mulDivDown(fee, RATIO);
        newAmount = amount - feeAmount;
    }

    /*
    ###################
    # PUBLIC FUNCTION #
    ###################
    */

    function transfer(address to, uint256 amount) public override returns (bool) {
        (uint256 newAmount, uint256 feeAmount) = _getFee(msg.sender, amount);
        if (feeAmount > 0) {
            super.transfer(treasure, feeAmount);
        }
        return super.transfer(to, newAmount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        (uint256 newAmount, uint256 feeAmount) = _getFee(from, amount);
        if (feeAmount > 0) {
            super.transferFrom(from, treasure, feeAmount);
        }
        return super.transferFrom(from, to, newAmount);
    }

    function burn(address to, uint256 amount) external onlyOwner moreThanZero(amount) {
        uint256 balance = balanceOf[to];
        if (balance < amount) {
            revert GalaxyUSD__NotEnoughBalance();
        }
        _burn(to, amount);
    }

    function mint(address to, uint256 amount) external onlyOwner moreThanZero(amount) {
        _mint(to, amount);
    }
}
