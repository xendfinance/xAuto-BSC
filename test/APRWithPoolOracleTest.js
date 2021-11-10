const { BN, ether, balance } = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const APRWithPoolOracle = artifacts.require('APRWithPoolOracle')
const EarnAPRWithPool = artifacts.require('EarnAPRWithPool')
// const XBUSD = artifacts.require('XBUSD')
// const ForceSend = artifacts.require('ForceSend');
// const busdABI = require('./abi/busd');

// const busdAddress = '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56';
// const busdContract = new web3.eth.Contract(busdABI, busdAddress);
// const busdOwner = '0x468c0cfae487a9de23e20d0b29a2835dc058cdf7';

contract('test APRWithPoolOracle', async([alice, bob, admin, dev, minter]) => {

    before(async () => {

        // this.xbusdContract = await XBUSD.new({
        //     from: alice
        // });
        this.aprWithPoolOracle = await APRWithPoolOracle.new({
            from: alice
        });
        this.earnAPRWithPool = await EarnAPRWithPool.new({
            from: alice
        });

        // const forceSend = await ForceSend.new();
        // await forceSend.go(busdOwner, { value: ether('1') });
        
        // await busdContract.methods.transfer(alice, '10000000000').send({ from: busdOwner});
        // await busdContract.methods.transfer(admin, '10000000000').send({ from: busdOwner});
        // await busdContract.methods.transfer(bob, '10000000000').send({ from: busdOwner});
        // await busdContract.methods.transfer(minter, '10000000000').send({ from: busdOwner});
        // await busdContract.methods.transfer(dev, '10000000000').send({ from: busdOwner});
        

        // await busdContract.methods.transfer(this.xbusdContract.address, 10000).send({
        //     from: admin
        // });
        console.log('---ended-before---');
    });

    it('recommend test', async() => {
        let aprWithPoolOracle = this.aprWithPoolOracle;
        let earnAPRWithPool = this.earnAPRWithPool;
        // let xbusd = this.xbusdContract;
        await earnAPRWithPool.set_new_APR(aprWithPoolOracle.address)
        // console.log(await earnAPRWithPool.APR());
        // let result = await earnAPRWithPool.recommend('0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56');
        // let result = await earnAPRWithPool.recommend('0x55d398326f99059fF775485246999027B3197955');
        // let result = await earnAPRWithPool.recommend('0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d');
        let result = await earnAPRWithPool.recommend('0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c');
        
        // console.log(result.toString());
        console.log(result['_fulcrum'].toString());
        console.log(result['_fortube'].toString());
        console.log(result['_venus'].toString());
        console.log(result['_alpaca'].toString());
        
        // console.log(await aprWithPoolOracle.getFulcrumAPRAdjusted('0x7343b25c4953f4C57ED4D16c33cbEDEFAE9E8Eb9', 0))
        // console.log(await aprWithPoolOracle.getFortubeAPRAdjusted('0x57160962Dc107C8FBC2A619aCA43F79Fd03E7556'))
        // console.log(await aprWithPoolOracle.getVenusAPRAdjusted('0x95c78222B3D6e262426483D42CfA53685A67Ab9D'))
        // console.log(await aprWithPoolOracle.getAlpacaAPRAdjusted('0x7C9e73d4C71dae564d41F78d56439bB4ba87592f'))
    })
})