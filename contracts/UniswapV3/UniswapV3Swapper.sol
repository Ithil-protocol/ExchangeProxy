// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolImmutables.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "../interfaces/IUniswapV3Swapper.sol";
import "../libraries/FullMath.sol";
import "../libraries/SafeCast.sol";
import "../libraries/TickMath.sol";
import "../libraries/SwapMath.sol";
import "../libraries/UniswapV3Math.sol";
import "../libraries/UniswapPath.sol";
import "../libraries/TickBitmap.sol";
import "../libraries/SqrtPriceMath.sol";

contract UniswapV3Swapper is IUniswapV3Swapper {
    using UniswapPath for bytes;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    struct SwapCallbackData {
        bytes path;
        address payer;
    }

    IUniswapV3Factory internal immutable uniV3Factory;

    constructor(address _uniV3Factory) {
        uniV3Factory = IUniswapV3Factory(_uniV3Factory);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external override {
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        (address tokenIn, address tokenOut, uint24 fee) = data
            .path
            .decodeFirstPool();

        address pool = uniV3Factory.getPool(tokenIn, tokenOut, fee);
        require(msg.sender == pool);

        (bool isExactInput, uint256 amountToPay) = amount0Delta > 0
            ? (tokenIn < tokenOut, uint256(amount0Delta))
            : (tokenOut < tokenIn, uint256(amount1Delta));

        if (isExactInput) {
            IERC20(tokenIn).safeTransferFrom(
                data.payer,
                msg.sender,
                amountToPay
            );
        } else {
            // either initiate the next swap or pay
            // swap in/out because exact output swaps are reversed
            IERC20(tokenOut).safeTransferFrom(
                data.payer,
                msg.sender,
                amountToPay
            );
        }
    }
}
