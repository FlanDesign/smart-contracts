const { time } = require('@openzeppelin/test-helpers');
const { expect } = require("chai");
const { ethers } = require('hardhat');

const BN = ethers.BigNumber;

const Decimals = BN.from(18);
const OneToken = BN.from(10).pow(Decimals);
const moment = require('moment')

describe("Flan Vesting test", function () {
    let tokenInst, vesting;

    const lockedTotalSupply = OneToken.mul(50000000);

    beforeEach(async () => {
        // deploy Token
        const Token = await ethers.getContractFactory("FlanToken");
        tokenInst = await Token.deploy();
		
		const FlanTokenVesting = await ethers.getContractFactory("FlanTokenVesting");
		vesting = await FlanTokenVesting.deploy(tokenInst.address)
		await tokenInst.transfer(vesting.address, lockedTotalSupply)

		const balanceOfContract = await tokenInst.balanceOf(vesting.address)
		console.log("balance of contract is:" + ethers.utils.formatEther(balanceOfContract));
		
    });

	it("should successfully send tokens to first account", async() => {
        const [owner, member1, member2, member3] = await ethers.getSigners();
		console.log('first member address: ', owner.address);
		await vesting.addAdmin(owner.address)
		// await expect(vesting.unlockToken()).to.be.revertedWith(
        //     "Please add members"
        // );

		const amount0 = OneToken.mul(100000000 * 0.1);
		const amount1 = OneToken.mul(100000000 * 0.1 * 0.05);
		const amount2 = OneToken.mul(100000000 * 0.05 * 0.05);
		await vesting.addTreasuryMember(owner.address, amount0);
		await vesting.addTeamMember(member1.address, amount1);
		await vesting.addPreSaleMember(member2.address, amount2);

		console.log('--------------------------------------')

		let ownerData = await vesting.getMemberData(owner.address);
		let member1Data = await vesting.getMemberData(member1.address);
		let member2Data = await vesting.getMemberData(member2.address);

		console.log('ownerData: ', ownerData[3]);
		console.log('member1Data: ', member1Data[3]);
		console.log('member2Data: ', member2Data[3]);

		console.log('--------------------------------------')

		await time.increaseTo(1656547200 + 1);
		await vesting.unlockToken();

		ownerData = await vesting.getMemberData(owner.address);
		member1Data = await vesting.getMemberData(member1.address);
		member2Data = await vesting.getMemberData(member2.address);

		console.log('ownerData: ', ownerData[3]);
		console.log('member1Data: ', member1Data[3]);
		console.log('member2Data: ', member2Data[3]);

		console.log('--------------------------------------')

		await time.increaseTo(1672444800 + 1);
		await vesting.unlockToken();

		ownerData = await vesting.getMemberData(owner.address);
		member1Data = await vesting.getMemberData(member1.address);
		member2Data = await vesting.getMemberData(member2.address);

		console.log('ownerData: ', ownerData[3]);
		console.log('member1Data: ', member1Data[3]);
		console.log('member2Data: ', member2Data[3]);

		console.log('--------------------------------------')

		await time.increaseTo(1703980800 + 1);
		// await vesting.unlockToken();
		await vesting.withdrawByMember();

		ownerData = await vesting.getMemberData(owner.address);
		member1Data = await vesting.getMemberData(member1.address);
		member2Data = await vesting.getMemberData(member2.address);

		console.log('ownerData: ', ownerData[3]);
		console.log('member1Data: ', member1Data[3]);
		console.log('member2Data: ', member2Data[3]);

		console.log('======================================');

		const balance = await vesting.getContractBalance();
		console.log("balance is:" + ethers.utils.formatEther(balance));
	})
});
