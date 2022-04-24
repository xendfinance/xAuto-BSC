// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/utils/Context.sol";
import '@openzeppelin/contracts/math/SafeMath.sol';
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import {ABDKMath64x64} from "./libraries/ABDKMath64x64.sol";

// Fulcrum
interface IFulcrum {
  function supplyInterestRate() external view returns (uint256);
  function nextSupplyInterestRate(uint256 supplyAmount) external view returns (uint256);
}

interface IFortube {
    function APY() external view returns (uint256);
    function underlying() external view returns (address);
}

interface IVenus {
  function supplyRatePerBlock() external view returns (uint);
}

interface IAlpaca {
  function vaultDebtVal() external view returns (uint256);
  function vaultDebtShare() external view returns (uint256);
  function totalSupply() external view returns (uint256);
  function totalToken() external view returns (uint256);
  function config() external view returns (address);
  function balanceOf(address _token) external view returns (uint256);
  function debtShareToVal(uint256 _amount) external view returns (uint256);
  function fairLaunchPoolId() external view returns (uint256);
  function token() external view returns (address);
}

interface IAlpacaFairLaunch {
  function alpacaPerBlock() external view returns (uint256);
  function poolInfo(uint256 index) external view returns (
    address stakeToken,
    uint256 allocPoint,
    uint256 lastRewardBlock,
    uint256 accAlpacaPerShare,
    uint256 accAlpacaPerShareTilBonusEnd
  );
  function totalAllocPoint() external view returns (uint256);
  function alpaca() external view returns (address);
}

interface IAlpacaConfig {
  function getFairLaunchAddr() external view returns (address);
  function getInterestRate(uint256 debt, uint256 floating) external view returns (uint256);
  function getReservePoolBps() external view returns(uint256);
}

interface IUniswapV2Router02{
  function getAmountsOut(uint256 _amount, address[] calldata path) external view returns (uint256[] memory);
}

contract APRWithPoolOracle is Context, Initializable {
  using SafeMath for uint256;
  using Address for address;

  address private _owner;
  address private _candidate;
  
  bool public fulcrumStatus;
  bool public fortubeStatus;
  bool public venusStatus;
  bool public alpacaStatus;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  constructor() public {}

  function initialize() public initializer{
    address msgSender = _msgSender();
    _owner = msgSender;
    fulcrumStatus = false;
    fortubeStatus = true;
    venusStatus = true;
    alpacaStatus = true;
    emit OwnershipTransferred(address(0), msgSender);
  }
  function getFulcrumAPRAdjusted(address token, uint256 _supply) external view returns(uint256) {
    if(token == address(0) || !fulcrumStatus)
      return 0;
    else
      return IFulcrum(token).supplyInterestRate();
  }

  function getFortubeAPRAdjusted(address token) external view returns (uint256) {
    if(token == address(0) || !fortubeStatus)
      return 0;
    else{
      IFortube fortube = IFortube(token);
      return fortube.APY().mul(1e2);
    }
  }

  function getVenusAPRAdjusted(address token) external view returns (uint256) {
    if(token == address(0) || !venusStatus)
      return 0;
    else{
      uint256 supplyRatePerBlock = IVenus(token).supplyRatePerBlock();
      int128 _temp = ABDKMath64x64.add(ABDKMath64x64.mul(ABDKMath64x64.divu(supplyRatePerBlock, 1e18),ABDKMath64x64.fromUInt(20*60*24)),ABDKMath64x64.fromUInt(1));
      return ABDKMath64x64.mulu(ABDKMath64x64.sub(ABDKMath64x64.pow(_temp, 365),ABDKMath64x64.fromUInt(1)), 1e18)*1e2;
    }
  }

  function getAlpacaAPRAdjusted(address token) external view returns(uint256) {
    if(token == address(0) || !alpacaStatus)
      return 0;
    else{
      IAlpaca alpaca = IAlpaca(token);
      IAlpacaConfig config = IAlpacaConfig(alpaca.config());
      uint256 borrowInterest = config.getInterestRate(alpaca.vaultDebtVal(), alpaca.totalToken() - alpaca.vaultDebtVal()) * 365 * 24 * 3600;
      uint256 lendingApr = borrowInterest * alpaca.vaultDebtVal() / alpaca.totalToken() * (100 - (config.getReservePoolBps() / 100)) / 100;
      uint256 apr = lendingApr;
      return 
        ABDKMath64x64.mulu(
          ABDKMath64x64.sub(
            ABDKMath64x64.exp(ABDKMath64x64.div(ABDKMath64x64.fromUInt(apr), ABDKMath64x64.fromUInt(1e18))),
            ABDKMath64x64.fromUInt(1)
          ),
          1e18
        )*1e2;
    }
  }

  function setFulcrumStatus(bool status) external onlyOwner{
    fulcrumStatus = status;
  }

  function setFortubeStatus(bool status) external onlyOwner{
    fortubeStatus = status;
  }

  function setVenusStatus(bool status) external onlyOwner{
    venusStatus = status;
  }

  function setAlpacaStatus(bool status) external onlyOwner{
    alpacaStatus = status;
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