// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

interface ISwapper {
  function swapExactTokensForTokens(address token0, address token1, uint256 amount, uint256 minOutput) external returns(uint256);
  function swapTokensForExactTokens(address token0, address token1, uint256 amount, uint256 minInput) external returns(uint256);
}
