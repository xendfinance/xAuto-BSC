pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;
import './libraries/Context.sol';
import './libraries/Ownable.sol';
import './libraries/SafeMath.sol';
import './libraries/Address.sol';
import './interfaces/IERC20.sol';

// Fulcrum
interface IFulcrum {
  function supplyInterestRate() external view returns (uint256);
  function nextSupplyInterestRate(uint256 supplyAmount) external view returns (uint256);
}

interface IFortube {
    function APY() external view returns (uint256);
}

contract APRWithPoolOracle is Ownable {
  using SafeMath for uint256;
  using Address for address;

  function getFulcrumAPRAdjusted(address token, uint256 _supply) public view returns(uint256) {
    if(token == address(0))
      return 0;
    else
      return IFulcrum(token).nextSupplyInterestRate(_supply).mul(1e7);
  }

  function getFortubeAPRAdjusted(address token) public view returns (uint256) {
    if(token == address(0))
      return 0;
    else{
      IFortube fortube = IFortube(token);
      return fortube.APY().mul(1e9);
    }
  }

  function getNerveAPRAdjusted(address token) public view returns (uint256) {
    if(token == address(0))
      return 0;
    else
      return 0;
  }

  function getVenusAPRAdjusted(address token) public view returns (uint256) {
    if(token == address(0))
      return 0;
    else
      return 0;
  }
}
// interestRateStrategyAddress