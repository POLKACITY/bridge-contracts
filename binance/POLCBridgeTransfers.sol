// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "./IERC20Token.sol";
import "./IBridgeLog.sol";
import "./Managed.sol";

contract POLCBridgeTransfers is Managed {
  event NewTransfer(address indexed sender, uint256 chainTo, uint256 amount);
  event VaultChange(address vault);
  event FeeChange(uint256 fee);
  event TXLimitChange(uint256 minTX, uint256 maxTX);
  event LoggerChange(address _logger);
  event ChainUpdate(uint256 chain, bool available);
  event PauseTransfers(bool paused);

  address public polcVault;
  address public polcTokenAddress;
  uint256 public bridgeFee;
  IERC20Token private polcToken;
  uint256 public depositIndex;
  IBridgeLog public logger;
  bool public paused;
  
  struct Deposit {
      address sender;
      uint256 amount;
      uint256 fee;
      uint256 chainTo;
  } 
  
  mapping (uint256 => Deposit) public deposits;
  mapping (address => bool) public whitelisted;
  mapping (uint256 => bool) public chains;
  uint256 public maxTXAmount = 25000 ether;
  uint256 public minTXAmount = 50 ether;
    
  constructor() {
    polcTokenAddress = 0x6Ae9701B9c423F40d54556C9a443409D79cE170a;
    logger = IBridgeLog(0x923076A69B52f5E98C95D8C61EfA20CD46F15062);
    polcToken = IERC20Token(polcTokenAddress);
    polcVault = 0xf7A9F6001ff8b499149569C54852226d719f2D76;
    bridgeFee = 1;
    whitelisted[0xf7A9F6001ff8b499149569C54852226d719f2D76] = true;
    whitelisted[0xeA50CE6EBb1a5E4A8F90Bfb35A2fb3c3F0C673ec] = true;
    whitelisted[0x00d6E1038564047244Ad37080E2d695924F8515B] = true;
    managers[0x00d6E1038564047244Ad37080E2d695924F8515B] = true;
    chains[1] = true;
    chains[112358] = true;
    depositIndex = 1;
  }

  function bridgeSend(uint256 _amount, uint256 _chainTo) public {
    require((_amount>=(minTXAmount) && _amount<=(maxTXAmount)), "Invalid amount");
    uint256 fee;
    if (bridgeFee > 0) {
      fee = (_amount * bridgeFee) /100;  // bridge transaction fee
    }
    _bridge(msg.sender, _amount, fee, _chainTo);
  }
    
  function platformTransfer(uint256 _amount, uint256 _chainTo) public {
    require(whitelisted[msg.sender] == true, "Not allowed");
    _bridge(msg.sender, _amount, 0, _chainTo);
  }

  function _bridge(address _wallet, uint256 _amount, uint256 _fee, uint256 _chainTo) private {
    require(chains[_chainTo] == true, "Invalid chain");
    require(!paused, "Contract is paused");
    require(polcToken.transferFrom(msg.sender, polcVault, _amount), "ERC20 transfer error");
    deposits[depositIndex].sender = _wallet;
    deposits[depositIndex].amount = _amount;
    deposits[depositIndex].fee = _fee;
    deposits[depositIndex].chainTo = _chainTo;
    logger.outgoing(_wallet, _amount, _fee, _chainTo, depositIndex);
    depositIndex += 1;
    emit NewTransfer(_wallet, _chainTo, _amount);
  }
       
  function setVault(address _vault) public onlyManagers {
    require(_vault != address(0), "Invalid address");
    polcVault = _vault;
    emit VaultChange(_vault);
  }
  
  function setFee(uint256 _fee) public onlyManagers {
    require(_fee <= 5, "Fee too high");
    bridgeFee = _fee;   
    emit FeeChange(_fee);
  }
      
  function setMaxTXAmount(uint256 _amount) public onlyManagers {
    require(_amount > 10000 ether, "Max amount too low");
    maxTXAmount = _amount;
    emit TXLimitChange(minTXAmount, maxTXAmount);
  }
  
  function setMinTXAmount(uint256 _amount) public onlyManagers {
    require(_amount < 1000 ether, "Min amount too high");
    minTXAmount = _amount;
    emit TXLimitChange(minTXAmount, maxTXAmount);
  }

  function whitelistWallet(address _wallet, bool _whitelisted) public onlyManagers {
    whitelisted[_wallet] = _whitelisted;
  }

  function setLogger (address _logger) public onlyManagers {
    require(_logger != address(0), "Invalid address");
    logger = IBridgeLog(_logger);
    emit LoggerChange(_logger);
  }

  function setChain(uint256 _chain, bool _available) public onlyManagers {
    chains[_chain] = _available;
    emit ChainUpdate(_chain, _available);
  }
    
  function pauseBridge(bool _paused) public onlyManagers {
    paused = _paused;
    emit PauseTransfers(_paused);
  }
}