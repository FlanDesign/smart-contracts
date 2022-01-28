// SPDX-License-Identifier: UNLICENSED

// contracts/FlanTokenVesting.sol
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
contract FlanTokenStaking is Context, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 private _token;
    uint256 private _decimal=18;
    uint32 private _minLockDay=7;

    uint256 totalStakedAmount = 0;

    struct Member{
        uint256 totalAmount;
        uint32 actionTime;
    }


    mapping(address => Member) stakingAddressAmount;

    constructor(address token_) {
        require(token_ != address(0x0));
        _token = IERC20(token_);
    }

    /**
     * @dev Emitted on stake()
     * @param address_ member address
     * @param amount_ staked amount
     **/
    event Stake(address indexed address_, uint256 amount_);

    /**
     * @dev Emitted on withdrawAmount()
     * @param address_ member address
     * @param amount_ staked amount
     **/
    event WithdrawAmount(address indexed address_, uint256 amount_);

    event WithdrawAll(address indexed address_, uint256 amount_);

    function stake(uint256 amount_) external payable {
        require(msg.sender != address(0x0), "");
        require(amount_ > 0, "");
        if (stakingAddressAmount[msg.sender].totalAmount == 0) {
            stakingAddressAmount[msg.sender].totalAmount = amount_;
        } else {
            stakingAddressAmount[msg.sender].totalAmount += amount_;
        }
        stakingAddressAmount[msg.sender].actionTime = uint32(block.timestamp);
        _token.transferFrom(msg.sender, address(this), amount_);
        emit Stake(_msgSender(), amount_);
    }

    function withdrawAmount(uint256 amount_) external payable {
        require(msg.sender != address(0x0), "Flan Staking: None address!");
        uint256 amount = _withdrawAmount(payable(msg.sender), amount_);
        emit WithdrawAmount(msg.sender, amount);
    }

    function withdrawAll() external payable {
        require(msg.sender != address(0x0), "");
        uint256 amount = stakingAddressAmount[msg.sender].totalAmount;
        amount = _withdrawAmount(payable(msg.sender), amount);
        emit WithdrawAll(msg.sender, amount);
    }

    function _withdrawAmount(address payable address_, uint256 amount_) internal virtual returns(uint256) {
        require(amount_ > 0, "Flan Staking: requested amount == 0");
        require(stakingAddressAmount[address_].totalAmount >= amount_, "Flan Staking: Balance < requested amount");
        require(_getCurrentTime() >= stakingAddressAmount[address_].actionTime + _minLockDay * 3600, "Flan Staking: Lock Period");
        _token.transfer(msg.sender, amount_);
        stakingAddressAmount[msg.sender].totalAmount -= amount_;
        stakingAddressAmount[msg.sender].actionTime = uint32(block.timestamp);
        return amount_;
    }

    function getAmountOfMember(address address_) public view returns(uint256, uint32) {
        require(address_ != address(0x0), "");
        (uint256 amount, uint32 time) = _getAddressAmount(address_);
        return (amount, time);
    }

    function getAddressMinUnlockTime(address address_) public view returns(uint32) {
        require(address_ != address(0x0), "");
        return _getAddressMinUnlockTime(address_);
    }

    function _getAddressAmount(address address_) private view returns(uint256, uint32) {
        return (stakingAddressAmount[address_].totalAmount, stakingAddressAmount[address_].actionTime);
    }

    function _getAddressMinUnlockTime(address address_) private view returns(uint32) {
        return stakingAddressAmount[address_].actionTime + _minLockDay * 3600;
    }

    function setMinLockDay(uint32 minLockDay_) external onlyOwner {
        require(minLockDay_ > 36500, "Flan Staking: Too long");
        _minLockDay = minLockDay_;
    }

    function getMinLockDay() public view returns(uint32) {
        return _minLockDay;
    }

    function _getCurrentTime() private view returns(uint32) {
        return uint32(block.timestamp);
    }
}
