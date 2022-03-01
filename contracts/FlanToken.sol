// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FlanToken is ERC20, Ownable {
    constructor() ERC20("Flan Token", "FLN") {
        uint256 initialSupply = 100000000 * 10 ** decimals();
        _mint(_msgSender(), initialSupply);
    }


    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}


