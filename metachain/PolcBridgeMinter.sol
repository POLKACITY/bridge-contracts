// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "./IERC20Token.sol";
import "./IBridgeLog.sol";
import "./Managed.sol";

// signature verification library

library ECDSA {
  function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
    bytes32 r;
    bytes32 s;
    uint8 v;
    if (signature.length == 65) {
      // solhint-disable-next-line no-inline-assembly
      assembly {
        r := mload(add(signature, 0x20))
        s := mload(add(signature, 0x40))
        v := byte(0, mload(add(signature, 0x60)))
      }
    } else if (signature.length == 64) {
      // solhint-disable-next-line no-inline-assembly
      assembly {
        let vs := mload(add(signature, 0x40))
        r := mload(add(signature, 0x20))
        s := and(
          vs,
          0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        )
        v := add(shr(255, vs), 27)
      }
    } else {
      revert("ECDSA: invalid signature length");
    }

    return recover(hash, v, r, s);
  }

  function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
    require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "ECDSA: invalid signature 's' value");
    require(v == 27 || v == 28, "ECDSA: invalid signature 'v' value");

    // If the signature is valid (and not malleable), return the signer address
    address signer = ecrecover(hash, v, r, s);
    require(signer != address(0), "ECDSA: invalid signature");
    return signer;
  }

  function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
  }

  function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
  }
}

contract POLCBridgeMinter is Managed {
  IERC20Token private polcToken;
  IBridgeLog private logger;
  address private signer;
  uint256 private chainID;
  address public platformWallet;
  address public banksWallet;
  address public polcVault;
  uint256 private txMode; // 0 minting, 1 transfer
  
  constructor() {
    polcToken = IERC20Token(0xCcd0B2659d46a0042f42F4Cb00401D7cA24326bd);
    logger = IBridgeLog(0xC6B18C443d78AA0abD98cd32Aec52ae918324953);
    chainID = 112358;
    polcVault = 0xf7A9F6001ff8b499149569C54852226d719f2D76;
    platformWallet = 0x00d6E1038564047244Ad37080E2d695924F8515B;
    banksWallet = 0x57379373df97B21d5cDCdA4A718432704Bd0c2A6;
    signer = 0xa4C03a9B4f1c67aC645A990DDB7B8A27D4D9e7af;
    managers[0x00d6E1038564047244Ad37080E2d695924F8515B] = true;
  }

  // verify transaction signature to ensure signer is valid
  function verifyTXCall(bytes32 _taskHash, bytes memory _sig) public view returns (bool valid) {
    address mSigner = ECDSA.recover(ECDSA.toEthSignedMessageHash(_taskHash), _sig);
    if (mSigner == signer) {
      return true;
    } else {
      return false;
    }
  }

  // users will withdraw their assets with a pre-signed hash validation
  function withdraw(address _wallet, uint256 _amount, uint256 _fee, uint256 _chainFrom, uint256 _chainTo, uint256 _logIndex, bytes memory _sig) public {

    require(_chainTo == chainID, "Invalid chain");
    if (txMode == 1) {
      require(polcToken.allowance(polcVault, address(this)) >= _amount, "Vault need increase allowance");
      require(polcToken.balanceOf(polcVault) >= _amount, "Vault balance is too low");
    }
    bytes32 txHash = keccak256(abi.encode(_wallet, _amount, _fee, _chainFrom, _chainTo, _logIndex));
    bool txv = verifyTXCall(txHash, _sig);
    require (txv == true, "Invalid signature");
    require(logger.withdrawalCompleted(txHash) == false, "Withdrawal already completed");
    logger.incoming(_wallet, _amount, _fee, _chainFrom, _logIndex, txHash);
    uint256 platformFees;
    if (_fee > 0) {
      platformFees = (_fee * 75) / 100;
    }
    if (txMode == 0) {
      polcToken.mint(_wallet, _amount-_fee);
      if (platformFees > 0) {
        polcToken.mint(platformWallet, platformFees);
        polcToken.mint(banksWallet, _fee - platformFees);
      }
    } else {
      require(polcToken.transferFrom(polcVault, _wallet, (_amount - _fee)), "ERC20 transfer error");
        if (platformFees > 0) {
        require(polcToken.transferFrom(polcVault, platformWallet, platformFees), "ERC20 transfer error");
        require(polcToken.transferFrom(polcVault, banksWallet, (_fee - platformFees)), "ERC20 transfer error");
      }
    }
  }

  // administrative variables update
  function setLogger (address _logger) public onlyManagers {
    require(_logger != address(0), "Invalid address");
    logger = IBridgeLog(_logger);
  }
  
  function setSigner (address _signer) public onlyManagers {
    require(_signer != address(0), "Invalid address");
    signer = _signer;
  }

  function setBanksWallet(address _wallet) public onlyManagers {
    require(_wallet != address(0), "Invalid address");
    banksWallet = _wallet;
  }

  function setVault(address _wallet) public onlyManagers {
    require(_wallet != address(0), "Invalid address");
    polcVault = _wallet;
  }

  function setPlatformWallet(address _wallet) public onlyManagers {
    require(_wallet != address(0), "Invalid address");
    platformWallet = _wallet;
  }
  
  function setMode(uint256 _mode) public onlyManagers {
    txMode = _mode;
  }
}