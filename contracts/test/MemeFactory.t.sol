// SPDX-License-Identifier: MIT
// SPDX 许可证标识符：MIT
// Meme 工厂合约测试
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

/**
 * @title Meme Factory 测试
 * @dev 测试 Meme 工厂合约的各种功能
 */
contract MemeFactoryTest is Test {
    // Meme 工厂合约实例
    MemeFactory public factory;
    // 项目所有者地址
    address public projectOwner;
    // 代币发行者地址
    address public issuer;
    // 代币购买者地址
    address public buyer;
    
    /**
     * @dev 设置测试环境
     */
    function setUp() public {
        // 初始化测试地址
        projectOwner = address(1);
        issuer = address(2);
        buyer = address(3);
        
        // 部署工厂合约
        vm.prank(projectOwner);
        factory = new MemeFactory();
    }
    
    /**
     * @dev 测试部署 Meme 代币
     */
    function testDeployMeme() public {
        // 测试参数
        string memory symbol = "DOGE";
        uint256 totalSupply = 1000 ether;
        uint256 perMint = 10 ether;
        uint256 price = 1 ether;
        
        // 模拟发行者部署代币
        vm.prank(issuer);
        address tokenAddress = factory.deployMeme(symbol, totalSupply, perMint, price);
        
        // 验证代币数据
        (string memory returnedSymbol, uint256 returnedTotalSupply, uint256 returnedPerMint, uint256 returnedPrice, address returnedIssuer) = factory.memeTokens(tokenAddress);
        assertEq(returnedSymbol, symbol, "Symbol should match");
        assertEq(returnedTotalSupply, totalSupply, "Total supply should match");
        assertEq(returnedPerMint, perMint, "Per mint should match");
        assertEq(returnedPrice, price, "Price should match");
        assertEq(returnedIssuer, issuer, "Issuer should match");
        
        // 验证代币初始化
        MemeToken token = MemeToken(tokenAddress);
        assertEq(token.name(), string(abi.encodePacked("Meme Token: ", symbol)), "Name should match");
        assertEq(token.symbol(), symbol, "Symbol should match");
        assertEq(token.maxSupply(), totalSupply, "Max supply should match");
        assertEq(token.perMint(), perMint, "Per mint should match");
        assertEq(token.price(), price, "Price should match");
        assertEq(token.issuer(), issuer, "Issuer should match");
        assertEq(token.factory(), address(factory), "Factory should match");
        assertEq(token.projectOwner(), projectOwner, "Project owner should match");
    }
    
    /**
     * @dev 测试铸造 Meme 代币
     */
    function testMintMeme() public {
        // 部署代币
        string memory symbol = "DOGE";
        uint256 totalSupply = 1000 ether;
        uint256 perMint = 10 ether;
        uint256 price = 1 ether;
        
        vm.prank(issuer);
        address tokenAddress = factory.deployMeme(symbol, totalSupply, perMint, price);
        
        // 记录初始余额
        uint256 initialProjectBalance = projectOwner.balance;
        uint256 initialIssuerBalance = issuer.balance;
        
        // 铸造代币
        vm.deal(buyer, price);
        vm.prank(buyer);
        factory.mintMeme{value: price}(tokenAddress);
        
        // 验证代币余额
        MemeToken token = MemeToken(tokenAddress);
        assertEq(token.balanceOf(buyer), perMint, "Buyer balance should match");
        assertEq(token.totalSupply(), perMint, "Total supply should match");
        assertEq(token.minted(), perMint, "Minted should match");
        
        // 验证费用分配
        uint256 projectFee = price / 100; // 1%
        uint256 issuerFee = price - projectFee;
        assertEq(projectOwner.balance, initialProjectBalance + projectFee, "Project fee should be transferred");
        assertEq(issuer.balance, initialIssuerBalance + issuerFee, "Issuer fee should be transferred");
        // 验证买家余额（应该为0，因为支付了全部金额）
        assertEq(buyer.balance, 0, "Buyer balance should be 0");
    }
    
    /**
     * @dev 测试铸造数量限制
     */
    function testMintLimit() public {
        // 部署代币，总供应量为 20 ether，每次铸造 10 ether
        string memory symbol = "DOGE";
        uint256 totalSupply = 20 ether;
        uint256 perMint = 10 ether;
        uint256 price = 1 ether;
        
        vm.prank(issuer);
        address tokenAddress = factory.deployMeme(symbol, totalSupply, perMint, price);
        
        MemeToken token = MemeToken(tokenAddress);
        
        // 第一次铸造
        vm.deal(buyer, price * 2);
        vm.prank(buyer);
        factory.mintMeme{value: price}(tokenAddress);
        assertEq(token.balanceOf(buyer), perMint, "First mint balance should match");
        assertEq(token.totalSupply(), perMint, "First mint total supply should match");
        
        // 第二次铸造
        vm.prank(buyer);
        factory.mintMeme{value: price}(tokenAddress);
        assertEq(token.balanceOf(buyer), perMint * 2, "Second mint balance should match");
        assertEq(token.totalSupply(), perMint * 2, "Second mint total supply should match");
        
        // 第三次铸造应该失败（超过总供应量）
        vm.prank(buyer);
        // 这里应该回退，因为超过了总供应量
        bool success;
        bytes memory data;
        (success, data) = address(factory).call{value: price}(abi.encodeWithSignature("mintMeme(address)", tokenAddress));
        // 验证交易失败
        require(!success, "Transaction should have failed");
    }
    
    /**
     * @dev 测试支付金额验证
     */
    function testIncorrectPayment() public {
        // 部署代币
        string memory symbol = "DOGE";
        uint256 totalSupply = 1000 ether;
        uint256 perMint = 10 ether;
        uint256 price = 1 ether;
        
        vm.prank(issuer);
        address tokenAddress = factory.deployMeme(symbol, totalSupply, perMint, price);
        
        // 支付金额不足
        vm.deal(buyer, price - 1);
        vm.prank(buyer);
        vm.expectRevert("Incorrect payment");
        factory.mintMeme{value: price - 1}(tokenAddress);
        
        // 支付金额过多
        vm.deal(buyer, price + 1);
        vm.prank(buyer);
        vm.expectRevert("Incorrect payment");
        factory.mintMeme{value: price + 1}(tokenAddress);
    }
    
    /**
     * @dev 测试未知代币
     */
    function testUnknownMeme() public {
        address invalidToken = address(999);
        vm.deal(buyer, 1 ether);
        vm.prank(buyer);
        vm.expectRevert("Meme not found");
        factory.mintMeme{value: 1 ether}(invalidToken);
    }
}
