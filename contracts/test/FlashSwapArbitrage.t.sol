// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/HyToken.sol";
import "../src/uniswap/UniswapV2Factory.sol";
import "../src/uniswap/IUniswapV2Pair.sol";
import "../src/FlashSwapArbitrage.sol";

contract FlashSwapArbitrageTest is Test {
    HyToken tokenA;
    HyToken tokenB;
    UniswapV2Factory factory1;
    UniswapV2Factory factory2;
    address poolA;
    address poolB;
    address arbitrageur;

    function setUp() public {
        arbitrageur = makeAddr("arbitrageur");

        tokenA = new HyToken();
        tokenA.initialize("TokenA", "TA", 1000 ether);

        tokenB = new HyToken();
        tokenB.initialize("TokenB", "TB", 1000 ether);

        factory1 = new UniswapV2Factory(address(this));
        factory2 = new UniswapV2Factory(address(this));

        poolA = factory1.createPair(address(tokenA), address(tokenB));
        poolB = factory2.createPair(address(tokenA), address(tokenB));

        tokenA.transfer(poolA, 1 ether);
        tokenB.transfer(poolA, 2 ether);
        IUniswapV2Pair(poolA).mint(address(this));

        tokenA.transfer(poolB, 1.5 ether);
        tokenB.transfer(poolB, 2 ether);
        IUniswapV2Pair(poolB).mint(address(this));
    }

    function testFlashSwapArbitrage() public {
        uint256 initialTokenAAmount = tokenA.balanceOf(arbitrageur);
        uint256 initialTokenBAmount = tokenB.balanceOf(arbitrageur);

        vm.prank(arbitrageur);
        FlashSwapArbitrage arbitrage = new FlashSwapArbitrage();
        arbitrage.setArbitrageur(arbitrageur);
        arbitrage.executeArbitrage(
            poolA,
            poolB,
            address(tokenA),
            address(tokenB),
            2 ether
        );

        uint256 finalTokenAAmount = tokenA.balanceOf(arbitrageur);
        uint256 finalTokenBAmount = tokenB.balanceOf(arbitrageur);

        console.log("Initial TokenA balance:", initialTokenAAmount);
        console.log("Initial TokenB balance:", initialTokenBAmount);
        console.log("Final TokenA balance:", finalTokenAAmount);
        console.log("Final TokenB balance:", finalTokenBAmount);

        assertTrue(finalTokenAAmount > initialTokenAAmount || finalTokenBAmount > initialTokenBAmount);
    }
}
