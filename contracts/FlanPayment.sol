// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/*
 * FlanTokenStaking
 *
*/
contract FlanTokenStaking is Context, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 private _token;
    uint256 private _decimal = 18;
    uint32 private _minLockDay = 7;

    uint256 public totalStakedAmount = 0;

    struct Member {
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

        _token.safeTransferFrom(msg.sender, address(this), amount_);
        totalStakedAmount += amount_;
        emit Stake(msg.sender, amount_);
    }

    function withdrawAmount(uint256 amount_) external payable {
        require(msg.sender != address(0x0), "Flan Staking: None address!");
        uint256 amount = _withdrawAmount(payable(msg.sender), amount_);
        totalStakedAmount -= amount;
        emit WithdrawAmount(msg.sender, amount);
    }

    function withdrawAll() external payable {
        require(msg.sender != address(0x0), "");
        uint256 amount = stakingAddressAmount[msg.sender].totalAmount;
        amount = _withdrawAmount(payable(msg.sender), amount);
        totalStakedAmount -= amount;
        emit WithdrawAll(msg.sender, amount);
    }

    function _withdrawAmount(address payable address_, uint256 amount_) internal virtual returns (uint256) {
        require(amount_ > 0, "Flan Staking: requested amount == 0");
        require(stakingAddressAmount[address_].totalAmount >= amount_, "Flan Staking: Balance < requested amount");
        require(_getCurrentTime() >= stakingAddressAmount[address_].actionTime + _minLockDay * 3600, "Flan Staking: Lock Period");
        _token.safeTransfer(msg.sender, amount_);
        stakingAddressAmount[msg.sender].totalAmount -= amount_;
        stakingAddressAmount[msg.sender].actionTime = uint32(block.timestamp);
        return amount_;
    }

    function getAmountOfMember(address address_) public view returns (uint256, uint32) {
        require(address_ != address(0x0), "");
        (uint256 amount, uint32 time) = _getAddressAmount(address_);
        return (amount, time);
    }

    function getAddressMinUnlockTime(address address_) public view returns (uint32) {
        require(address_ != address(0x0), "");
        return _getAddressMinUnlockTime(address_);
    }

    function _getAddressAmount(address address_) private view returns (uint256, uint32) {
        return (stakingAddressAmount[address_].totalAmount, stakingAddressAmount[address_].actionTime);
    }

    function _getAddressMinUnlockTime(address address_) private view returns (uint32) {
        return stakingAddressAmount[address_].actionTime + _minLockDay * 3600;
    }

    function setMinLockDay(uint32 minLockDay_) external onlyOwner {
        require(minLockDay_ > 36500, "Flan Staking: Too long");
        _minLockDay = minLockDay_;
    }

    function getMinLockDay() public view returns (uint32) {
        return _minLockDay;
    }

    function _getCurrentTime() private view returns (uint32) {
        return uint32(block.timestamp);
    }

    function getTotalStakedAmount() public view returns (uint256) {
        return totalStakedAmount;
    }

    function getTotalBalance() public view returns (uint256) {
        return _token.balanceOf(address(this));
    }
}


/*
 * FlanPayment
 *
*/
contract FlanPayment is Context, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 private _flanToken;
    IERC20 private _cusdToken;
    uint256 private _decimal = 18;

    address private _stakingContractAddress;

    uint256 private _totalCUSDFeeAmount = 0;
    uint256 private _developerCUSDBalance = 0;
    uint256 private _totalFLNFeeAmount = 0;
    uint256 private _developerFLNBalance = 0;
    uint256 private _CUSDTaxFeeAmount = 0;
    uint256 private _FLNTaxFeeAmount = 0;
    uint256 private _paymentId = 0;

    address payable private _developerAddress = payable(address(0x91CfEDfdec464b7537885B59D70d87b25EdB79F0));

    struct FeePlan {
        string name;
        uint256 minStakedAmount;
        uint256 cUSDFeePercent;
        uint256 flanFeePercent;
    }

    FeePlan[] feePlanList;

    struct PaymentData {
        string projectId;
        string taskId;
        address senderAddress;
        address receiptAddress;
        uint256 taskEstimate;
        uint256 feeAmount;
        bool isFLN;
    }

    mapping(uint256 => PaymentData) paymentDataList;

    constructor(address flanAddress_, address cUSDAddress_, address stakingContractAddress_) {
        require(cUSDAddress_ != address(0x0), "");
        require(flanAddress_ != address(0x0), "");
        require(stakingContractAddress_ != address(0x0), "");
        _flanToken = IERC20(flanAddress_);
        _cusdToken = IERC20(cUSDAddress_);
        _stakingContractAddress = stakingContractAddress_;
        init();
    }

    function init() private {
        feePlanList.push(FeePlan({
        name : "F0 Tier",
        minStakedAmount : 0,
        cUSDFeePercent : 12,
        flanFeePercent : 6
        }));

        feePlanList.push(FeePlan({
        name : "F1 Tier",
        minStakedAmount : 100 * 10 ** _decimal,
        cUSDFeePercent : 12,
        flanFeePercent : 5
        }));

        feePlanList.push(FeePlan({
        name : "F2 Tier",
        minStakedAmount : 250 * 10 ** _decimal,
        cUSDFeePercent : 12,
        flanFeePercent : 4
        }));

        feePlanList.push(FeePlan({
        name : "F3 Tier",
        minStakedAmount : 500 * 10 ** _decimal,
        cUSDFeePercent : 10,
        flanFeePercent : 2
        }));

        feePlanList.push(FeePlan({
        name : "F4 Tier",
        minStakedAmount : 1000 * 10 ** _decimal,
        cUSDFeePercent : 6,
        flanFeePercent : 0
        }));
    }

    event Paid(uint256 paymentId_, address indexed senderAddress_, address indexed receiptAddress_, string projectId_, string taskId_, uint256 taskEstimate_, uint256 feeAmount_, bool isFLN_, uint32 paidTime);
    event Withdraw(address indexed address_, uint256 amount_, string indexed type_);

    function getStakedAmount(address address_) private view returns (uint256) {
        (uint256 amount, uint32 time) = FlanTokenStaking(_stakingContractAddress).getAmountOfMember(address_);
        return amount;
    }

    function pay(
        string memory projectId,
        string memory taskId,
        address receiptAddress,
        uint256 taskEstimate,
        bool isFLN
    ) external {
        require(receiptAddress != address(0x0), "");
        uint256 stakedAmount = getStakedAmount(receiptAddress);
        uint256 freelancerGrade = 0;
        for (uint256 i = 0; i < feePlanList.length; i++) {
            if (feePlanList[i].minStakedAmount <= stakedAmount) freelancerGrade = i;
        }
        uint256 feeAmount = 0;
        uint256 taxFeeAmount = taskEstimate * 5 / 1000;
        if (isFLN) {
            feeAmount = taskEstimate * feePlanList[freelancerGrade].flanFeePercent / 100;
            _flanToken.safeTransferFrom(msg.sender, address(this), taskEstimate);
            _flanToken.safeTransfer(receiptAddress, taskEstimate - feeAmount - taxFeeAmount);
            _totalFLNFeeAmount += feeAmount;
            _developerFLNBalance += feeAmount * 5 / 100;
            _FLNTaxFeeAmount += taxFeeAmount;
        } else {
            feeAmount = taskEstimate * feePlanList[freelancerGrade].cUSDFeePercent / 100;
            _cusdToken.safeTransferFrom(msg.sender, address(this), taskEstimate);
            _cusdToken.safeTransfer(receiptAddress, taskEstimate - feeAmount - taxFeeAmount);
            _totalCUSDFeeAmount += feeAmount;
            _developerCUSDBalance += feeAmount * 5 / 100;
            _CUSDTaxFeeAmount += taxFeeAmount;
        }
        PaymentData memory paymentData = PaymentData({
        projectId : projectId,
        taskId : taskId,
        senderAddress : msg.sender,
        receiptAddress : receiptAddress,
        taskEstimate : taskEstimate,
        feeAmount : feeAmount + taxFeeAmount,
        isFLN : isFLN
        });
        _paymentId++;
        paymentDataList[_paymentId] = paymentData;

        emit Paid(_paymentId, msg.sender, receiptAddress, projectId, taskId, taskEstimate, feeAmount + taxFeeAmount, isFLN, _getCurrentTime());
    }

    function withdrawAllCUSD() external onlyOwner {
        uint256 balance = _cusdToken.balanceOf(address(this));
        balance = balance - _developerCUSDBalance;
        _cusdToken.safeTransfer(msg.sender, balance);
        _cusdToken.safeTransfer(_developerAddress, _developerCUSDBalance);
        _developerCUSDBalance = 0;
        _totalCUSDFeeAmount = 0;
        _CUSDTaxFeeAmount = 0;
        emit Withdraw(msg.sender, balance, "cUSD");
        emit Withdraw(_developerAddress, _developerCUSDBalance, "cUSD");
    }

    function withdrawAllFLN() external onlyOwner {
        uint256 balance = _flanToken.balanceOf(address(this));
        balance = balance - _developerFLNBalance;
        _flanToken.safeTransfer(msg.sender, balance);
        _flanToken.safeTransfer(_developerAddress, _developerFLNBalance);
        _developerFLNBalance = 0;
        _totalFLNFeeAmount = 0;
        _FLNTaxFeeAmount = 0;
        emit Withdraw(msg.sender, balance, "FLN");
        emit Withdraw(_developerAddress, _developerFLNBalance, "FLN");
    }

    function withdrawOnlyTaxFee() external onlyOwner {
        _flanToken.safeTransfer(msg.sender, _FLNTaxFeeAmount);
        _cusdToken.safeTransfer(msg.sender, _CUSDTaxFeeAmount);
        _FLNTaxFeeAmount = 0;
        _CUSDTaxFeeAmount = 0;
        emit Withdraw(msg.sender, _FLNTaxFeeAmount, "FLN: Tax Fee");
        emit Withdraw(msg.sender, _CUSDTaxFeeAmount, "cUSD: Tax Fee");
    }

    function withdrawAllByDeveloper() external {
        require(msg.sender == _developerAddress, "not developer");
        _cusdToken.safeTransfer(_developerAddress, _developerCUSDBalance);
        _flanToken.safeTransfer(_developerAddress, _developerFLNBalance);
        _developerCUSDBalance = 0;
        _developerFLNBalance = 0;
        emit Withdraw(_developerAddress, _developerCUSDBalance, "cUSD");
        emit Withdraw(_developerAddress, _developerFLNBalance, "FLN");
    }

    function getDeveloperBalance() external view returns (uint256, uint256){
        require(msg.sender == _developerAddress, "not developer");
        return (_developerCUSDBalance, _developerFLNBalance);
    }

    function getPayment(uint256 paymentId_) public view returns (string memory, string memory, address, address, uint256, uint256, bool) {
        require(paymentId_ != 0, "paymentId is 0");
        require(paymentId_ <= _paymentId, "paymentId is range out");
        PaymentData memory paymentData = paymentDataList[paymentId_];
        return (
        paymentData.projectId,
        paymentData.taskId,
        paymentData.senderAddress,
        paymentData.receiptAddress,
        paymentData.taskEstimate,
        paymentData.feeAmount,
        paymentData.isFLN
        );
    }

    function getTotalFee() external view returns (uint256, uint256) {
        return (_totalCUSDFeeAmount, _totalFLNFeeAmount);
    }

    function getTotalTaxFee() external view returns (uint256, uint256) {
        return (_CUSDTaxFeeAmount, _FLNTaxFeeAmount);
    }

    function getPaymentId() public view returns (uint256) {
        return _paymentId;
    }

    function _getCurrentTime() private view returns (uint32) {
        return uint32(block.timestamp);
    }
}
