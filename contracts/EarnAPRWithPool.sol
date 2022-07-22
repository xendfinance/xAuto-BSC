// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";

interface IAPRWithPoolOracle {

  function getFulcrumAPRAdjusted(address token, uint256 _supply) external view returns(uint256);
  function getFortubeAPRAdjusted(address token) external view returns (uint256);
  // function calcVenusAPR(address token) external returns(bool);
  function getVenusAPRAdjusted(address token) external view returns (uint256);
  function getAlpacaAPRAdjusted(address token) external view returns (uint256);

}

contract EarnAPRWithPool is Context, Initializable {
    using SafeMath for uint;
    using Address for address;

    address private _owner;
    address private _candidate;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    mapping(address => uint256) public pools;
    mapping(address => address) public fulcrum;
    mapping(address => address) public fortube;
    mapping(address => address) public venus;
    mapping(address => address) public alpaca;

    address public APR;

    constructor() public {}

    function initialize(
      address _apr
    ) public initializer{
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
        APR = _apr;
        addFToken(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, 0x1a7189Af4e5f58Ddd0b9B195a53E5f4e4b55c949); //fBUSD
        addFToken(0x55d398326f99059fF775485246999027B3197955, 0xC3f6816C860e7d7893508C8F8568d5AF190f6d7d); //fUSDT
        addFToken(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c, 0xB8329B5458B1E493EFd8D9DA8C3B5E6D68e67C21); //fBNB

        addFTToken(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, 0x57160962Dc107C8FBC2A619aCA43F79Fd03E7556); //ftBUSD
        addFTToken(0x55d398326f99059fF775485246999027B3197955, 0xBf9213D046C2c1e6775dA2363fC47F10C4471255); //ftUSDT
        addFTToken(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, 0xb2CB0Af60372E242710c42e1C34579178c3D2BED); //ftUSDC
        addFTToken(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c, 0xf330b39f74e7f71ab9604A5307690872b8125aC8); //ftBNB

        addVToken(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, 0x95c78222B3D6e262426483D42CfA53685A67Ab9D); //vBUSD 2
        addVToken(0x55d398326f99059fF775485246999027B3197955, 0xfD5840Cd36d94D7229439859C0112a4185BC0255); //vUSDT 1
        addVToken(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, 0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8); //vUSDC 0
        addVToken(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c, 0xA07c5b74C9B40447a954e1466938b865b6BBea36); //vBNB

        addAToken(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, 0x7C9e73d4C71dae564d41F78d56439bB4ba87592f); //aBUSD
        addAToken(0x55d398326f99059fF775485246999027B3197955, 0x158Da805682BdC8ee32d52833aD41E74bb951E59); //aUSDT
        addAToken(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, 0x800933D685E7Dc753758cEb77C8bd34aBF1E26d7); //aUSDC
        addAToken(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c, 0xd7D069493685A581d27824Fc46EdA46B7EfC0063); //aBNB
    }

    // Wrapper for legacy v1 token support
    function recommend(address _token) public view returns (
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
        _venus = IAPRWithPoolOracle(APR).getVenusAPRAdjusted(addr);
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
    ) public  {
      require(fulcrum[token] == address(0), "This token is already set.");
        fulcrum[token] = fToken;
    }

    function addFTToken(
      address token,
      address ftToken
    ) public  {
      require(fortube[token] == address(0), "This token is already set.");
        fortube[token] = ftToken;
    }

    function addVToken(
      address token,
      address vToken
    ) public  {
      require(venus[token] == address(0), "This token is already set.");
        venus[token] = vToken;
    }

    function addAToken(
      address token,
      address aToken
    ) public  {
      require(alpaca[token] == address(0), "This token is already set.");
        alpaca[token] = aToken;
    }

    function set_new_APR(address _new_APR) public  {
        APR = _new_APR;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _candidate = newOwner;
    }

    function acceptOwnership() external {
        require(msg.sender == _candidate, "Ownable: not cadidate");
        emit OwnershipTransferred(_owner, _candidate);
        _owner = _candidate;
    }
}