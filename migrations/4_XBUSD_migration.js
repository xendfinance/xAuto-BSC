const XBUSD = artifacts.require("XBUSD")
module.exports = async function(deployer) {
  await deployer.deploy(XBUSD);
};