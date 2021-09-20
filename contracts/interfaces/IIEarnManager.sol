// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;
interface IIEarnManager {
    function recommend(address _token) external view returns (
      uint256 fapr,
      uint256 aapr,
      uint256 ftapr
    );
}