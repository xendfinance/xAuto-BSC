// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
interface Fortube {
    function mint(address receiver, uint256 amount) external payable returns (uint256 mintAmount);
    function withdraw(address receiver, uint256 withdrawTokensIn, uint256 withdrawAmountIn) external view returns(uint256 loanAmountPaid);
    function balanceOf(address _owner) external view returns (uint256 balance);
}