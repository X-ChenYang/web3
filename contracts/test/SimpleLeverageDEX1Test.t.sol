// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/leverage/SimpleLeverageDEX1.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC 模拟USDC代币
 * @dev 用于测试的ERC20代币，模拟USDC行为
 */
contract MockUSDC is ERC20 {
    /**
     * @dev 构造函数
     * @notice 初始化代币并铸造初始供应
     */
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1_000_000 * 10**6); // Mint 1,000,000 USDC
    }

    /**
     * @dev 铸造代币
     * @param to 接收地址
     * @param amount 铸造数量
     * @notice 用于为测试账户分配USDC
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @dev 获取代币小数位数
     * @return uint8 小数位数
     * @notice 模拟USDC的6位小数
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

/**
 * @title SimpleLeverageDEX1Test 测试合约
 * @dev 测试SimpleLeverageDEX1的功能，包括开启头寸、关闭头寸和清算
 * @notice 更新为测试预言机价格功能
 */
contract SimpleLeverageDEX1Test is Test {
    /**
     * @dev DEX合约实例
     * @notice 用于测试的SimpleLeverageDEX1合约
     */
    SimpleLeverageDEX1 public dex;
    
    /**
     * @dev 模拟USDC合约实例
     * @notice 用于测试中的资金转账
     */
    MockUSDC public usdc;
    
    /**
     * @dev 测试账户
     * @notice 用于执行测试操作的模拟账户
     */
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public liquidator = makeAddr("liquidator");

    /**
     * @dev 初始虚拟池参数
     * @notice 测试中使用的初始虚拟池配置
     */
    uint public constant INITIAL_VETH = 1000 * 1e18; // 增加虚拟池规模，避免整数除法截断
    uint public constant INITIAL_VUSDC = 1000000 * 1e18; // 增加虚拟池规模，避免整数除法截断
    uint public constant INITIAL_ORACLE_PRICE = 1000 * 1e18; // 初始预言机价格：1000 USDC/ETH

    /**
     * @dev 测试设置函数
     * @notice 在每个测试用例之前运行，初始化测试环境
     */
    function setUp() public {
        // 部署模拟USDC合约
        usdc = new MockUSDC();
        
        // 部署DEX合约，设置USDC地址和初始虚拟池参数
        dex = new SimpleLeverageDEX1(address(usdc), INITIAL_VETH, INITIAL_VUSDC);
        
        // 设置初始预言机价格
        dex.setOraclePrice(INITIAL_ORACLE_PRICE);
        
        // 为测试账户分配USDC
        usdc.mint(alice, 100_000 * 10**6); // 100,000 USDC
        usdc.mint(bob, 100_000 * 10**6);   // 100,000 USDC
        usdc.mint(liquidator, 50_000 * 10**6); // 50,000 USDC
        
        // 为DEX合约分配足够的USDC用于支付用户盈利
        usdc.mint(address(dex), 100_000 * 10**6); // 100,000 USDC
        
        // 输出初始价格信息
        emit log_string("=== Initial Virtual Pool State ===");
        emit log_named_uint("Initial vETH Amount", INITIAL_VETH);
        emit log_named_uint("Initial vUSDC Amount", INITIAL_VUSDC);
        uint initialPoolPrice = INITIAL_VUSDC * 1e18 / INITIAL_VETH;
        emit log_named_uint("Initial Pool Price (USDC)", initialPoolPrice / 1e18);
        emit log_named_uint("Initial Oracle Price (USDC)", dex.oraclePrice() / 1e18);
        emit log_string("====================");
    }

    /**
     * @dev 测试开启多头头寸
     * @notice 验证开启多头头寸时设置正确的状态并记录预言机价格
     */
    function testOpenLongPosition() public {
        uint256 margin = 10 * 10**6; // 10 USDC
        uint256 level = 2; // 2x leverage
        
        // 输出测试信息
        emit log_string("=== Test Opening Long Position ===");
        emit log_named_uint("Margin (USDC)", margin / 10**6);
        emit log_named_uint("Leverage Level", level);
        emit log_named_uint("Current Oracle Price (USDC)", dex.oraclePrice() / 1e18);
        
        // 记录开启头寸前的虚拟池状态
        uint vEthBefore = dex.vETHAmount();
        uint vUsdcBefore = dex.vUSDCAmount();
        uint priceBefore = vUsdcBefore * 1e18 / vEthBefore;
        emit log_named_uint("vETH Amount Before", vEthBefore);
        emit log_named_uint("vUSDC Amount Before", vUsdcBefore);
        emit log_named_uint("Pool Price Before (USDC)", priceBefore / 1e18);
        
        // Alice开启多头头寸
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, level, true); // Open long position
        vm.stopPrank();
        
        // 记录开启头寸后的虚拟池状态
        uint vEthAfter = dex.vETHAmount();
        uint vUsdcAfter = dex.vUSDCAmount();
        uint priceAfter = vUsdcAfter * 1e18 / vEthAfter;
        emit log_named_uint("vETH Amount After", vEthAfter);
        emit log_named_uint("vUSDC Amount After", vUsdcAfter);
        emit log_named_uint("Pool Price After (USDC)", priceAfter / 1e18);
        
        // 验证头寸信息
        (uint256 posMargin, uint256 posBorrowed, int256 pos) = dex.positions(alice);
        uint openOraclePrice = dex.openPrice(alice);
        emit log_named_uint("Position Margin (USDC)", posMargin / 10**6);
        emit log_named_uint("Borrowed Amount (USDC)", posBorrowed / 10**6);
        emit log_named_int("Virtual ETH Position", pos);
        emit log_named_uint("Open Oracle Price (USDC)", openOraclePrice / 1e18);
        
        assertEq(posMargin, margin);
        assertEq(posBorrowed, margin * (level - 1));
        assertGt(pos, 0); // Long position should be positive
        assertEq(openOraclePrice, INITIAL_ORACLE_PRICE); // Open price should match initial oracle price
        
        emit log_string("====================");
    }

    /**
     * @dev 测试开启空头头寸
     * @notice 验证开启空头头寸时设置正确的状态并记录预言机价格
     */
    function testOpenShortPosition() public {
        uint256 margin = 10 * 10**6; // 10 USDC
        uint256 level = 2; // 2x leverage
        
        // 输出测试信息
        emit log_string("=== Test Opening Short Position ===");
        emit log_named_uint("Margin (USDC)", margin / 10**6);
        emit log_named_uint("Leverage Level", level);
        emit log_named_uint("Current Oracle Price (USDC)", dex.oraclePrice() / 1e18);
        
        // 记录开启头寸前的虚拟池状态
        uint vEthBefore = dex.vETHAmount();
        uint vUsdcBefore = dex.vUSDCAmount();
        uint priceBefore = vUsdcBefore * 1e18 / vEthBefore;
        emit log_named_uint("vETH Amount Before", vEthBefore);
        emit log_named_uint("vUSDC Amount Before", vUsdcBefore);
        emit log_named_uint("Pool Price Before (USDC)", priceBefore / 1e18);
        
        // Alice开启空头头寸
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, level, false); // Open short position
        vm.stopPrank();
        
        // 记录开启头寸后的虚拟池状态
        uint vEthAfter = dex.vETHAmount();
        uint vUsdcAfter = dex.vUSDCAmount();
        uint priceAfter = vUsdcAfter * 1e18 / vEthAfter;
        emit log_named_uint("vETH Amount After", vEthAfter);
        emit log_named_uint("vUSDC Amount After", vUsdcAfter);
        emit log_named_uint("Pool Price After (USDC)", priceAfter / 1e18);
        
        // 验证头寸信息
        (uint256 posMargin, uint256 posBorrowed, int256 pos) = dex.positions(alice);
        uint openOraclePrice = dex.openPrice(alice);
        emit log_named_uint("Position Margin (USDC)", posMargin / 10**6);
        emit log_named_uint("Borrowed Amount (USDC)", posBorrowed / 10**6);
        emit log_named_int("Virtual ETH Position", pos);
        emit log_named_uint("Open Oracle Price (USDC)", openOraclePrice / 1e18);
        
        assertEq(posMargin, margin);
        assertEq(posBorrowed, margin * (level - 1));
        assertLt(pos, 0); // Short position should be negative
        assertEq(openOraclePrice, INITIAL_ORACLE_PRICE); // Open price should match initial oracle price
        
        emit log_string("====================");
    }

    /**
     * @dev 测试不能开启重复头寸
     * @notice 验证当已有未平仓头寸时不能再次开启头寸
     */
    function testCannotOpenDuplicatePosition() public {
        uint256 margin = 10 * 10**6;
        
        // 输出测试信息
        emit log_string("=== Test Failing to Open Duplicate Position ===");
        
        // Alice开启第一个头寸
        vm.startPrank(alice);
        usdc.approve(address(dex), margin * 2);
        dex.openPosition(margin, 2, true);
        
        // 尝试开启另一个头寸应该失败
        vm.expectRevert("Position already open");
        dex.openPosition(margin, 2, true);
        vm.stopPrank();
        
        emit log_string("Test Passed: Failed to open duplicate position");
        emit log_string("====================");
    }

    /**
     * @dev 测试关闭盈利的多头头寸
     * @notice 验证价格上涨后关闭多头头寸时正确结算
     */
    function testCloseLongPositionWithProfit() public {
        uint256 margin = 10 * 10**6;
        uint256 level = 2;
        uint newOraclePrice = 1200 * 1e18; // 价格上涨20%
        
        // 输出测试信息
        emit log_string("=== Test Closing Profitable Long Position ===");
        emit log_named_uint("Margin (USDC)", margin / 10**6);
        emit log_named_uint("Leverage Level", level);
        emit log_named_uint("Initial Oracle Price (USDC)", dex.oraclePrice() / 1e18);
        emit log_named_uint("New Oracle Price (USDC)", newOraclePrice / 1e18);
        
        // Alice开启多头头寸
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, level, true);
        vm.stopPrank();
        
        // 更新预言机价格模拟价格上涨
        dex.setOraclePrice(newOraclePrice);
        
        // 记录关闭前的状态
        uint256 balanceBefore = usdc.balanceOf(alice);
        uint currentOraclePrice = dex.oraclePrice();
        uint openOraclePrice = dex.openPrice(alice);
        emit log_named_uint("Alice's Balance Before (USDC)", balanceBefore / 10**6);
        emit log_named_uint("Open Oracle Price (USDC)", openOraclePrice / 1e18);
        emit log_named_uint("Current Oracle Price (USDC)", currentOraclePrice / 1e18);
        
        // 关闭头寸
        vm.prank(alice);
        dex.closePosition();
        
        // 记录关闭后的状态
        uint256 balanceAfter = usdc.balanceOf(alice);
        uint256 actualReturned = balanceAfter - balanceBefore;
        uint256 actualProfit = actualReturned - margin;
        
        emit log_named_uint("Alice's Balance After (USDC)", balanceAfter / 10**6);
        emit log_named_uint("Actual Returned (USDC)", actualReturned / 10**6);
        emit log_named_uint("Actual Profit (USDC)", actualProfit / 10**6);
        
        // 验证盈利计算正确
        assertGt(balanceAfter, balanceBefore);
        assertGt(actualProfit, 0);
        
        // 验证头寸被清除
        (uint256 posMargin,, int256 pos) = dex.positions(alice);
        assertEq(posMargin, 0);
        assertEq(pos, 0);
        
        emit log_string("Test Passed: Long position closed with profit");
        emit log_string("====================");
    }

    /**
     * @dev 测试关闭亏损的空头头寸
     * @notice 验证价格上涨后关闭空头头寸时正确结算
     */
    function testCloseShortPositionWithLoss() public {
        uint256 margin = 10 * 10**6;
        uint256 level = 2;
        uint newOraclePrice = 1200 * 1e18; // 价格上涨20%
        
        // 输出测试信息
        emit log_string("=== Test Closing Losing Short Position ===");
        emit log_named_uint("Margin (USDC)", margin / 10**6);
        emit log_named_uint("Leverage Level", level);
        emit log_named_uint("Initial Oracle Price (USDC)", dex.oraclePrice() / 1e18);
        emit log_named_uint("New Oracle Price (USDC)", newOraclePrice / 1e18);
        
        // Alice开启空头头寸
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, level, false);
        vm.stopPrank();
        
        // 更新预言机价格模拟价格上涨
        dex.setOraclePrice(newOraclePrice);
        
        // 记录关闭前的状态
        uint256 balanceBefore = usdc.balanceOf(alice);
        uint currentOraclePrice = dex.oraclePrice();
        uint openOraclePrice = dex.openPrice(alice);
        emit log_named_uint("Alice's Balance Before (USDC)", balanceBefore / 10**6);
        emit log_named_uint("Open Oracle Price (USDC)", openOraclePrice / 1e18);
        emit log_named_uint("Current Oracle Price (USDC)", currentOraclePrice / 1e18);
        
        // 关闭头寸
        vm.prank(alice);
        dex.closePosition();
        
        // 记录关闭后的状态
        uint256 balanceAfter = usdc.balanceOf(alice);
        uint256 actualReturned = balanceAfter - balanceBefore;
        uint256 actualLoss = margin - actualReturned;
        
        emit log_named_uint("Alice's Balance After (USDC)", balanceAfter / 10**6);
        emit log_named_uint("Actual Returned (USDC)", actualReturned / 10**6);
        emit log_named_uint("Actual Loss (USDC)", actualLoss / 10**6);
        
        // 验证头寸被清除
        (uint256 posMargin,, int256 pos) = dex.positions(alice);
        assertEq(posMargin, 0);
        assertEq(pos, 0);
        
        // 验证至少返回部分资金
        assertGt(actualReturned, 0);
        
        emit log_string("Test Passed: Short position closed with loss");
        emit log_string("====================");
    }

    /**
     * @dev 测试清算功能
     * @notice 验证只有当亏损超过保证金80%时才能进行清算
     */
    function testLiquidation() public {
        uint256 margin = 10 * 10**6;
        uint256 level = 5;
        uint newOraclePrice = 600 * 1e18; // 价格下跌40%，导致多头大幅亏损
        
        // 输出测试信息
        emit log_string("=== Test Liquidation Functionality ===");
        emit log_named_uint("Margin (USDC)", margin / 10**6);
        emit log_named_uint("Leverage Level", level);
        emit log_named_uint("Initial Oracle Price (USDC)", dex.oraclePrice() / 1e18);
        emit log_named_uint("New Oracle Price (USDC)", newOraclePrice / 1e18);
        
        // Alice开启多头头寸
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, level, true);
        vm.stopPrank();
        
        // 更新预言机价格模拟大幅下跌（应该触发清算）
        dex.setOraclePrice(newOraclePrice);
        
        // 计算当前盈亏
        int256 pnl = dex.calculatePnL(alice);
        emit log_named_int("Current PnL (USDC)", pnl / 10**6);
        
        // 尝试清算（现在应该成功）
        vm.prank(liquidator);
        dex.liquidatePosition(alice);
        
        // 验证头寸被清除
        (uint256 posMargin,, int256 pos) = dex.positions(alice);
        assertEq(posMargin, 0);
        assertEq(pos, 0);
        
        emit log_string("Test Passed: Liquidation successful when eligible");
        emit log_string("====================");
    }

    /**
     * @dev 测试不能清算自己的头寸
     * @notice 验证用户不能清算自己的头寸
     */
    function testCannotLiquidateYourself() public {
        uint256 margin = 10 * 10**6;
        
        // 输出测试信息
        emit log_string("=== Test Cannot Liquidate Yourself ===");
        
        // Alice开启多头头寸
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, 2, true);
        
        // 尝试清算自己的头寸应该失败
        vm.expectRevert("Cannot liquidate yourself");
        dex.liquidatePosition(alice);
        vm.stopPrank();
        
        emit log_string("Test Passed: Cannot liquidate your own position");
        emit log_string("====================");
    }

    /**
     * @dev 测试盈亏计算功能
     * @notice 验证盈亏计算是否正确
     */
    function testCalculatePnL() public {
        uint256 margin = 10 * 10**6;
        uint256 level = 2;
        uint newOraclePrice = 1100 * 1e18; // 价格上涨10%
        
        // 输出测试信息
        emit log_string("=== Test PnL Calculation ===");
        emit log_named_uint("Margin (USDC)", margin / 10**6);
        emit log_named_uint("Leverage Level", level);
        emit log_named_uint("Initial Oracle Price (USDC)", dex.oraclePrice() / 1e18);
        emit log_named_uint("New Oracle Price (USDC)", newOraclePrice / 1e18);
        
        // Alice开启多头头寸
        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, level, true);
        vm.stopPrank();
        
        // 更新预言机价格
        dex.setOraclePrice(newOraclePrice);
        
        // 记录当前预言机价格
        uint currentOraclePrice = dex.oraclePrice();
        uint openOraclePrice = dex.openPrice(alice);
        emit log_named_uint("Open Oracle Price (USDC)", openOraclePrice / 1e18);
        emit log_named_uint("Current Oracle Price (USDC)", currentOraclePrice / 1e18);
        
        // 计算盈亏
        int256 pnl = dex.calculatePnL(alice);
        emit log_named_int("Calculated PnL (USDC)", pnl / 10**6);
        
        // 验证盈亏计算返回正值（多头头寸价格上涨）
        assertGt(pnl, 0);
        
        emit log_string("Test Passed: PnL calculation works correctly with oracle price");
        emit log_string("====================");
    }

    /**
     * @dev 测试设置预言机价格
     * @notice 验证预言机价格可以正确更新
     */
    function testSetOraclePrice() public {
        uint initialPrice = dex.oraclePrice();
        uint newPrice = 1500 * 1e18;
        
        // 输出测试信息
        emit log_string("=== Test Setting Oracle Price ===");
        emit log_named_uint("Initial Oracle Price (USDC)", initialPrice / 1e18);
        emit log_named_uint("New Oracle Price (USDC)", newPrice / 1e18);
        
        // 设置新的预言机价格
        dex.setOraclePrice(newPrice);
        
        // 验证价格已更新
        assertEq(dex.oraclePrice(), newPrice);
        
        emit log_string("Test Passed: Oracle price updated successfully");
        emit log_string("====================");
    }
}