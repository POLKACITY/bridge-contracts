// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "./Managed.sol";

contract BridgeLog is Managed {

  event Incoming (address indexed wallet, uint256 amount, uint256 logId);
  event Outgoing (address indexed wallet, uint256 amount, uint256 logId);

  struct OutgoingLog {
    address wallet;
    uint256 amount;
    uint256 fee;
    uint256 date;
    uint256 chainID;
    uint256 bridgeIndex;
  }

  struct IncomingLog {
    address wallet;
    uint256 amount;
    uint256 fee;
    uint256 date;
    uint256 chainID;
    uint256 logIndex;
  }

  mapping(uint256 => OutgoingLog) public outgoingTx;
  mapping(uint256 => IncomingLog) public incomingTx;
  mapping(bytes32 => uint256) public withdrawals;
  mapping(address => bool) public loggers;
  uint256 public outgoingIndex;
  uint256 public incomingIndex;

  constructor() {
    managers[0x00d6E1038564047244Ad37080E2d695924F8515B] = true;
  }

  // set the contracts allowed to create logs
  function setLogger(address _logger, bool _canLog) public onlyManagers {
    loggers[_logger] = _canLog;
  }

  // log bridge transfers send from current chain to any other
  function outgoing(address _wallet, uint256 _amount, uint256 _fee, uint256 _chainID, uint256 _bridgeIndex) public {
    require(loggers[msg.sender] == true, "Invalid caller");
    outgoingIndex += 1;
    OutgoingLog memory _outgoing = OutgoingLog(
      _wallet,
      _amount,
      _fee,
      block.timestamp,
      _chainID,
      _bridgeIndex
    );
    outgoingTx[outgoingIndex] = _outgoing;
    emit Outgoing(_wallet, _amount, outgoingIndex);
  }

  // log bridge transfers received on this chain
  function incoming(address _wallet, uint256 _amount, uint256 _fee, uint256 _chainID, uint256 _logIndex, bytes32 txHash) public {
    require(loggers[msg.sender] == true, "Invalid caller");
    require(!withdrawalCompleted(txHash), "Withdrawal already completed");
    incomingIndex += 1;
    IncomingLog memory _incoming = IncomingLog(
      _wallet,
      _amount,
      _fee,
      block.timestamp,
      _chainID,
      _logIndex
    );
    incomingTx[incomingIndex] = _incoming;
    withdrawals[txHash] = incomingIndex;
    emit Incoming(_wallet, _amount, incomingIndex);
  }

  function getIncomingTx(uint256 _index) public view returns (address wallet, uint256 amount, uint256 fee, uint256 date, uint256 chainID, uint256 logIndex) {
    IncomingLog memory _incoming = incomingTx[_index];
    return (
      _incoming.wallet,
      _incoming.amount,
      _incoming.fee,
      _incoming.date,
      _incoming.chainID,
      _incoming.logIndex
    );
  }

  function getOutgoingTx(uint256 _index) public view returns (address wallet, uint256 amount, uint256 fee, uint256 date, uint256 chainID, uint256 bridgeIndex) {
    OutgoingLog memory _outgoing = outgoingTx[_index];
    return (
      _outgoing.wallet,
      _outgoing.amount,
      _outgoing.fee,
      _outgoing.date,
      _outgoing.chainID,
      _outgoing.bridgeIndex
    );
  }

  // check if the incoming transfer withdrawal is completed
  function withdrawalCompleted(bytes32 _withdrawalId) public view returns (bool completed) {
    return (withdrawals[_withdrawalId] > 0);
  }

}
