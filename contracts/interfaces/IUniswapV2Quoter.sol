// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

interface IUniswapV2Quoter {
    function estimateMaxSwapUniswapV2(
        address _fromToken,
        address _toToken,
        uint256 _amount
    ) external view returns (uint256);

    function estimateMinSwapUniswapV2(
        address _fromToken,
        address _toToken,
        uint256 _amount
    ) external view returns (uint256);
}
