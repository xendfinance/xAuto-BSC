const { BN, ether, balance } = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const APRWithPoolOracle = artifacts.require('APRWithPoolOracle')
const EarnAPRWithPool = artifacts.require('EarnAPRWithPool')
const XBUSD = artifacts.require('XBUSD')
const ForceSend = artifacts.require('ForceSend');
const busdABI = require('./abi/busd');

const busdAddress = '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56';
const busdContract = new web3.eth.Contract(busdABI, busdAddress);
const busdOwner = '0xD5fFaab18cE0E5A50BE03392388BA0b147b218bD';

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
        

        // let xaave = this.xaaveContract

        // await aaveContract.methods.approve(xaave.address, 10000000).send({
        //     from: alice
        // });

        // await xaave.deposit(10000000, {from: alice});
        console.log('---ended-before---');
    });

    it('recommend test', async() => {
        let aprWithPoolOracle = this.aprWithPoolOracle;
        let earnAPRWithPool = this.earnAPRWithPool;
        let xbusd = this.xbusdContract;
        await earnAPRWithPool.set_new_APR(aprWithPoolOracle.address)
        await xbusd.set_new_APR(earnAPRWithPool.address)

        await busdContract.methods.approve(xbusd.address, 10000000).send({
            from: alice
        });

        await xbusd.deposit(10000000, {from: alice});
        const balance = await xbusd.balanceOf(alice);
        console.log('balance', balance.toString());
        const tokenAmount = await xbusd.balanceOf(alice);
        await xbusd.withdraw(tokenAmount, {from: alice});
        const currentBalance = await xbusd.balanceOf(alice);
        console.log('final_balance', currentBalance.toString());
    })
})