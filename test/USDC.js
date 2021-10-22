const { BN, ether, balance } = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const APRWithPoolOracle = artifacts.require('APRWithPoolOracle')
const EarnAPRWithPool = artifacts.require('EarnAPRWithPool')
const XUSDC = artifacts.require('XUSDC')
const ForceSend = artifacts.require('ForceSend');
const usdcABI = require('./abi/usdc');

const usdcAddress = '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d';
const usdcContract = new web3.eth.Contract(usdcABI, usdcAddress);
const usdcOwner = '0x2b258fb1892bc1778f16e940f493a30f1aa711cd';

contract('test EarnAPRWithPool', async([alice, bob, admin, dev, minter]) => {

    before(async () => {

        this.xusdcContract = await XUSDC.new({
            from: alice
        });
        this.aprWithPoolOracle = await APRWithPoolOracle.new({
            from: alice
        });
        this.earnAPRWithPool = await EarnAPRWithPool.new({
            from: alice
        });

        const forceSend = await ForceSend.new();
        await forceSend.go(usdcOwner, { value: ether('1') });
        
        await usdcContract.methods.transfer(alice, '1000000000000000000').send({ from: usdcOwner});
        await usdcContract.methods.transfer(admin, '1000000000000000000').send({ from: usdcOwner});
        console.log('---ended-before---');
    });

    it('recommend test', async() => {
        let aprWithPoolOracle = this.aprWithPoolOracle;
        let earnAPRWithPool = this.earnAPRWithPool;
        let xusdc = this.xusdcContract;
        await earnAPRWithPool.set_new_APR(aprWithPoolOracle.address)
        await xusdc.set_new_APR(earnAPRWithPool.address)

        await usdcContract.methods.approve(xusdc.address, '1000000000000000000').send({
            from: alice
        });

        await xusdc.deposit('1000000000000000000', {from: alice});

        await usdcContract.methods.approve(xusdc.address, '1000000000000000000').send({
            from: admin
        });

        await xusdc.deposit('1000000000000000000', {from: admin});

        const balance = await xusdc.balanceOf(alice);
        console.log('balance', balance.toString());
        const tokenAmount = await xusdc.balanceOf(alice);
        await xusdc.withdraw(tokenAmount, {from: alice});
        const currentBalance = await xusdc.balanceOf(alice);
        console.log('final_balance', currentBalance.toString());
    })
})