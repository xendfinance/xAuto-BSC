// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;

import './libraries/Context.sol';
import './libraries/Ownable.sol';
import './interfaces/IERC20.sol';
import './libraries/SafeMath.sol';
import './libraries/Decimal.sol';
import './libraries/Address.sol';

interface IAPRWithPoolOracle {

  function getFulcrumAPRAdjusted(address token, uint256 _supply) external view returns(uint256);
  function getFortubeAPRAdjusted(address token) external view returns (uint256);
  function calcVenusAPR(address token) external returns(bool);
  function getVenusAPRAdjusted() external view returns (uint256);

}

contract EarnAPRWithPool is Ownable {
    using SafeMath for uint;
    using Address for address;

    mapping(address => uint256) public pools;
    mapping(address => address) public fulcrum;
    mapping(address => address) public fortube;
    mapping(address => address) public venus;

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
    }

    // Wrapper for legacy v1 token support
    function recommend(address _token) public returns (
      string memory choice,
      uint256 fapr,
      uint256 ftapr,
      uint256 vapr
    ) {
      (fapr, ftapr, vapr) = getAPROptionsInc(_token);
      return (choice, fapr, ftapr, vapr);
    }

    function getAPROptionsInc(address _token) public returns (
      uint256 _fulcrum,
      uint256 _fortube,
      uint256 _venus
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

      return (
        _fulcrum,
        _fortube,
        _venus
      );
    }

    function addFToken(
      address token,
      address fToken
    ) public onlyOwner {
        fulcrum[token] = fToken;
    }

    function addFTToken(
      address token,
      address ftToken
    ) public onlyOwner {
        fortube[token] = ftToken;
    }

    function addVToken(
      address token,
      address vToken
    ) public onlyOwner {
        venus[token] = vToken;
    }

    function set_new_APR(address _new_APR) public onlyOwner {
        APR = _new_APR;
    }
}