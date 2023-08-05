// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 initalAmount)
        ERC20(name_, symbol_, decimals_)
    {
        _mint(msg.sender, initalAmount);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
