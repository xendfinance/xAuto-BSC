// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;
interface IAlpaca {
    function balanceOf(address _owner) external view returns (uint256 balance);
    function debtShareToVal(uint _amount) external view returns (uint);
    function deposit(uint256 _amount) external payable;
    function withdraw(uint256 _share) external;
}