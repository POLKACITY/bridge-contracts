// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IBridgeLog {
  function outgoing(address _wallet, uint256 _amount, uint256 _fee, uint256 _chainID, uint256 _bridgeIndex) external;
  function incoming(address _wallet, uint256 _amount, uint256 _fee, uint256 _chainID, uint256 _logIndex, bytes32 _txHash) external;
  function withdrawalCompleted(bytes32 _withdrawalId) external view returns (bool completed);
}