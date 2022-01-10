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
        
        await busdContract.methods.transfer(alice, '10000000000000000000').send({ from: busdOwner});
        await busdContract.methods.transfer(admin, '10000000000000000000').send({ from: busdOwner});
        await busdContract.methods.transfer(bob, '10000000000000000000').send({ from: busdOwner});
        await busdContract.methods.transfer(minter, '10000000000000000000').send({ from: busdOwner});
        await busdContract.methods.transfer(dev, '10000000000000000000').send({ from: busdOwner});
        
        console.log('---ended-before---');
    });

    it('recommend test', async() => {
        let aprWithPoolOracle = this.aprWithPoolOracle;
        let earnAPRWithPool = this.earnAPRWithPool;
        let xbusd = this.xbusdContract;
        await aprWithPoolOracle.initialize();
        await earnAPRWithPool.initialize(aprWithPoolOracle.address)
        await xbusd.initialize(earnAPRWithPool.address)

        fee_address = await xbusd.feeAddress();
        await xbusd.set_new_feeAmount(10);     
        await busdContract.methods.approve(xbusd.address, '10000000000000000000').send({
            from: admin
        }); 
        await busdContract.methods.approve(xbusd.address, '10000000000000000000').send({
            from: alice
        });

        await busdContract.methods.approve(xbusd.address, '10000000000000000000').send({
            from: dev
        }); 
        await busdContract.methods.approve(xbusd.address, '10000000000000000000').send({
            from: minter
        });

        await busdContract.methods.approve(xbusd.address, '10000000000000000000').send({
            from: bob
        });

        console.log('before_xbusd_balance',await busdContract.methods.balanceOf(xbusd.address).call());
        console.log('before_alice_balance',await busdContract.methods.balanceOf(alice).call());
        console.log('before_admin_balance',await busdContract.methods.balanceOf(admin).call());
        console.log('before_dev_balance',await busdContract.methods.balanceOf(dev).call());
        console.log('before_minter_balance',await busdContract.methods.balanceOf(minter).call());
        console.log('before_bob_balance',await busdContract.methods.balanceOf(bob).call());

        await xbusd.deposit('2000000000000000000', {from: admin});
        await xbusd.deposit('2000000000000000000', {from: dev});
        await xbusd.deposit('2000000000000000000', {from: minter});
        await busdContract.methods.transfer(xbusd.address, '1000000000000000000').send({
            from: admin
        });

        console.log('fee_address_balance', await busdContract.methods.balanceOf(fee_address).call());
        await xbusd.withdrawFee({from : alice});
        console.log('fee_address_balance', await busdContract.methods.balanceOf(fee_address).call());

        await xbusd.deposit('2000000000000000000', {from: alice});
        await xbusd.deposit('2000000000000000000', {from: bob});
        
        let tokenAmount = await xbusd.balanceOf(alice);
        console.log('------------', tokenAmount.toString());
        await xbusd.rebalance();
        let provider = await xbusd.provider();
        console.log('provider',provider.toString());

        tokenAmount = await xbusd.balanceOf(admin);
        console.log('admin------------', tokenAmount.toString());
        await xbusd.withdraw(tokenAmount.toString(), {from: admin});
        
        tokenAmount = await xbusd.balanceOf(dev);
        console.log('dev------------', tokenAmount.toString());
        await xbusd.withdraw(tokenAmount.toString(), {from: dev});
        
        tokenAmount = await xbusd.balanceOf(minter);
        console.log('minter------------', tokenAmount.toString());
        await xbusd.withdraw(tokenAmount.toString(), {from: minter});

        tokenAmount = await xbusd.balanceOf(bob);
        console.log('bob------------', tokenAmount.toString());
        await xbusd.withdraw(tokenAmount.toString(), {from: bob});

        console.log('fee_address_balance', await busdContract.methods.balanceOf(fee_address).call());
        await xbusd.withdrawFee({from : alice});
        console.log('fee_address_balance', await busdContract.methods.balanceOf(fee_address).call());
        
        tokenAmount = await xbusd.balanceOf(alice);
        console.log('alice------------', tokenAmount.toString());
        await xbusd.withdraw(tokenAmount.toString(), {from: alice});

        console.log('after_xbusd_balance',await busdContract.methods.balanceOf(xbusd.address).call());
        console.log('after_alice_balance',await busdContract.methods.balanceOf(alice).call());
        console.log('after_admin_balance',await busdContract.methods.balanceOf(admin).call());
        console.log('after_dev_balance',await busdContract.methods.balanceOf(dev).call());
        console.log('after_minter_balance',await busdContract.methods.balanceOf(minter).call());
        console.log('after_bob_balance',await busdContract.methods.balanceOf(bob).call());

        console.log('fee_address_balance', await busdContract.methods.balanceOf(fee_address).call());
        await xbusd.withdrawFee({from : alice});
        console.log('fee_address_balance', await busdContract.methods.balanceOf(fee_address).call());
    
    })
})