// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/OPToken.sol";
import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDT
 * @dev 模拟USDT代币
 */
contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
    
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}

/**
 * @title OPTokenTest
 * @dev 测试OPToken合约的功能
 */
contract OPTokenTest is Test {
    OPToken public opToken;
    MockUSDT public mockUSDT;
    address public owner;
    address public user;
    uint256 public constant TEST_AMOUNT = 1 ether;
    uint256 public constant EXERCISE_DATE = 1780416000;
    uint256 public constant EXERCISE_WINDOW = 1 days;
    
    /**
     * @dev 测试设置
     */
    function setUp() public {
        owner = address(0x1);
        user = address(0x2);
        // 为账户分配ETH资金
        vm.deal(owner, 100 ether);
        vm.deal(user, 100 ether);
        // 部署模拟USDT
        vm.startPrank(owner);
        mockUSDT = new MockUSDT();
        // 部署OPToken
        opToken = new OPToken(owner, mockUSDT);
        // 给用户转账USDT（足够进行行权操作）
        mockUSDT.transfer(user, 10000 * 10 ** 18);
        vm.stopPrank();
    }
    
    /**
     * @dev 测试构造函数是否正确设置参数
     */
    function testConstructor() public {
        assertEq(opToken.owner(), owner);
        assertEq(address(opToken.usdt()), address(mockUSDT));
        assertEq(opToken.STRIKE_PRICE(), 1800 ether);
        assertEq(opToken.EXERCISE_DATE(), EXERCISE_DATE);
        assertEq(opToken.EXERCISE_WINDOW(), EXERCISE_WINDOW);
        assertEq(opToken.ethReserve(), 0);
        assertEq(opToken.totalSupply(), 0);
        assertEq(opToken.expired(), false);
    }
    
    /**
     * @dev 测试发行功能 - 只有所有者可以调用
     */
    function testMintOnlyOwner() public {
        vm.startPrank(user);
        vm.expectRevert();
        opToken.mint{value: TEST_AMOUNT}(user);
        vm.stopPrank();
    }
    
    /**
     * @dev 测试发行功能 - 金额为0不能发行
     */
    function testMintZeroAmount() public {
        vm.startPrank(owner);
        vm.expectRevert(OPToken.ZeroAmount.selector);
        opToken.mint{value: 0}(user);
        vm.stopPrank();
    }
    
    /**
     * @dev 测试发行功能 - 过期后不能发行
     */
    function testMintAfterExpired() public {
        // 设置过期后
        vm.warp(EXERCISE_DATE + EXERCISE_WINDOW + 1);
        // 标记合约过期
        vm.startPrank(owner);
        opToken.expire();
        // 尝试发行
        vm.expectRevert(OPToken.AlreadyExpired.selector);
        opToken.mint{value: TEST_AMOUNT}(user);
        vm.stopPrank();
    }
    
    /**
     * @dev 测试发行功能 - 行权日期后不能发行
     */
    function testMintAfterExerciseDate() public {
        // 设置行权日期后
        vm.warp(EXERCISE_DATE + 1);
        // 尝试发行
        vm.startPrank(owner);
        vm.expectRevert(OPToken.MintClosed.selector);
        opToken.mint{value: TEST_AMOUNT}(user);
        vm.stopPrank();
    }
    
    /**
     * @dev 测试发行功能 - 正确发行OPToken
     */
    function testMint() public {
        emit log_string("=== Test Minting OPToken ===");
        emit log_named_uint("Owner ETH Balance (ETH)", address(owner).balance / 1 ether);
        emit log_named_uint("User ETH Balance (ETH)", address(user).balance / 1 ether);
        emit log_named_uint("Owner USDT Balance (USDT)", mockUSDT.balanceOf(owner) / 1 ether);
        emit log_named_uint("User USDT Balance (USDT)", mockUSDT.balanceOf(user) / 1 ether);
        
        vm.startPrank(owner);
        uint256 initialBalance = opToken.balanceOf(user);
        uint256 initialSupply = opToken.totalSupply();
        uint256 initialReserve = opToken.ethReserve();
        
        opToken.mint{value: TEST_AMOUNT}(user);
        
        emit log_string("=== After Minting ===");
        emit log_named_uint("Owner ETH Balance (ETH)", address(owner).balance / 1 ether);
        emit log_named_uint("User ETH Balance (ETH)", address(user).balance / 1 ether);
        emit log_named_uint("Owner USDT Balance (USDT)", mockUSDT.balanceOf(owner) / 1 ether);
        emit log_named_uint("User USDT Balance (USDT)", mockUSDT.balanceOf(user) / 1 ether);
        emit log_named_uint("User OPToken Balance (OP)", opToken.balanceOf(user) / 1 ether);
        emit log_named_uint("Total Supply (OP)", opToken.totalSupply() / 1 ether);
        emit log_named_uint("ETH Reserve (ETH)", opToken.ethReserve() / 1 ether);
        
        assertEq(opToken.balanceOf(user), initialBalance + TEST_AMOUNT);
        assertEq(opToken.totalSupply(), initialSupply + TEST_AMOUNT);
        assertEq(opToken.ethReserve(), initialReserve + TEST_AMOUNT);
        vm.stopPrank();
    }
    
    /**
     * @dev 测试行权功能 - 非行权窗口不能行权
     */
    function testExerciseNotExerciseDay() public {
        // 发行OPToken
        vm.startPrank(owner);
        opToken.mint{value: TEST_AMOUNT}(user);
        vm.stopPrank();
        
        // 非行权窗口行权
        vm.startPrank(user);
        vm.expectRevert(OPToken.NotExerciseDay.selector);
        opToken.exercise(TEST_AMOUNT);
        vm.stopPrank();
    }
    
    /**
     * @dev 测试行权功能 - 余额不足不能行权
     */
    function testExerciseInsufficientBalance() public {
        // 设置行权窗口
        vm.warp(EXERCISE_DATE);
        
        // 用户余额不足
        vm.startPrank(user);
        vm.expectRevert(OPToken.InsufficientOPTokenBalance.selector);
        opToken.exercise(TEST_AMOUNT);
        vm.stopPrank();
    }
    
    /**
     * @dev 测试行权功能 - 过期后不能行权
     */
    function testExerciseAfterExpired() public {
        // 发行OPToken
        vm.startPrank(owner);
        opToken.mint{value: TEST_AMOUNT}(user);
        vm.stopPrank();
        
        // 设置过期后
        vm.warp(EXERCISE_DATE + EXERCISE_WINDOW + 1);
        // 标记合约过期
        vm.startPrank(owner);
        opToken.expire();
        // 尝试行权
        vm.startPrank(user);
        vm.expectRevert(OPToken.AlreadyExpired.selector);
        opToken.exercise(TEST_AMOUNT);
        vm.stopPrank();
    }
    
    /**
     * @dev 测试行权功能 - 正确行权
     */
    function testExercise() public {
        // 发行OPToken
        vm.startPrank(owner);
        opToken.mint{value: TEST_AMOUNT}(user);
        vm.stopPrank();
        
        // 设置行权窗口
        vm.warp(EXERCISE_DATE);
        
        emit log_string("=== Test Exercising OPToken ===");
        emit log_named_uint("Owner ETH Balance (ETH)", address(owner).balance / 1 ether);
        emit log_named_uint("User ETH Balance (ETH)", address(user).balance / 1 ether);
        emit log_named_uint("Owner USDT Balance (USDT)", mockUSDT.balanceOf(owner) / 1 ether);
        emit log_named_uint("User USDT Balance (USDT)", mockUSDT.balanceOf(user) / 1 ether);
        emit log_named_uint("User OPToken Balance (OP)", opToken.balanceOf(user) / 1 ether);
        
        // 授权USDT
        vm.startPrank(user);
        uint256 usdtAmount = (TEST_AMOUNT * 1800 ether) / 1 ether;
        mockUSDT.approve(address(opToken), usdtAmount);
        
        // 记录初始状态
        uint256 initialUserBalance = opToken.balanceOf(user);
        uint256 initialSupply = opToken.totalSupply();
        uint256 initialReserve = opToken.ethReserve();
        uint256 initialEthBalance = address(user).balance;
        uint256 initialOwnerUSDT = mockUSDT.balanceOf(owner);
        
        // 行权
        opToken.exercise(TEST_AMOUNT);
        
        emit log_string("=== After Exercising ===");
        emit log_named_uint("Owner ETH Balance (ETH)", address(owner).balance / 1 ether);
        emit log_named_uint("User ETH Balance (ETH)", address(user).balance / 1 ether);
        emit log_named_uint("Owner USDT Balance (USDT)", mockUSDT.balanceOf(owner) / 1 ether);
        emit log_named_uint("User USDT Balance (USDT)", mockUSDT.balanceOf(user) / 1 ether);
        emit log_named_uint("User OPToken Balance (OP)", opToken.balanceOf(user) / 1 ether);
        emit log_named_uint("Total Supply (OP)", opToken.totalSupply() / 1 ether);
        emit log_named_uint("ETH Reserve (ETH)", opToken.ethReserve() / 1 ether);
        
        vm.stopPrank();
        
        // 验证状态变化
        assertEq(opToken.balanceOf(user), initialUserBalance - TEST_AMOUNT);
        assertEq(opToken.totalSupply(), initialSupply - TEST_AMOUNT);
        assertEq(opToken.ethReserve(), initialReserve - TEST_AMOUNT);
        assertEq(address(user).balance, initialEthBalance + TEST_AMOUNT);
        assertEq(mockUSDT.balanceOf(owner), initialOwnerUSDT + usdtAmount);
    }
    
    /**
     * @dev 测试过期销毁功能 - 非所有者不能调用
     */
    function testExpireOnlyOwner() public {
        // 设置过期后
        vm.warp(EXERCISE_DATE + EXERCISE_WINDOW + 1);
        
        vm.startPrank(user);
        vm.expectRevert();
        opToken.expire();
        vm.stopPrank();
    }
    
    /**
     * @dev 测试过期销毁功能 - 未过期不能调用
     */
    function testExpireNotExpired() public {
        // 未过期
        vm.warp(EXERCISE_DATE);
        
        vm.startPrank(owner);
        vm.expectRevert(OPToken.NotExpired.selector);
        opToken.expire();
        vm.stopPrank();
    }
    
    /**
     * @dev 测试过期销毁功能 - 已过期不能重复调用
     */
    function testExpireAlreadyExpired() public {
        // 设置过期后
        vm.warp(EXERCISE_DATE + EXERCISE_WINDOW + 1);
        
        vm.startPrank(owner);
        opToken.expire();
        vm.expectRevert(OPToken.AlreadyExpired.selector);
        opToken.expire();
        vm.stopPrank();
    }
    
    /**
     * @dev 测试过期销毁功能 - 正确销毁
     */
    function testExpire() public {
        // 发行OPToken
        vm.startPrank(owner);
        opToken.mint{value: TEST_AMOUNT}(user);
        vm.stopPrank();
        
        // 设置过期后
        vm.warp(EXERCISE_DATE + EXERCISE_WINDOW + 1);
        
        emit log_string("=== Test Expiring OPToken ===");
        emit log_named_uint("Owner ETH Balance (ETH)", address(owner).balance / 1 ether);
        emit log_named_uint("User ETH Balance (ETH)", address(user).balance / 1 ether);
        emit log_named_uint("Owner USDT Balance (USDT)", mockUSDT.balanceOf(owner) / 1 ether);
        emit log_named_uint("User USDT Balance (USDT)", mockUSDT.balanceOf(user) / 1 ether);
        emit log_named_uint("User OPToken Balance (OP)", opToken.balanceOf(user) / 1 ether);
        emit log_named_uint("ETH Reserve (ETH)", opToken.ethReserve() / 1 ether);
        
        // 记录初始状态
        uint256 initialEthBalance = address(owner).balance;
        
        // 销毁
        vm.startPrank(owner);
        opToken.expire();
        
        emit log_string("=== After Expiring ===");
        emit log_named_uint("Owner ETH Balance (ETH)", address(owner).balance / 1 ether);
        emit log_named_uint("User ETH Balance (ETH)", address(user).balance / 1 ether);
        emit log_named_uint("Owner USDT Balance (USDT)", mockUSDT.balanceOf(owner) / 1 ether);
        emit log_named_uint("User USDT Balance (USDT)", mockUSDT.balanceOf(user) / 1 ether);
        emit log_named_uint("User OPToken Balance (OP)", opToken.balanceOf(user) / 1 ether);
        emit log_named_uint("ETH Reserve (ETH)", opToken.ethReserve() / 1 ether);
        
        vm.stopPrank();
        
        // 验证状态变化
        assertEq(opToken.expired(), true);
        assertEq(address(owner).balance, initialEthBalance + TEST_AMOUNT);
    }
    
    /**
     * @dev 测试ERC20转账功能
     */
    function testTransfer() public {
        // 发行OPToken
        vm.startPrank(owner);
        opToken.mint{value: TEST_AMOUNT}(owner);
        uint256 initialOwnerBalance = opToken.balanceOf(owner);
        uint256 initialUserBalance = opToken.balanceOf(user);
        
        // 转账
        opToken.transfer(user, TEST_AMOUNT);
        
        // 验证余额变化
        assertEq(opToken.balanceOf(owner), initialOwnerBalance - TEST_AMOUNT);
        assertEq(opToken.balanceOf(user), initialUserBalance + TEST_AMOUNT);
        vm.stopPrank();
    }
    
    /**
     * @dev 测试ERC20授权功能
     */
    function testApproveAndTransferFrom() public {
        // 发行OPToken
        vm.startPrank(owner);
        opToken.mint{value: TEST_AMOUNT}(user);
        vm.stopPrank();
        
        // 授权
        vm.startPrank(user);
        opToken.approve(owner, TEST_AMOUNT);
        assertEq(opToken.allowance(user, owner), TEST_AMOUNT);
        
        // 授权转账
        uint256 initialUserBalance = opToken.balanceOf(user);
        uint256 initialOwnerBalance = opToken.balanceOf(owner);
        
        vm.stopPrank();
        vm.startPrank(owner);
        opToken.transferFrom(user, owner, TEST_AMOUNT);
        
        // 验证余额变化
        assertEq(opToken.balanceOf(user), initialUserBalance - TEST_AMOUNT);
        assertEq(opToken.balanceOf(owner), initialOwnerBalance + TEST_AMOUNT);
        vm.stopPrank();
    }
}