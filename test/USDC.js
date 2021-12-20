const { BN, ether, balance } = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const APRWithPoolOracle = artifacts.require('APRWithPoolOracle')
const EarnAPRWithPool = artifacts.require('EarnAPRWithPool')
const XUSDC = artifacts.require('XUSDC')
const ForceSend = artifacts.require('ForceSend');
const usdcABI = require('./abi/usdc');

const usdcAddress = '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d';
const usdcContract = new web3.eth.Contract(usdcABI, usdcAddress);
const usdcOwner = '0x526d47FedF9651a8db7d2E2cc2e68cC4c1849783';

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
        await usdcContract.methods.transfer(bob, '1000000000000000000').send({ from: usdcOwner});
        await usdcContract.methods.transfer(minter, '1000000000000000000').send({ from: usdcOwner});
        await usdcContract.methods.transfer(dev, '1000000000000000000').send({ from: usdcOwner});
        
        console.log('---ended-before---');
    });

    it('recommend test', async() => {
        let aprWithPoolOracle = this.aprWithPoolOracle;
        let earnAPRWithPool = this.earnAPRWithPool;
        let xusdc = this.xusdcContract;
        await aprWithPoolOracle.initialize();
        await earnAPRWithPool.initialize(aprWithPoolOracle.address)
        await xusdc.initialize(earnAPRWithPool.address)

        fee_address = await xusdc.feeAddress();
        await xusdc.set_new_feeAmount(10);     
        await usdcContract.methods.approve(xusdc.address, '1000000000000000000').send({
            from: admin
        }); 
        await usdcContract.methods.approve(xusdc.address, '1000000000000000000').send({
            from: alice
        });

        await usdcContract.methods.approve(xusdc.address, '1000000000000000000').send({
            from: dev
        }); 
        await usdcContract.methods.approve(xusdc.address, '1000000000000000000').send({
            from: minter
        });

        await usdcContract.methods.approve(xusdc.address, '1000000000000000000').send({
            from: bob
        });

        console.log('before_xusdc_balance',await usdcContract.methods.balanceOf(xusdc.address).call());
        console.log('before_alice_balance',await usdcContract.methods.balanceOf(alice).call());
        console.log('before_admin_balance',await usdcContract.methods.balanceOf(admin).call());
        console.log('before_dev_balance',await usdcContract.methods.balanceOf(dev).call());
        console.log('before_minter_balance',await usdcContract.methods.balanceOf(minter).call());
        console.log('before_bob_balance',await usdcContract.methods.balanceOf(bob).call());

        await xusdc.deposit('8000000', {from: admin});
        await xusdc.deposit('10000000', {from: dev});
        await xusdc.deposit('10000000', {from: minter});

        await usdcContract.methods.transfer(xusdc.address, '500000').send({
            from: admin
        });

        // console.log('fee_address_balance', await usdcContract.methods.balanceOf(fee_address).call());
        // await xusdc.withdrawFee({from : alice});
        // console.log('fee_address_balance', await usdcContract.methods.balanceOf(fee_address).call());

        await xusdc.deposit('2000000', {from: bob});
        await xusdc.deposit('5000000', {from: alice});
        
        let tokenAmount = await xusdc.balanceOf(alice);
        console.log('------------', tokenAmount.toString());
        await xusdc.rebalance();
        let provider = await xusdc.provider();
        console.log('provider',provider.toString());

        tokenAmount = await xusdc.balanceOf(alice);
        console.log('alice------------', tokenAmount.toString());
        await xusdc.withdraw(tokenAmount.toString(), {from: alice});
        
        tokenAmount = await xusdc.balanceOf(admin);
        console.log('admin------------', tokenAmount.toString());
        await xusdc.withdraw(tokenAmount.toString(), {from: admin});
        
        tokenAmount = await xusdc.balanceOf(dev);
        console.log('dev------------', tokenAmount.toString());
        await xusdc.withdraw(tokenAmount.toString(), {from: dev});
        
        tokenAmount = await xusdc.balanceOf(minter);
        console.log('minter------------', tokenAmount.toString());
        await xusdc.withdraw(tokenAmount.toString(), {from: minter});

        console.log('fee_address_balance', await usdcContract.methods.balanceOf(fee_address).call());
        await xusdc.withdrawFee({from : alice});
        console.log('fee_address_balance', await usdcContract.methods.balanceOf(fee_address).call());
        
        tokenAmount = await xusdc.balanceOf(bob);
        console.log('bob------------', tokenAmount.toString());
        await xusdc.withdraw(tokenAmount.toString(), {from: bob});

        console.log('after_xusdc_balance',await usdcContract.methods.balanceOf(xusdc.address).call());
        console.log('after_alice_balance',await usdcContract.methods.balanceOf(alice).call());
        console.log('after_admin_balance',await usdcContract.methods.balanceOf(admin).call());
        console.log('after_dev_balance',await usdcContract.methods.balanceOf(dev).call());
        console.log('after_minter_balance',await usdcContract.methods.balanceOf(minter).call());
        console.log('after_bob_balance',await usdcContract.methods.balanceOf(bob).call());

        console.log('fee_address_balance', await usdcContract.methods.balanceOf(fee_address).call());
        await xusdc.withdrawFee({from : alice});
        console.log('fee_address_balance', await usdcContract.methods.balanceOf(fee_address).call());
    
    })
})