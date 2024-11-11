// SPDX-License-Identifier: MIT

// This contract stores and verify accounts with administratives privileges

pragma solidity 0.8.7;

contract Managed {
  event AddManager(address Wallet);
  event RemoveManager(address Wallet);
  mapping(address => bool) public managers;
  modifier onlyManagers() {
    require(managers[msg.sender] == true, "Caller is not manager");
    _;
  }
  constructor() {
    managers[msg.sender] = true;
    emit AddManager(msg.sender);
  }
  function setManager(address _wallet, bool _manager) public onlyManagers {
    require(_wallet != msg.sender, "Not allowed");
    require(_wallet != address(0), "Invalid address");
    managers[_wallet] = _manager;
    if (_manager) {
      emit AddManager(_wallet);
    } else {
      emit RemoveManager(_wallet);
    }
  }
}