// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolImmutables.sol";
import "../libraries/LowGasSafeMath.sol";
import "../libraries/SafeCast.sol";
import "../libraries/Tick.sol";
import "../libraries/TickBitmap.sol";
import "../libraries/FullMath.sol";
import "../libraries/TickMath.sol";
import "../libraries/LiquidityMath.sol";
import "../libraries/SqrtPriceMath.sol";
import "../libraries/SwapMath.sol";

contract BaseQuoter {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for uint256;

    struct PoolState {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the tick spacing
        int24 tickSpacing;
        // the pool's fee
        uint24 fee;
        // the pool's liquidity
        uint128 liquidity;
        // whether the pool is locked
        bool unlocked;
    }
    
    // accumulated protocol fees in token0/token1 units
    struct ProtocolFees {
        uint128 token0;
        uint128 token1;
    }

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the amount remaining to be swapped in/out of the input/output asset
        int256 amountSpecifiedRemaining;
        // the amount already swapped out/in of the output/input asset
        int256 amountCalculated;
        // current sqrt(price)
        uint160 sqrtPriceX96;
        // the tick associated with the current price
        int24 tick;
        // the current liquidity in range
        uint128 liquidity;
    }

    struct StepComputations {
        // the price at the beginning of the step
        uint160 sqrtPriceStartX96;
        // the next tick to swap to from the current tick in the swap direction
        int24 tickNext;
        // whether tickNext is initialized or not
        bool initialized;
        // sqrt(price) for the next tick (1/0)
        uint160 sqrtPriceNextX96;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out
        uint256 amountOut;
        // how much fee is being paid in
        uint256 feeAmount;
    }

    struct InitialState {
        address poolAddress;
        PoolState poolState;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
    }

    struct NextTickPassage {
        int24 tick;
        int24 tickSpacing;
    }

    function fetchState(address _pool) internal view returns (
        PoolState memory poolState
        ){
        IUniswapV3Pool pool = IUniswapV3Pool(_pool);
        (uint160 sqrtPriceX96, int24 tick,,,,, bool unlocked) = pool.slot0();
        uint128 liquidity = pool.liquidity();
        int24 tickSpacing = IUniswapV3PoolImmutables(_pool).tickSpacing();
        uint24 fee = IUniswapV3PoolImmutables(_pool).fee();
        poolState = PoolState(sqrtPriceX96, tick, tickSpacing, fee, liquidity, unlocked);
    }

    function setInitialState(PoolState memory poolStateStart, int256 amountSpecified) 
        internal pure returns (SwapState memory state) {
        state =
            SwapState({
                amountSpecifiedRemaining: amountSpecified,
                amountCalculated: 0,
                sqrtPriceX96: poolStateStart.sqrtPriceX96,
                tick: poolStateStart.tick,
                liquidity: 0 // to be modified after initialization
            });
    }

    function getNextTickAndPrice(int24 tickSpacing, int24 currentTick, IUniswapV3Pool pool, bool zeroForOne) 
        internal view returns (int24 tickNext, bool initialized, uint160 sqrtPriceNextX96) {
        int24 compressed = currentTick / tickSpacing;
        if (!zeroForOne) compressed++;
        if (currentTick < 0 && currentTick % tickSpacing != 0) compressed--; // round towards negative infinity

        uint256 selfResult = pool.tickBitmap(int16(compressed >> 8));

        (tickNext, initialized) =  
            TickBitmap.nextInitializedTickWithinOneWord(
                selfResult,
                currentTick,
                tickSpacing,
                zeroForOne
                );

        if (tickNext < TickMath.MIN_TICK) {
            tickNext = TickMath.MIN_TICK;
        } else if (tickNext > TickMath.MAX_TICK) {
            tickNext = TickMath.MAX_TICK;
        }
        sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(tickNext);
    }

    function quoteSwap(
            address poolAddress,
            int256 amountSpecified,
            uint160 sqrtPriceLimitX96,
            bool zeroForOne
    ) internal view returns (int256 amount0, int256 amount1) {
        require(amountSpecified < 0, "AS");
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        PoolState memory initialPoolState = fetchState(poolAddress);

        uint128 liquidity = initialPoolState.liquidity;
        
        uint160 sqrtPriceX96 = initialPoolState.sqrtPriceX96;
        uint160 sqrtPriceNextX96;

        require(zeroForOne 
                ? sqrtPriceLimitX96 < initialPoolState.sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 > initialPoolState.sqrtPriceX96 && sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO, "SPL");

        SwapState memory state = setInitialState(initialPoolState, amountSpecified);

        while (state.amountSpecifiedRemaining != 0 && sqrtPriceX96 != sqrtPriceLimitX96) {
            StepComputations memory step;

            step.sqrtPriceStartX96 = sqrtPriceX96;

            (step.tickNext, step.initialized, sqrtPriceNextX96) = getNextTickAndPrice(initialPoolState.tickSpacing, state.tick, pool, zeroForOne);

            (sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                sqrtPriceX96,
                (zeroForOne ? sqrtPriceNextX96 < sqrtPriceLimitX96 : sqrtPriceNextX96 > sqrtPriceLimitX96) ? sqrtPriceLimitX96 : sqrtPriceNextX96,
                liquidity,
                state.amountSpecifiedRemaining,
                initialPoolState.fee,
                zeroForOne
            );

            state.amountSpecifiedRemaining += step.amountOut.toInt256();
            state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
            
            if (sqrtPriceX96 == sqrtPriceNextX96) {
                if (step.initialized) {
                    (,int128 liquidityNet,,,,,,) = pool.ticks(step.tickNext);
                    if (zeroForOne) liquidityNet = -liquidityNet;
                    liquidity = LiquidityMath.addDelta(liquidity, liquidityNet);
                }
                state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else if (sqrtPriceX96 != step.sqrtPriceStartX96) {
                // recompute unless we"re on a lower tick boundary (i.e. already transitioned ticks), and haven"t moved
                state.tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
            }
        }

        (amount0, amount1) = 
            zeroForOne
            ?(state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining)
            :(amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated);
    }

    function quoteSwapExactAmount(
            address poolAddress,
            int256 amountSpecified,
            uint160 sqrtPriceLimitX96,
            bool zeroForOne
        ) internal view returns (int256 amount0, int256 amount1) {
        require(amountSpecified > 0, "ASEA");

        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        PoolState memory initialPoolState = fetchState(poolAddress);
        
        uint128 liquidity = initialPoolState.liquidity;

        uint160 sqrtPriceX96 = initialPoolState.sqrtPriceX96;
        uint160 sqrtPriceNextX96;
    
        require(zeroForOne 
                ? sqrtPriceLimitX96 < initialPoolState.sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 > initialPoolState.sqrtPriceX96 && sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO, "SPL");

        SwapState memory state = setInitialState(initialPoolState, amountSpecified);

        while (state.amountSpecifiedRemaining != 0 && sqrtPriceX96 != sqrtPriceLimitX96) {
            StepComputations memory step;

            step.sqrtPriceStartX96 = sqrtPriceX96;

            (step.tickNext, step.initialized, sqrtPriceNextX96) = getNextTickAndPrice(initialPoolState.tickSpacing, state.tick, pool, zeroForOne);

            (sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                sqrtPriceX96,
                (zeroForOne ? sqrtPriceNextX96 < sqrtPriceLimitX96 : sqrtPriceNextX96 > sqrtPriceLimitX96) ? sqrtPriceLimitX96 : sqrtPriceNextX96,
                liquidity,
                state.amountSpecifiedRemaining,
                initialPoolState.fee,
                zeroForOne
            );
            
            state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
            state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
            
            if (sqrtPriceX96 == sqrtPriceNextX96) {
                if (step.initialized) {
                    (,int128 liquidityNet,,,,,,) = pool.ticks(step.tickNext);
                    if (zeroForOne) liquidityNet = -liquidityNet;
                    liquidity = LiquidityMath.addDelta(liquidity, liquidityNet);
                }
                state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else if (sqrtPriceX96 != step.sqrtPriceStartX96) {
                // recompute unless we"re on a lower tick boundary (i.e. already transitioned ticks), and haven"t moved
                state.tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
            }
        }

      (amount0, amount1) = zeroForOne
            ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
            : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);
    }

}