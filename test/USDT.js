const { BN, ether, balance } = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const APRWithPoolOracle = artifacts.require('APRWithPoolOracle')
const EarnAPRWithPool = artifacts.require('EarnAPRWithPool')
const XUSDT = artifacts.require('XUSDT')
const ForceSend = artifacts.require('ForceSend');
const usdtABI = require('./abi/usdt');

const usdtAddress = '0x55d398326f99059fF775485246999027B3197955';
const usdtContract = new web3.eth.Contract(usdtABI, usdtAddress);
const usdtOwner = '0xd6216fc19db775df9774a6e33526131da7d19a2c';

contract('test EarnAPRWithPool', async([alice, bob, admin, dev, minter]) => {

    before(async () => {

        this.xusdtContract = await XUSDT.new({
            from: alice
        });
        this.aprWithPoolOracle = await APRWithPoolOracle.new({
            from: alice
        });
        this.earnAPRWithPool = await EarnAPRWithPool.new({
            from: alice
        });

        const forceSend = await ForceSend.new();
        await forceSend.go(usdtOwner, { value: ether('1') });
        
        await usdtContract.methods.transfer(alice, '1000000000000000000').send({ from: usdtOwner});
        await usdtContract.methods.transfer(admin, '1000000000000000000').send({ from: usdtOwner});
        console.log('---ended-before---');
    });

    it('recommend test', async() => {
        let aprWithPoolOracle = this.aprWithPoolOracle;
        let earnAPRWithPool = this.earnAPRWithPool;
        let xusdt = this.xusdtContract;
        await earnAPRWithPool.set_new_APR(aprWithPoolOracle.address)
        await xusdt.set_new_APR(earnAPRWithPool.address)

        await usdtContract.methods.approve(xusdt.address, '1000000000000000000').send({
            from: alice
        });

        await xusdt.deposit('1000000000000000000', {from: alice});
        await usdtContract.methods.approve(xusdt.address, '1000000000000000000').send({
            from: admin
        });

        await xusdt.deposit('1000000000000000000', {from: admin});

        const balance = await xusdt.balanceOf(alice);
        console.log('balance', balance.toString());
        const tokenAmount = await xusdt.balanceOf(alice);
        await xusdt.withdraw(tokenAmount, {from: alice});
        const currentBalance = await xusdt.balanceOf(alice);
        console.log('final_balance', currentBalance.toString());
    })
})