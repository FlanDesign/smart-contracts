const { expect } = require("chai");

const BN = ethers.BigNumber;

const Name = "Test Token";
const Symbol = "TEST";
const Decimals = BN.from(18);
const OneToken = BN.from(10).pow(Decimals);

describe("Token test", function () {
    let tokenInst;

    const inititalSupply = OneToken.mul(1000);

    beforeEach(async () => {
        // deploy Token
        const Token = await ethers.getContractFactory("Token");
        tokenInst = await Token.deploy(inititalSupply);
    });

    it("Deploy test", async () => {
        const [owner] = await ethers.getSigners();

        expect(await tokenInst.owner()).to.be.equals(owner.address);

        expect(await tokenInst.totalSupply()).to.be.equals(inititalSupply);
        expect(await tokenInst.balanceOf(owner.address)).to.be.equals(inititalSupply);
        expect(await tokenInst.name()).to.be.equals(Name);
        expect(await tokenInst.symbol()).to.be.equals(Symbol);
        expect(await tokenInst.decimals()).to.be.equals(Decimals);
    });

    it("Test mint", async () => {
        const [owner, user] = await ethers.getSigners();

        const mintAmount = OneToken.mul(10);
        await expect(tokenInst.connect(user).mint(user.address, mintAmount)).to.be.revertedWith(
            "Ownable: caller is not the owner"
        );

        await tokenInst.connect(owner).mint(user.address, mintAmount);

        expect(await tokenInst.totalSupply()).to.be.equals(inititalSupply.add(mintAmount));
        expect(await tokenInst.balanceOf(owner.address)).to.be.equals(inititalSupply);
        expect(await tokenInst.balanceOf(user.address)).to.be.equals(mintAmount);
    });

    it("Test burn", async () => {
        const [owner, user] = await ethers.getSigners();

        const burnAmount = OneToken.mul(10);
        await expect(tokenInst.connect(user).burn(owner.address, burnAmount)).to.be.revertedWith(
            "Ownable: caller is not the owner"
        );

        await tokenInst.connect(owner).burn(owner.address, burnAmount);

        expect(await tokenInst.totalSupply()).to.be.equals(inititalSupply.sub(burnAmount));
        expect(await tokenInst.balanceOf(owner.address)).to.be.equals(
            inititalSupply.sub(burnAmount)
        );
    });
});
