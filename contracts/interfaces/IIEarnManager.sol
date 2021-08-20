pragma solidity ^0.5.0;
interface IIEarnManager {
    function recommend(address _token) external view returns (
      string memory choice,
      uint256 fapr,
      uint256 ftapr,
      uint256 napr,
      uint256 vapr
    );
}