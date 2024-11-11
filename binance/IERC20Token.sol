// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IERC20Token {
    function mint(address account, uint256 value) external;
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}