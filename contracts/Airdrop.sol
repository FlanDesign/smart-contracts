// SPDX-License-Identifier: UNLICENSED

// contracts/Airdrop.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/*
 * FlanTokenVesting
 *
*/
contract FlanTokenAirdrop is Context, Ownable, ReentrancyGuard {
    mapping(address => bool) private Claimed;
    mapping(address => bool) private _isWhitelist;
    mapping(address => uint256) private _valDrop;

    IERC20 private _token;
    uint256 private _decimal=18;
    bool public airdropLive = false;

    event AirdropClaimed(address receiver, uint256 amount);
    event WhitelistSetted(address[] recipient, uint256[] amount);

    constructor(address token_) {
        require(token_ != address(0x0));
        _token = IERC20(token_);
    }


     //Start Airdrop
    function startAirdrop() public onlyOwner{
        require(airdropLive == false, 'Airdrop already started');
        airdropLive = true;
    }

     function setWhitelist(address[] calldata recipients, uint256[] calldata amount) external onlyOwner{
        for(uint i = 0; i< recipients.length; i++){
            require(recipients[i] != address(0));
            _valDrop[recipients[i]] = amount[i];
        }
        emit WhitelistSetted(recipients, amount);
    }

    function claimTokens() public nonReentrant {
        require(airdropLive == true, 'Airdrop not started yet');
        require(Claimed[msg.sender] == false, 'Airdrop already claimed!');
        if(_token.balanceOf(address(this)) == 0) { airdropLive = false; return;}
        Claimed[msg.sender] = true;
        uint256 amount = _valDrop[msg.sender] * 10**18;
        _token.transfer(msg.sender, amount);
        emit AirdropClaimed(msg.sender, amount);
    }

    function withdraw() external onlyOwner {
         require(address(this).balance > 0, 'Contract has no money');
         address payable wallet = payable(msg.sender);
        wallet.transfer(address(this).balance);
    }

    function takeTokens(IERC20 tokenAddress)  public onlyOwner{
        IERC20 tokenERC = tokenAddress;
        uint256 tokenAmt = tokenERC.balanceOf(address(this));
        require(tokenAmt > 0, 'ERC-20 balance is 0');
        address payable wallet = payable(msg.sender);
        tokenERC.transfer(wallet, tokenAmt);
    }

}