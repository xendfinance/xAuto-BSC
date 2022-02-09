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
        
        await usdtContract.methods.transfer(alice, '10000000000000000000').send({ from: usdtOwner});
        await usdtContract.methods.transfer(admin, '10000000000000000000').send({ from: usdtOwner});
        await usdtContract.methods.transfer(bob, '10000000000000000000').send({ from: usdtOwner});
        await usdtContract.methods.transfer(minter, '10000000000000000000').send({ from: usdtOwner});
        await usdtContract.methods.transfer(dev, '10000000000000000000').send({ from: usdtOwner});
        
        console.log('---ended-before---');
    });

    it('recommend test', async() => {
        let aprWithPoolOracle = this.aprWithPoolOracle;
        let earnAPRWithPool = this.earnAPRWithPool;
        let xusdt = this.xusdtContract;
        await aprWithPoolOracle.initialize();
        await earnAPRWithPool.initialize(aprWithPoolOracle.address)
        await xusdt.initialize(earnAPRWithPool.address)

        fee_address = await xusdt.feeAddress();
        await xusdt.set_new_feeAmount(10);     
        await usdtContract.methods.approve(xusdt.address, '10000000000000000000').send({
            from: admin
        }); 
        await usdtContract.methods.approve(xusdt.address, '10000000000000000000').send({
            from: alice
        });

        await usdtContract.methods.approve(xusdt.address, '10000000000000000000').send({
            from: dev
        }); 
        await usdtContract.methods.approve(xusdt.address, '10000000000000000000').send({
            from: minter
        });

        await usdtContract.methods.approve(xusdt.address, '10000000000000000000').send({
            from: bob
        });

        console.log('before_xusdt_balance',await usdtContract.methods.balanceOf(xusdt.address).call());
        console.log('before_alice_balance',await usdtContract.methods.balanceOf(alice).call());
        console.log('before_admin_balance',await usdtContract.methods.balanceOf(admin).call());
        console.log('before_dev_balance',await usdtContract.methods.balanceOf(dev).call());
        console.log('before_minter_balance',await usdtContract.methods.balanceOf(minter).call());
        console.log('before_bob_balance',await usdtContract.methods.balanceOf(bob).call());

        await xusdt.deposit('2000000000000000000', {from: admin});
        await xusdt.deposit('2000000000000000000', {from: dev});
        await xusdt.deposit('2000000000000000000', {from: minter});
        await usdtContract.methods.transfer(xusdt.address, '1000000000000000000').send({
            from: admin
        });

        console.log('fee_address_balance', await usdtContract.methods.balanceOf(fee_address).call());

        await xusdt.deposit('2000000000000000000', {from: bob});
        await xusdt.deposit('2000000000000000000', {from: alice});
        
        let tokenAmount = await xusdt.balanceOf(alice);
        console.log('------------', tokenAmount.toString());
        await xusdt.rebalance();
        let provider = await xusdt.provider();
        console.log('provider',provider.toString());

        tokenAmount = await xusdt.balanceOf(alice);
        console.log('alice------------', tokenAmount.toString());
        await xusdt.withdraw(tokenAmount.toString(), {from: alice});
        
        tokenAmount = await xusdt.balanceOf(admin);
        console.log('admin------------', tokenAmount.toString());
        await xusdt.withdraw(tokenAmount.toString(), {from: admin});
        
        tokenAmount = await xusdt.balanceOf(dev);
        console.log('dev------------', tokenAmount.toString());
        await xusdt.withdraw(tokenAmount.toString(), {from: dev});
        
        tokenAmount = await xusdt.balanceOf(minter);
        console.log('minter------------', tokenAmount.toString());
        await xusdt.withdraw(tokenAmount.toString(), {from: minter});

        console.log('fee_address_balance', await usdtContract.methods.balanceOf(fee_address).call());
        
        tokenAmount = await xusdt.balanceOf(bob);
        console.log('bob------------', tokenAmount.toString());
        await xusdt.withdraw((tokenAmount-1).toString(), {from: bob});

        console.log('after_xusdt_balance',await usdtContract.methods.balanceOf(xusdt.address).call());
        console.log('after_alice_balance',await usdtContract.methods.balanceOf(alice).call());
        console.log('after_admin_balance',await usdtContract.methods.balanceOf(admin).call());
        console.log('after_dev_balance',await usdtContract.methods.balanceOf(dev).call());
        console.log('after_minter_balance',await usdtContract.methods.balanceOf(minter).call());
        console.log('after_bob_balance',await usdtContract.methods.balanceOf(bob).call());

        console.log('fee_address_balance', await usdtContract.methods.balanceOf(fee_address).call());
    
    })
})