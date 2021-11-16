// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

interface IExchangeProxy {
  function addDex(address _quoter, address _swapper) external returns(uint256);
  function removeDex(uint256 id) external;
  function quoteSell(address token0, address token1, uint256 amount) external view returns(uint256);
  function quoteBuy(address token0, address token1, uint256 amount) external view returns(uint256);
  function sell(address token0, address token1, uint256 amount, uint256 maxInput, uint256 dexId) external  returns(uint256);
  function buy(address token0, address token1, uint256 amount, uint256 minOutput, uint256 dexId) external  returns(uint256);
}
