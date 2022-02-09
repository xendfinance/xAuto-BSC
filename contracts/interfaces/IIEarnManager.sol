// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
interface IIEarnManager {
    function recommend(address _token) external view returns (
      uint256 _fulcrum,
      uint256 _fortube,
      uint256 _venus,
      uint256 _alpaca
    );
}