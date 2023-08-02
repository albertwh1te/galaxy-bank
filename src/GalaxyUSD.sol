// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

/* 
    @title GalaxyUSD is a stablecoin, issued by Galaxy Bank, with the aim of maintaining a peg to the U.S. dollar.
*/
contract GalaxyUSD is ERC20, Owned {
    error GalaxyUSD__NotEnoughBalance();
    error GalaxyUSD__NeedMoreThanZero();

    /*
    ###################
    # PUBLIC VARIABLE #
    ###################
    */
    uint256 public fee;
    uint256 public RATIO = 10e4;

    constructor(uint256 _fee) ERC20("Galaxy USD", "GUSD", 18) Owned(msg.sender) {
        fee = _fee;
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

    function _burnTransferFee(address from, uint256 amount) internal returns (uint256) {
        uint256 balance = balanceOf[msg.sender];
        if (balance < amount) {
            revert GalaxyUSD__NotEnoughBalance();
        }

        uint256 feeAmount = amount * fee / RATIO;
        uint256 newAmount = amount - feeAmount;

        if (feeAmount > 0) {
            _burn(from, feeAmount);
        }
        return newAmount;
    }

    /*
    ###################
    # PUBLIC FUNCTION #
    ###################
    */

    function transfer(address to, uint256 amount) public override returns (bool) {
        return super.transfer(to, _burnTransferFee(msg.sender, amount));
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        return super.transferFrom(from, to, _burnTransferFee(from, amount));
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
