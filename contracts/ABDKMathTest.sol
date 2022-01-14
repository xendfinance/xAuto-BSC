// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/utils/Context.sol";
import '@openzeppelin/contracts/math/SafeMath.sol';
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ABDKMath64x64} from "./libraries/ABDKMath64x64.sol";

contract ABDKMathTest{
  using SafeMath for uint256;
  using Address for address;
  // using AttoDecimal for AttoDecimal.Instance;

  // AttoDecimal.Instance private _temp;
  // AttoDecimal.Instance private _decimal;
  function test() external view returns(uint) {
    return ABDKMath64x64.toUInt(ABDKMath64x64.sub(ABDKMath64x64.exp(ABDKMath64x64.divu(1646, 10000)), ABDKMath64x64.fromUInt(1)) * 10**18);
  }
}