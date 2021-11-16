// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

interface IQuoter {
  function quoteNeededTokens(address token0, address token1, uint256 amount) external returns(uint256);
  function quoteObtainedTokens(address token0, address token1, uint256 amount) external returns(uint256);
}
