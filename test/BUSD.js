const { BN, ether, balance } = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const APRWithPoolOracle = artifacts.require('APRWithPoolOracle')
const EarnAPRWithPool = artifacts.require('EarnAPRWithPool')
const XBUSD = artifacts.require('XBUSD')
const ForceSend = artifacts.require('ForceSend');
const busdABI = require('./abi/busd');

const busdAddress = '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56';
const busdContract = new web3.eth.Contract(busdABI, busdAddress);
const busdOwner = '0x468c0cfae487a9de23e20d0b29a2835dc058cdf7';

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
        
        await busdContract.methods.transfer(alice, '10000000000').send({ from: busdOwner});
        await busdContract.methods.transfer(admin, '10000000000').send({ from: busdOwner});
        await busdContract.methods.transfer(bob, '10000000000').send({ from: busdOwner});
        await busdContract.methods.transfer(minter, '10000000000').send({ from: busdOwner});
        await busdContract.methods.transfer(dev, '10000000000').send({ from: busdOwner});
        

        await busdContract.methods.transfer(this.xbusdContract.address, 10000).send({
            from: admin
        });
        console.log('---ended-before---');
    });

    it('recommend test', async() => {
        let aprWithPoolOracle = this.aprWithPoolOracle;
        let earnAPRWithPool = this.earnAPRWithPool;
        let xbusd = this.xbusdContract;
        await earnAPRWithPool.set_new_APR(aprWithPoolOracle.address)
        await xbusd.set_new_APR(earnAPRWithPool.address)
        let balanceOfAlice = await busdContract.methods.balanceOf(alice).call();
        console.log('balanceOfAlice', balanceOfAlice);

        await busdContract.methods.approve(xbusd.address, 1000).send({
            from: alice
        });

        await xbusd.deposit(1000, {from: alice});
        const balance = await xbusd.balanceOf(alice);
        console.log('balance', balance.toString());
        const tokenAmount = await xbusd.balanceOf(alice);
        await xbusd.withdraw(tokenAmount, {from: alice});
        const currentBalance = await xbusd.balanceOf(alice);
        console.log('final_balance', currentBalance.toString());
    })
})