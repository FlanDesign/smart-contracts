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
contract FlanTokenVesting is Context, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Flan token totalSupply
    uint256 totalSupply = 100000000;
    // Total member count
    uint256 totalMemberCount = 0;
    // Sent member count
    uint256 sentMemberCount = 0;

    // 2022-06-30 GMT as default
    uint256 after6M = 1656547200;
    // 2022-12-31 GMT as default
    uint256 after12M = 1672444800;
    // 2022-12-31 GMT as default
    uint256 after24M = 1703980800;

    uint256 currentTime = 0;

    mapping(address => bool) public admins;

    // Member has locked coins
    struct Member{
        address payable memberAddress;
        uint256 amount;
        bool isSent;
    }

    // Vesting Schedule for advisory, team, pre sale, treasury
    struct VestingSchedule{
        uint256 totalBalance;
        uint256 balance;
        uint256 endTime;
        address payable[] memberAddress;
        uint256[] amount;
        bool[] isSent;
    }

    VestingSchedule[] private vestingScheduleList;

    // Mapping from groupId to list of member index
    mapping(uint256 => mapping(address => uint256)) private vestingMemberIndex;

    IERC20 public _token;

    /**
     * @dev Emitted on addAdmin()
     * @param _address admin address
     **/
    event AddAdmin(address _address);

    /**
     * @dev Emitted on removeAdmin()
     * @param _address admin address
     **/
    event RemoveAdmin(address _address);

    /**
     * @dev Emitted on unlockToken()
     * @param _time run time
     **/
    event UnlockTokens(uint256 _time);

    /**
     * @dev Emitted on withdrawByMember()
     * @param _address member address
     * @param _amount sent amount
     **/
    event WithdrawByMember(address _address, uint256 _amount);

    /**
     * @dev Emitted on withdrawLeftTokens()
     * @param _address member address
     * @param _amount sent amount
     **/
    event WithdrawLeftTokens(address _address, uint256 _amount);

    /**
     * @dev Emitted on addAdvisoryMember()
     * @param _address member address
     * @param _amount locked amount
     * @param _releaseTime expected release time
     **/
    event AddAdvisoryMember(address _address, uint256 _amount, uint256 _releaseTime);

    /**
     * @dev Emitted on addTeamMember()
     * @param _address member address
     * @param _amount locked amount
     * @param _releaseTime expected release time
     **/
    event AddTeamMember(address _address, uint256 _amount, uint256 _releaseTime);

    /**
     * @dev Emitted on addPreSaleMember()
     * @param _address member address
     * @param _amount locked amount
     * @param _releaseTime expected release time
     **/
    event AddPreSaleMember(address _address, uint256 _amount, uint256 _releaseTime);

    /**
     * @dev Emitted on addTreasuryMember()
     * @param _address member address
     * @param _amount locked amount
     * @param _releaseTime expected release time
     **/
    event AddTreasuryMember(address _address, uint256 _amount, uint256 _releaseTime);

    modifier onlyAdmin() {
        require(_msgSender() != address(0x0) && admins[_msgSender()], "Caller is not the admin");
        _;
    }

    /**
     * @dev Deploy contract
     * @param token_ flan token address
     */
    constructor(address token_) {
        require(token_ != address(0x0));
        _token = IERC20(token_);
        totalSupply = _token.totalSupply();
        initialData();
    }

    /**
     * @dev initial data
       - set vesting schedule
     */
    function initialData() private {
        // For Advisory
        vestingScheduleList.push(VestingSchedule({
            totalBalance: totalSupply.mul(5).div(100),
            balance: totalSupply.mul(5).div(100),
            endTime: after6M,
            memberAddress: new address payable[](0),
            amount: new uint256[](0),
            isSent: new bool[](0)
        }));

        // For Team
        vestingScheduleList.push(VestingSchedule({
            totalBalance: totalSupply.mul(10).div(100),
            balance: totalSupply.mul(10).div(100),
            endTime: after6M,
            memberAddress: new address payable[](0),
            amount: new uint256[](0),
            isSent: new bool[](0)
        }));

        // For Private Sale
        vestingScheduleList.push(VestingSchedule({
            totalBalance: totalSupply.mul(15).div(100),
            balance: totalSupply.mul(15).div(100),
            endTime: after6M,
            memberAddress: new address payable[](0),
            amount: new uint256[](0),
            isSent: new bool[](0)
        }));

        // For Treasury
        vestingScheduleList.push(VestingSchedule({
            totalBalance: totalSupply.mul(20).div(100),
            balance: totalSupply.mul(20).div(100),
            endTime: after24M,
            memberAddress: new address payable[](0),
            amount: new uint256[](0),
            isSent: new bool[](0)
        }));

        // add first team member
        _addMember(1, payable(address(0x91CfEDfdec464b7537885B59D70d87b25EdB79F0)), totalSupply.mul(10).div(100).mul(5).div(100));
    }

    /**
     * @dev add admin
       - owner permission
     * @param _address admin address
     */
    function addAdmin(address _address) external onlyOwner {
        require(_address != address(0x0), "Zero address");
        require(!admins[_address], "This address is already added as an admin");
        admins[_address] = true;
        emit AddAdmin(_address);
    }

    /**
     * @dev remove admin
       - owner permission
     * @param _address admin address
     */
    function removeAdmin(address _address) external onlyOwner {
        require(_address != address(0x0), "Zero address");
        require(admins[_address], "This address is not admin");
        admins[_address] = false;
        emit RemoveAdmin(_address);
    }

    /**
     * @dev add advisory member
     * @param _member member address
     * @param _amount locked amount
     */
    function addAdvisoryMember(address payable _member, uint256 _amount) public onlyAdmin {
        require(_member != address(0x0), "FlanVesting::Zero address");
        require(_amount != 0, "FlanVesting::Amount is 0");

        _addMember(0, _member, _amount);

        emit AddAdvisoryMember(_member, _amount, vestingScheduleList[0].endTime);
    }

    /**
     * @dev add team member
     * @param _member member address
     * @param _amount locked amount
     */
    function addTeamMember(address payable _member, uint256 _amount) public onlyAdmin {
        require(_member != address(0x0), "FlanVesting::Zero address");
        require(_amount != 0, "FlanVesting::Amount is 0");

        _addMember(1, _member, _amount);

        emit AddTeamMember(_member, _amount, vestingScheduleList[1].endTime);
    }

    /**
     * @dev add pre sale member
     * @param _member member address
     * @param _amount locked amount
     */
    function addPreSaleMember(address payable _member, uint256 _amount) public onlyAdmin {
        require(_member != address(0x0), "FlanVesting::Zero address");
        require(_amount != 0, "FlanVesting::Amount is 0");

        _addMember(2, _member, _amount);

        emit AddPreSaleMember(_member, _amount, vestingScheduleList[2].endTime);
    }

    /**
     * @dev add treasury member
     * @param _member member address
     * @param _amount locked amount
     */
    function addTreasuryMember(address payable _member, uint256 _amount) public onlyAdmin {
        require(_member != address(0x0), "FlanVesting::Zero address");
        require(_amount != 0, "FlanVesting::Amount is 0");

        _addMember(3, _member, _amount);

        emit AddTreasuryMember(_member, _amount, vestingScheduleList[3].endTime);
    }

    /**
     * @dev withdraw own coins
       - if admin doesn't run the unlock function in time, members can withdraw their unlocked tokens.
     */
    function withdrawByMember() external {
        require(vestingMemberIndex[0][_msgSender()] > 0 || vestingMemberIndex[1][_msgSender()] > 0 || vestingMemberIndex[2][_msgSender()] > 0 || vestingMemberIndex[3][_msgSender()] > 0, "this member isn't registered!");
        uint256 cTime = getCurrentTime();
        for (uint256 i = 0; i < 4; i++) {
            uint256 memberIndex = vestingMemberIndex[i][_msgSender()];
            if (vestingScheduleList[i].endTime < cTime && memberIndex > 0) {
                memberIndex--;
                if (memberIndex < vestingScheduleList[i].memberAddress.length) {
                    if (vestingScheduleList[i].memberAddress[memberIndex] == _msgSender()) {
                        require(!vestingScheduleList[i].isSent[memberIndex], "already sent");
                        _transferToMember(i, memberIndex);
                        emit WithdrawByMember(_msgSender(), vestingScheduleList[i].amount[memberIndex]);
                    }
                }
            }

        }
    }

    /**
     * @dev withdraw contract balance after sent all members
     */
    function withdrawLeftTokens() external onlyOwner {
        require(totalMemberCount <= sentMemberCount, "You can't withdraw now because the vesting period is not end.");
        uint256 contractBalance = _token.balanceOf(address(this));
        _token.transfer(_msgSender(), contractBalance);
        emit WithdrawLeftTokens(_msgSender(), contractBalance);
    }

    /**
     * @dev admin unlocked tokens to members
     */
    function unlockToken() external onlyAdmin {
        require(totalMemberCount > 0, "Please add members");
        require(totalMemberCount > sentMemberCount, "All members already got his coins");
        uint256 cTime = getCurrentTime();
        for (uint256 i = 0; i < 4; i++) {
            VestingSchedule memory vestingSchedule = vestingScheduleList[i];
            if (cTime > vestingSchedule.endTime) {
                for (uint256 j = 0; j < vestingSchedule.memberAddress.length; j++) {
                    _transferToMember(i, j);
                }
            }
        }
    }

    /**
     * @dev add member in vesting schedule
     * @param _groupId vesting id
     * @param _member member address
     * @param _amount locked amount
     */
    function _addMember(uint256 _groupId, address payable _member, uint256 _amount) private {
        VestingSchedule storage vestingSchedule = vestingScheduleList[_groupId];
        require(_amount <= vestingSchedule.balance && _amount > 0, "_amount <= vestingSchedule.balance && _amount > 0");
        require(vestingMemberIndex[_groupId][_member] == 0, "member is already existing.");

        vestingSchedule.memberAddress.push(_member);
        vestingSchedule.amount.push(_amount);
        vestingSchedule.isSent.push(false);
        totalMemberCount++;
        vestingSchedule.balance = vestingSchedule.balance - _amount;
        vestingMemberIndex[_groupId][_member] = vestingSchedule.memberAddress.length;
    }

    /**
     * @dev transfer unlocked token to member
     * @param _groupId vesting id
     * @param _memberId member id
     */
    function _transferToMember(uint256 _groupId, uint256 _memberId) private {
        VestingSchedule storage vestingSchedule = vestingScheduleList[_groupId];
        if (!vestingSchedule.isSent[_memberId]) {
            _token.transfer(vestingSchedule.memberAddress[_memberId], vestingSchedule.amount[_memberId]);
            vestingSchedule.isSent[_memberId] = true;
            sentMemberCount++;
        }
    }

    /**
     * @dev transfer unlocked token to member with member address
     * @param _memberAddress member address
     */
    function _transferToMemberByAddress(address payable _memberAddress) private {
        for (uint256 i = 0; i < 4; i++) {
            if (vestingMemberIndex[i][_memberAddress] > 0) {
                _transferToMember(i, vestingMemberIndex[i][_memberAddress] - 1);
            }
        }
    }

    function getMemberData(address payable _address) external view returns(address, uint256, uint256, bool) {
        (uint256 groupId, uint256 amount, bool isSent) = _getMemberData(_address);
        return (_address, groupId, amount, isSent);
    }

    function _getMemberData(address payable _address) internal view returns(uint256, uint256, bool) {
        for (uint256 i = 0; i < 4; i++) {
            if (vestingMemberIndex[i][_address] > 0) {
                return (
                    i,
                    vestingScheduleList[i].amount[vestingMemberIndex[i][_address] - 1],
                    vestingScheduleList[i].isSent[vestingMemberIndex[i][_address] - 1]
                );
            }
        }
        return (
            100,
            0,
            false
        );
    }

    function getCurrentTime() internal view returns(uint256){
        if (currentTime == 0) return block.timestamp;
        else return currentTime;
    }

    function getToken() external view returns(address){
        return address(_token);
    }

    function getContractBalance() external view returns(uint256) {
        return _token.balanceOf(address(this));
    }

    // for test, MUST REMOVE THIS FUNCTION WHEN DEPLOY THIS CONTRACT ON MAINNET.
    function setCurrentTime(uint256 _currentTime) external  {
        currentTime = _currentTime;
    }
}