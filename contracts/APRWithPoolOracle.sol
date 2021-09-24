// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/utils/Context.sol";
// import '@openzeppelin/contracts/math/SafeMath.sol';
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/Ownable.sol";
import "./libraries/AttoDecimal.sol";

// Fulcrum
interface IFulcrum {
  function supplyInterestRate() external view returns (uint256);
  function nextSupplyInterestRate(uint256 supplyAmount) external view returns (uint256);
}

interface IFortube {
    function APY() external view returns (uint256);
}

interface IVenus {
  function supplyRatePerBlock() external view returns (uint);
}

contract APRWithPoolOracle is Ownable {
  using SafeMath for uint256;
  using Address for address;
  using AttoDecimal for AttoDecimal.Instance;

  AttoDecimal.Instance private _temp;
  AttoDecimal.Instance private _decimal;
  function getFulcrumAPRAdjusted(address token, uint256 _supply) external view returns(uint256) {
    if(token == address(0))
      return 0;
    else
      return IFulcrum(token).nextSupplyInterestRate(_supply);
  }

  function getFortubeAPRAdjusted(address token) external view returns (uint256) {
    if(token == address(0))
      return 0;
    else{
      IFortube fortube = IFortube(token);
      return fortube.APY().mul(100);
    }
  }

  function getVenusAPRAdjusted() external view returns (uint256) {
    return getVenusAPRValue();
  }

  function getVenusAPRValue()
    public
    view
    returns (
        uint256 value
    )
  {
      return _decimal.getValue();
  }

  function calcVenusAPR(address token) external returns (bool success) {
    uint256 supplyRatePerBlock = IVenus(token).supplyRatePerBlock();
    _temp = AttoDecimal.convert(supplyRatePerBlock).div(1000000000000000000).mul(20*60*24).add(1);
    _decimal = _temp;
    uint i = 0;
    for (; i < 365; i ++ ){
      _decimal = _decimal.mul(_temp);
    }
    _decimal = _decimal.sub(1).mul(100);
    return true;
  }
}