// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./libraries/Ownable.sol";

interface IAPRWithPoolOracle {

  function getFulcrumAPRAdjusted(address token, uint256 _supply) external view returns(uint256);
  function getFortubeAPRAdjusted(address token) external view returns (uint256);
  function calcVenusAPR(address token) external returns(bool);
  function getVenusAPRAdjusted() external view returns (uint256);
  function getAlpacaAPRAdjusted(address token) external view returns (uint256);

}

contract EarnAPRWithPool is Ownable {
    using SafeMath for uint;
    using Address for address;

    mapping(address => uint256) public pools;
    mapping(address => address) public fulcrum;
    mapping(address => address) public fortube;
    mapping(address => address) public venus;
    mapping(address => address) public alpaca;

    address public APR;

    constructor() public {
        //mainnet
        APR = address(0x0bCf5B3603fe34428Ac460C52674F12517d7C9aE);

        addFToken(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, 0x7343b25c4953f4C57ED4D16c33cbEDEFAE9E8Eb9); //fBUSD
        addFToken(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, 0xf326b42A237086F1De4E7D68F2d2456fC787bc01); //fUSDT
        // addFToken(0x55d398326f99059fF775485246999027B3197955, 0x2E1A74a16e3a9F8e3d825902Ab9fb87c606cB13f); //fUSDC

        addFTToken(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, 0x57160962Dc107C8FBC2A619aCA43F79Fd03E7556); //ftBUSD
        addFTToken(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, 0xBf9213D046C2c1e6775dA2363fC47F10C4471255); //ftUSDT
        addFTToken(0x55d398326f99059fF775485246999027B3197955, 0xb2CB0Af60372E242710c42e1C34579178c3D2BED); //ftUSDC

        addVToken(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, 0x95c78222B3D6e262426483D42CfA53685A67Ab9D); //vBUSD 2
        addVToken(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, 0xfD5840Cd36d94D7229439859C0112a4185BC0255); //vUSDT 1
        addVToken(0x55d398326f99059fF775485246999027B3197955, 0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8); //vUSDC 0

        addAToken(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, 0x7C9e73d4C71dae564d41F78d56439bB4ba87592f); //aBUSD
        addAToken(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, 0x158Da805682BdC8ee32d52833aD41E74bb951E59); //aUSDT
    }

    // Wrapper for legacy v1 token support
    function recommend(address _token) public returns (
      uint256 _fulcrum,
      uint256 _fortube,
      uint256 _venus,
      uint256 _alpaca
    ) {

      address addr;
      addr = fulcrum[_token];
      if (addr != address(0)) {
        _fulcrum = IAPRWithPoolOracle(APR).getFulcrumAPRAdjusted(addr, 0);
      }
      addr = fortube[_token];
      if (addr != address(0)) {
        _fortube = IAPRWithPoolOracle(APR).getFortubeAPRAdjusted(addr);
      }
      addr = venus[_token];
      if (addr != address(0)) {
        IAPRWithPoolOracle(APR).calcVenusAPR(addr);
        _venus = IAPRWithPoolOracle(APR).getVenusAPRAdjusted();
      }
      addr = alpaca[_token];
      if (addr != address(0)) {
        _alpaca = IAPRWithPoolOracle(APR).getAlpacaAPRAdjusted(addr);
      }

      return (
        _fulcrum,
        _fortube,
        _venus,
        _alpaca
      );
    }

    function addFToken(
      address token,
      address fToken
    ) public onlyOwner {
      require(fulcrum[token] == address(0), "This token is already set.");
        fulcrum[token] = fToken;
    }

    function addFTToken(
      address token,
      address ftToken
    ) public onlyOwner {
      require(fortube[token] == address(0), "This token is already set.");
        fortube[token] = ftToken;
    }

    function addVToken(
      address token,
      address vToken
    ) public onlyOwner {
      require(venus[token] == address(0), "This token is already set.");
        venus[token] = vToken;
    }

    function addAToken(
      address token,
      address aToken
    ) public onlyOwner {
      require(alpaca[token] == address(0), "This token is already set.");
        alpaca[token] = aToken;
    }

    function set_new_APR(address _new_APR) public onlyOwner {
        APR = _new_APR;
    }
}