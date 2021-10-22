const { BN, ether, balance } = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const APRWithPoolOracle = artifacts.require('APRWithPoolOracle')
const EarnAPRWithPool = artifacts.require('EarnAPRWithPool')
const XBNB = artifacts.require('XBNB')
const ForceSend = artifacts.require('ForceSend');
const bnbABI = require('./abi/busd');
const { web3 } = require('openzeppelin-test-helpers/src/setup');

// const bnbAddress = '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56';
// const bnbContract = new web3.eth.Contract(bnbABI, bnbAddress);
// const bnbOwner = '0x468c0cfae487a9de23e20d0b29a2835dc058cdf7';

contract('test EarnAPRWithPool', async([alice, bob, admin, dev, minter]) => {

    before(async () => {

        this.xbnbContract = await XBNB.new({
            from: alice
        });
        this.aprWithPoolOracle = await APRWithPoolOracle.new({
            from: alice
        });
        this.earnAPRWithPool = await EarnAPRWithPool.new({
            from: alice
        });

        const forceSend = await ForceSend.new();
        // await forceSend.go(alice, { value: ether('2') });
        // await forceSend.go(admin, { value: ether('10') });
        // await forceSend.go(bob, { value: ether('10') });
        // await forceSend.go(minter, { value: ether('10') });
        // await forceSend.go(dev, { value: ether('10') });
        // await forceSend.go(this.xbnbContract.address, { value: ether('2') });
        
        // await bnbContract.methods.transfer(alice, '10000000000').send({ from: bnbOwner});
        // await bnbContract.methods.transfer(admin, '10000000000').send({ from: bnbOwner});
        // await bnbContract.methods.transfer(bob, '10000000000').send({ from: bnbOwner});
        // await bnbContract.methods.transfer(minter, '10000000000').send({ from: bnbOwner});
        // await bnbContract.methods.transfer(dev, '10000000000').send({ from: bnbOwner});
        

        // await bnbContract.methods.transfer(this.xbnbContract.address, 10000).send({
        //     from: admin
        // });
        console.log('---ended-before---');
    });

    it('recommend test', async() => {
        let aprWithPoolOracle = this.aprWithPoolOracle;
        let earnAPRWithPool = this.earnAPRWithPool;
        let xbnb = this.xbnbContract;
        await earnAPRWithPool.set_new_APR(aprWithPoolOracle.address)
        await xbnb.set_new_APR(earnAPRWithPool.address)
        await xbnb.set_new_fee_address(admin)
        // let balanceOfAlice = await bnbContract.methods.balanceOf(alice).call();
        // let balanceOfAlice = await xbnb.balance();
        let balance = await web3.eth.getBalance(alice);
        console.log('balanceOfAlice', balance);
        balance = await web3.eth.getBalance(xbnb.address);
        console.log('xbnb', balance);

        // await bnbContract.methods.approve(xbnb.address, 1000).send({
        //     from: alice
        // });

        await xbnb.deposit({from: alice, value: ether('1')});
        // await xbnb.deposit({from: admin, value: ether('1')});
        balance = await xbnb.balanceOf(alice);
        console.log('balance', balance.toString());
        // fbalance = await xbnb.balanceFulcrum();
        // console.log('fbalance', fbalance.toString());
        const tokenAmount = await xbnb.balanceOf(alice);
        await xbnb.withdraw(tokenAmount, {from: alice});
        const currentBalance = await xbnb.balanceOf(alice);
        console.log('final_balance', currentBalance.toString());
        balance = await web3.eth.getBalance(admin);
        console.log('admin_balance', balance);
    })
})