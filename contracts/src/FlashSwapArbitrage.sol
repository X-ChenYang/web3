// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./uniswap/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashSwapArbitrage is IUniswapV2Callee {
    event ArbitrageExecuted(uint amountBorrowed, uint amountExchanged, uint profit);

    address public arbitrageur;

    function setArbitrageur(address _arbitrageur) external {
        arbitrageur = _arbitrageur;
    }

    function executeArbitrage(
        address poolA,
        address poolB,
        address tokenA,
        address tokenB,
        uint amountBorrowed
    ) external {
        bytes memory data = abi.encode(poolB, tokenA, tokenB, amountBorrowed);
        IUniswapV2Pair(poolA).swap(0, amountBorrowed, address(this), data);
    }

    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external override {
        (address poolB, address tokenA, address tokenB, uint amountBorrowed) = abi.decode(data, (address, address, address, uint));

        uint amountToRepay = amountBorrowed * 1000 / 997 + 1;

        IERC20(tokenB).approve(poolB, amountBorrowed);
        IUniswapV2Pair(poolB).swap(amountBorrowed * 3 / 4, 0, address(this), "");

        uint tokenBBalance = IERC20(tokenB).balanceOf(address(this));

        if (tokenBBalance < amountToRepay) {
            uint neededTokenB = amountToRepay - tokenBBalance;
            IERC20(tokenA).approve(poolB, neededTokenB * 2);
            IUniswapV2Pair(poolB).swap(0, neededTokenB, address(this), "");
        }

        IERC20(tokenB).transfer(msg.sender, amountToRepay);

        uint finalTokenABalance = IERC20(tokenA).balanceOf(address(this));
        uint finalTokenBBalance = IERC20(tokenB).balanceOf(address(this));

        if (finalTokenABalance > 0) {
            IERC20(tokenA).transfer(arbitrageur, finalTokenABalance);
        }
        if (finalTokenBBalance > 0) {
            IERC20(tokenB).transfer(arbitrageur, finalTokenBBalance);
        }

        uint profit = finalTokenABalance + finalTokenBBalance;
        emit ArbitrageExecuted(amountBorrowed, amountBorrowed * 3 / 4, profit);
    }
}
