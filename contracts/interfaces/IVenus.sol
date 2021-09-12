// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;
interface IVenus {
    function balanceOf(address _owner) external view returns (uint256 balance);
    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns(uint);
}