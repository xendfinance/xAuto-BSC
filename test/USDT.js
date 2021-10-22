const { BN, ether, balance } = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const APRWithPoolOracle = artifacts.require('APRWithPoolOracle')
const EarnAPRWithPool = artifacts.require('EarnAPRWithPool')
const XBUSD = artifacts.require('XBUSD')
const ForceSend = artifacts.require('ForceSend');
const busdABI = require('./abi/busd');

const busdAddress = '0x55d398326f99059fF775485246999027B3197955';
const busdContract = new web3.eth.Contract(busdABI, busdAddress);
const busdOwner = '0xd6216fc19db775df9774a6e33526131da7d19a2c';

contract('test EarnAPRWithPool', async([alice, bob, admin, dev, minter]) => {

    before(async () => {

        this.xbusdContract = await XBUSD.new({
            from: alice
        });
        this.aprWithPoolOracle = await APRWithPoolOracle.new({
            from: alice
        });
        this.earnAPRWithPool = await EarnAPRWithPool.new({
            from: alice
        });

        const forceSend = await ForceSend.new();
        await forceSend.go(busdOwner, { value: ether('1') });
        
        await busdContract.methods.transfer(alice, '1000000000000000000').send({ from: busdOwner});
        await busdContract.methods.transfer(admin, '1000000000000000000').send({ from: busdOwner});
        console.log('---ended-before---');
    });

    it('recommend test', async() => {
        let aprWithPoolOracle = this.aprWithPoolOracle;
        let earnAPRWithPool = this.earnAPRWithPool;
        let xbusd = this.xbusdContract;
        await earnAPRWithPool.set_new_APR(aprWithPoolOracle.address)
        await xbusd.set_new_APR(earnAPRWithPool.address)

        await busdContract.methods.approve(xbusd.address, '1000000000000000000').send({
            from: alice
        });

        await xbusd.deposit('1000000000000000000', {from: alice});
        await busdContract.methods.approve(xbusd.address, '1000000000000000000').send({
            from: admin
        });

        await xbusd.deposit('1000000000000000000', {from: admin});

        const balance = await xbusd.balanceOf(alice);
        console.log('balance', balance.toString());
        const tokenAmount = await xbusd.balanceOf(alice);
        await xbusd.withdraw(tokenAmount, {from: alice});
        const currentBalance = await xbusd.balanceOf(alice);
        console.log('final_balance', currentBalance.toString());
    })
})