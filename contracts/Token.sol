// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    constructor(uint256 initialSupply) ERC20("Test Token", "TEST") {
        _mint(_msgSender(), initialSupply);
    }


    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}


