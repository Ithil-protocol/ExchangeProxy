// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

interface IUniswapV3Swapper {

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external;

/*
    function sell(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        uint24 _slippage,
        address _recipient
    ) external returns (uint256);

    function buy(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        uint24 _slippage,
        address _recipient
    ) external returns (uint256);
*/
}
