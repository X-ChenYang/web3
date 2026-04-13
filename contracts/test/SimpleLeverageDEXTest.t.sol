// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/leverage/SimpleLeverageDEX.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC 模拟USDC代币
 * @dev 用于测试的ERC20代币
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1_000_000 * 10**6); // 铸造100万USDC
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

/**
 * @title SimpleLeverageDEXTest 测试合约
 * @dev 测试SimpleLeverageDEX的功能
 */
contract SimpleLeverageDEXTest is Test {
    // DEX合约实例
    SimpleLeverageDEX public dex;
    // 模拟USDC合约实例
    MockUSDC public usdc;
    
    // 测试账户
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public liquidator = makeAddr("liquidator");

    /**
     * @dev 测试设置函数
     * @notice 在每个测试用例执行前运行
     */
    function setUp() public {
        // 部署模拟USDC合约
        usdc = new MockUSDC();
        
        // 部署DEX合约，传入USDC地址
        dex = new SimpleLeverageDEX(address(usdc));
        
        // 给测试账户分配USDC
        usdc.mint(alice, 100_000 * 10**6); // 10万USDC
        usdc.mint(bob, 100_000 * 10**6);   // 10万USDC
        usdc.mint(liquidator, 50_000 * 10**6); // 5万USDC
        
        // 给DEX合约分配足够的USDC，用于支付用户盈利
        usdc.mint(address(dex), 100_000 * 10**6); // 10万USDC
    }

    /**
     * @dev 测试开启多头头寸
     * @notice 验证开启多头头寸后状态正确
     */
    function testOpenLongPosition() public {
        uint256 margin = 1000 * 10**6; // 1000 USDC
        uint256 level = 5; // 5倍杠杆
        
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, level, true); // 开启多头
        vm.stopPrank();
        
        // 验证头寸信息
        (uint256 posMargin, uint256 posBorrowed, SimpleLeverageDEX.Position pos, uint256 posLevel) = dex.positions(alice);
        assertEq(posMargin, margin);
        assertEq(posBorrowed, margin * (level - 1));
        assertEq(uint256(pos), uint256(SimpleLeverageDEX.Position.LONG));
        assertEq(posLevel, level);
    }

    /**
     * @dev 测试开启空头头寸
     * @notice 验证开启空头头寸后状态正确
     */
    function testOpenShortPosition() public {
        uint256 margin = 1000 * 10**6; // 1000 USDC
        uint256 level = 3; // 3倍杠杆
        
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, level, false); // 开启空头
        vm.stopPrank();
        
        // 验证头寸信息
        (uint256 posMargin, uint256 posBorrowed, SimpleLeverageDEX.Position pos, uint256 posLevel) = dex.positions(alice);
        assertEq(posMargin, margin);
        assertEq(posBorrowed, margin * (level - 1));
        assertEq(uint256(pos), uint256(SimpleLeverageDEX.Position.SHORT));
        assertEq(posLevel, level);
    }

    /**
     * @dev 测试重复开启头寸失败
     * @notice 验证已有头寸时无法再次开启
     */
    function testCannotOpenDuplicatePosition() public {
        uint256 margin = 1000 * 10**6;
        
        vm.startPrank(alice);
        usdc.approve(address(dex), margin * 2);
        dex.openPosition(margin, 2, true);
        
        // 尝试再次开启应该失败
        vm.expectRevert("Position already open");
        dex.openPosition(margin, 2, true);
        vm.stopPrank();
    }

    /**
     * @dev 测试关闭盈利的多头头寸
     * @notice 验证价格上涨后关闭多头能正确结算
     */
    function testCloseLongPositionWithProfit() public {
        uint256 margin = 1000 * 10**6;
        uint256 level = 2;
        
        // Alice开启多头头寸
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, level, true);
        vm.stopPrank();
        
        // 模拟价格上涨20%
        uint256 newPrice = 1200 ether;
        dex.setPrice(newPrice);
        
        // 计算预期盈利：2倍杠杆，20%涨幅，本金1000 USDC，预期盈利 = 1000 * 2 * 20% = 400 USDC
        uint256 expectedProfit = (margin / 10**6) * level * 20 / 100 * 10**6;
        emit log_named_uint("Expected profit (USDC)", expectedProfit / 10**6);
        
        // 记录关闭前的USDC余额
        uint256 balanceBefore = usdc.balanceOf(alice);
        emit log_named_uint("Alice's balance before closing position (USDC)", balanceBefore / 10**6);
        
        // 关闭头寸
        vm.prank(alice);
        dex.closePosition();
        
        // 验证Alice收到了本金+盈利
        uint256 balanceAfter = usdc.balanceOf(alice);
        emit log_named_uint("Alice's balance after closing position (USDC)", balanceAfter / 10**6);
        
        // 计算实际返回金额和盈利
        uint256 actualReturned = balanceAfter - balanceBefore;
        uint256 actualProfit = actualReturned - margin;
        emit log_named_uint("Amount returned to Alice (USDC)", actualReturned / 10**6);
        emit log_named_uint("Actual profit (USDC)", actualProfit / 10**6);
        
        // 验证盈利计算正确
        assertGt(balanceAfter, balanceBefore);
        assertGt(actualProfit, 0);
        
        // 验证盈利金额接近预期值（允许小的整数除法误差）
        uint256 profitDifference = actualProfit > expectedProfit ? actualProfit - expectedProfit : expectedProfit - actualProfit;
        assertLe(profitDifference, 1 * 10**6); // 允许最多1 USDC的误差
        
        // 验证头寸已清除
        (uint256 posMargin,, SimpleLeverageDEX.Position pos,) = dex.positions(alice);
        emit log_named_uint("Position margin after closing (USDC)", posMargin / 10**6);
        emit log_named_uint("Position status after closing", uint256(pos));
        assertEq(posMargin, 0);
        assertEq(uint256(pos), uint256(SimpleLeverageDEX.Position.NONE));
    }

    /**
     * @dev 测试关闭亏损的空头头寸
     * @notice 验证价格上涨后关闭空头（空头亏损）能正确结算
     */
    function testCloseShortPositionWithLoss() public {
        uint256 margin = 1000 * 10**6;
        uint256 level = 2;
        
        // Alice开启空头头寸
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, level, false);
        vm.stopPrank();
        
        // 模拟价格上涨10%（空头亏损）
        uint256 newPrice = 1100 ether;
        dex.setPrice(newPrice);
        
        // 计算预期亏损：2倍杠杆，10%涨幅，本金1000 USDC，预期亏损 = 1000 * 2 * 10% = 200 USDC
        uint256 expectedLoss = (margin / 10**6) * level * 10 / 100 * 10**6;
        emit log_named_uint("Expected loss (USDC)", expectedLoss / 10**6);
        
        // 记录关闭前的USDC余额
        uint256 balanceBefore = usdc.balanceOf(alice);
        emit log_named_uint("Alice's balance before closing short position (USDC)", balanceBefore / 10**6);
        
        // 关闭头寸
        vm.prank(alice);
        dex.closePosition();
        
        // 记录关闭后的USDC余额
        uint256 balanceAfter = usdc.balanceOf(alice);
        emit log_named_uint("Alice's balance after closing short position (USDC)", balanceAfter / 10**6);
        
        // 计算实际返回金额和亏损
        uint256 actualReturned = balanceAfter - balanceBefore;
        uint256 actualLoss = margin - actualReturned;
        emit log_named_uint("Amount returned to Alice (USDC)", actualReturned / 10**6);
        emit log_named_uint("Actual loss (USDC)", actualLoss / 10**6);
        
        // 验证亏损计算正确
        assertLt(actualReturned, margin); // 返还金额小于保证金
        assertGt(actualLoss, 0); // 确实发生了亏损
        
        // 验证头寸已清除
        (uint256 posMargin,, SimpleLeverageDEX.Position pos,) = dex.positions(alice);
        emit log_named_uint("Position margin after closing short position (USDC)", posMargin / 10**6);
        emit log_named_uint("Position status after closing short position", uint256(pos));
        assertEq(posMargin, 0);
        assertEq(uint256(pos), uint256(SimpleLeverageDEX.Position.NONE));
    }

    /**
     * @dev 测试清算功能
     * @notice 验证当保证金亏损超过80%时可以清算
     */
    function testLiquidation() public {
        uint256 margin = 1000 * 10**6;
        uint256 level = 5;
        
        // Alice开启多头头寸
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, level, true);
        vm.stopPrank();
        
        // 检查初始头寸状态
        (uint256 posMargin, uint256 posBorrowed, SimpleLeverageDEX.Position pos, uint256 posLevel) = dex.positions(alice);
        emit log_named_uint("Initial position margin (USDC)", posMargin / 10**6);
        emit log_named_uint("Initial position borrowed (USDC)", posBorrowed / 10**6);
        emit log_named_uint("Initial position level", posLevel);
        
        // 模拟价格大幅下跌（超过80%亏损）
        uint256 newPrice = 600 ether; // 下跌40%，5倍杠杆意味着亏损200%
        dex.setPrice(newPrice);
        emit log_named_uint("New price after crash (ether)", newPrice / 1 ether);
        
        // 计算盈亏
        int256 pnl = dex.calculatePnL(alice);
        emit log_named_int("PnL before liquidation (USDC)", pnl / 10**6);
        
        // 清算人清算Alice的头寸
        emit log_string("Liquidator is liquidating Alice's position...");
        vm.prank(liquidator);
        dex.liquidatePosition(alice);
        
        // 验证头寸已清除
        (uint256 posMarginAfter,, SimpleLeverageDEX.Position posAfter,) = dex.positions(alice);
        emit log_named_uint("Position margin after liquidation (USDC)", posMarginAfter / 10**6);
        emit log_named_uint("Position status after liquidation", uint256(posAfter));
        assertEq(posMarginAfter, 0);
        assertEq(uint256(posAfter), uint256(SimpleLeverageDEX.Position.NONE));
    }

    /**
     * @dev 测试计算盈亏功能
     * @notice 验证盈亏计算正确
     */
    function testCalculatePnL() public {
        uint256 margin = 1000 * 10**6;
        uint256 level = 2;
        
        // Alice开启多头头寸
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, level, true);
        vm.stopPrank();
        
        // 价格上涨10%
        dex.setPrice(1100 ether);
        int256 pnl = dex.calculatePnL(alice);
        emit log_named_int("PnL with 10% price increase (USDC)", pnl / 10**6);
        assertGt(pnl, 0); // 多头盈利
        
        // 价格下跌10%
        dex.setPrice(900 ether);
        pnl = dex.calculatePnL(alice);
        emit log_named_int("PnL with 10% price decrease (USDC)", pnl / 10**6);
        assertLt(pnl, 0); // 多头亏损
    }

    /**
     * @dev 测试无法清算未亏损的头寸
     * @notice 验证盈利头寸不会被清算
     */
    function testCannotLiquidateProfitablePosition() public {
        uint256 margin = 1000 * 10**6;
        
        // Alice开启多头头寸
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, 2, true);
        vm.stopPrank();
        
        // 价格上涨（盈利状态）
        dex.setPrice(1200 ether);
        
        // 尝试清算应该失败（因为不满足清算条件）
        vm.prank(liquidator);
        // 注意：当前实现中，如果不满足清算条件，函数不会revert，只是不执行清算
        // 这里我们验证头寸仍然存在
        dex.liquidatePosition(alice);
        
        // 验证头寸仍然存在
        (uint256 posMargin,,,) = dex.positions(alice);
        assertEq(posMargin, margin);
    }
}

