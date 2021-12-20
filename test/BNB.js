const { BN, ether, balance } = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const APRWithPoolOracle = artifacts.require('APRWithPoolOracle')
const EarnAPRWithPool = artifacts.require('EarnAPRWithPool')
const XBNB = artifacts.require('XBNB')
const ForceSend = artifacts.require('ForceSend');
const { web3 } = require('openzeppelin-test-helpers/src/setup');

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
        console.log('---ended-before---');
    });

    it('recommend test', async() => {
        let aprWithPoolOracle = this.aprWithPoolOracle;
        let earnAPRWithPool = this.earnAPRWithPool;
        let xbnb = this.xbnbContract;
        await aprWithPoolOracle.initialize();
        await earnAPRWithPool.initialize(aprWithPoolOracle.address)
        await xbnb.initialize(earnAPRWithPool.address)

        let balance = await web3.eth.getBalance(alice);
        console.log('balanceOfAlice', balance);
        balance = await web3.eth.getBalance(xbnb.address);
        console.log('xbnb', balance);
        await xbnb.set_new_feeAmount(10);
        let fee_address = await xbnb.feeAddress();
        console.log('fee_address: ', fee_address);

        await xbnb.deposit({from: alice, value: ether('1')});
        await xbnb.deposit({from: admin, value: ether('2')});
        await xbnb.deposit({from: bob, value: ether('3')});
        await web3.eth.sendTransaction({
            from: alice,
            to: xbnb.address,
            value: '10000000',
        })
        console.log('xbnb_balance', await web3.eth.getBalance(xbnb.address));
        console.log('fee_address_balance', await web3.eth.getBalance(fee_address));
        await xbnb.withdrawFee({from : alice});
        console.log('fee_address_balance', await web3.eth.getBalance(fee_address));
        await xbnb.deposit({from: dev, value: ether('2')});
        await xbnb.deposit({from: minter, value: ether('10')});
        balance = await xbnb.balanceOf(alice);
        console.log('balance', balance.toString());

        let tokenAmount = await xbnb.balanceOf(alice);
        await xbnb.withdraw(tokenAmount, {from: alice});
        let currentBalance = await xbnb.balanceOf(alice);
        console.log('final_balance', currentBalance.toString());
        balance = await web3.eth.getBalance(alice);
        console.log('alice_balance', balance);

        tokenAmount = await xbnb.balanceOf(admin);
        await xbnb.withdraw(tokenAmount, {from: admin});
        currentBalance = await xbnb.balanceOf(admin);
        console.log('final_balance', currentBalance.toString());
        balance = await web3.eth.getBalance(admin);
        console.log('admin_balance', balance);

        tokenAmount = await xbnb.balanceOf(dev);
        await xbnb.withdraw(tokenAmount, {from: dev});
        currentBalance = await xbnb.balanceOf(dev);
        console.log('final_balance', currentBalance.toString());
        balance = await web3.eth.getBalance(dev);
        console.log('dev_balance', balance);

        tokenAmount = await xbnb.balanceOf(bob);
        await xbnb.withdraw(tokenAmount, {from: bob});
        currentBalance = await xbnb.balanceOf(bob);
        console.log('final_balance', currentBalance.toString());
        balance = await web3.eth.getBalance(bob);
        console.log('bob_balance', balance);

        tokenAmount = await xbnb.balanceOf(minter);
        await xbnb.withdraw(tokenAmount, {from: minter});
        currentBalance = await xbnb.balanceOf(minter);
        console.log('final_balance', currentBalance.toString());
        balance = await web3.eth.getBalance(minter);
        console.log('minter_balance', balance);

        console.log('fee_address_balance', await web3.eth.getBalance(fee_address));
        await xbnb.withdrawFee({from : alice});
        console.log('fee_address_balance', await web3.eth.getBalance(fee_address));
    })
})