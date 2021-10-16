const { BN, ether, balance } = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const ABDKMathTest = artifacts.require('ABDKMathTest')

contract('test EarnAPRWithPool', async([alice, bob, admin, dev, minter]) => {

    before(async () => {

        this.aBDKMath = await ABDKMathTest.new({
            from: alice
        });
        console.log('---ended-before---');
    });

    it('abdkMath test', async() => {
        let result = await this.aBDKMath.test();
    
        console.log('test', result.toString());

        // console.log(await xaave.recommend());
    })
})