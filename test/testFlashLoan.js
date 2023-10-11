const {assert, expect} = require("chai");
const {ethers} = require("hardhat");

describe("FlashLoan Contract", () => {
    let FLASH_LOAN, BORROW_AMOUNT;
    
    const DECIMALS = 18;
    const BUSD = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";

    beforeEach(async () => {
        const flashLoan = await ethers.getContractFactory("FlashLoan");
        FLASH_LOAN = await flashLoan.deploy();
        await FLASH_LOAN.deployed();
        console.log("FlashLoan contract address: ", FLASH_LOAN.address);

        const borrowAmount = "1";
        BORROW_AMOUNT = ethers.utils.parseUnits(borrowAmount, DECIMALS);
        console.log("Borrow amount: ", BORROW_AMOUNT);
    })

    describe("Arbitrage execution", () => {
        it("executes the arbitrage", async () => {
            const tx_arbitrage = await FLASH_LOAN.initiateArbitrage(BUSD, BORROW_AMOUNT);
            assert(tx_arbitrage);

            const flashLoan_BUSD_balance = await FLASH_LOAN.getBalanceOfToken(BUSD);
            expect(flashLoan_BUSD_balance).equal("0");
        })
    })
})