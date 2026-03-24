// SPDX-License-Identifier: MIT
// SPDX 许可证标识符：MIT
// Meme 工厂合约 - 使用最小代理模式部署 Meme 代币
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "./MemeToken.sol";

/**
 * @title Meme Factory
 * @dev 使用最小代理模式部署 Meme 代币
 * 最小代理模式可以大幅减少部署成本，提高部署效率
 */
contract MemeFactory {
    // 项目所有者
    address public projectOwner;
    // 实现合约地址
    address public implementation;
    
    /**
     * @dev Meme 代币数据结构
     */
    struct MemeData {
        // 代币符号
        string symbol;
        // 总供应量
        uint256 totalSupply;
        // 每次铸造数量
        uint256 perMint;
        // 铸造价格
        uint256 price;
        // 代币发行者
        address issuer;
    }
    
    // 代币地址到代币数据的映射
    mapping(address => MemeData) public memeTokens;
    
    // Meme 代币部署事件
    event MemeDeployed(address indexed tokenAddress, string symbol, address indexed issuer);
    // Meme 代币铸造事件
    event MemeMinted(address indexed tokenAddress, address indexed buyer, uint256 amount, uint256 price);
    
    /**
     * @dev 构造函数
     * 部署实现合约并设置项目所有者
     */
    constructor() {
        // 设置项目所有者为部署者
        projectOwner = msg.sender;
        // 部署实现合约
        implementation = address(new MemeToken());
    }
    
    /**
     * @dev 部署新的 Meme 代币
     * @param symbol 代币符号
     * @param totalSupply 总供应量
     * @param perMint 每次铸造数量
     * @param price 铸造价格
     * @return 代币合约地址
     */
    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        // 创建最小代理
        address tokenAddress = createMinimalProxy();
        
        // 初始化代币
        MemeToken(tokenAddress).initialize(
            symbol,
            totalSupply,
            perMint,
            price,
            msg.sender, // 发行者为调用者
            address(this), // 工厂合约地址
            projectOwner // 项目所有者
        );
        
        // 存储代币数据
        memeTokens[tokenAddress] = MemeData({
            symbol: symbol,
            totalSupply: totalSupply,
            perMint: perMint,
            price: price,
            issuer: msg.sender
        });
        
        // 触发部署事件
        emit MemeDeployed(tokenAddress, symbol, msg.sender);
        return tokenAddress;
    }
    
    /**
     * @dev 铸造 Meme 代币
     * @param tokenAddr 代币合约地址
     */
    function mintMeme(address tokenAddr) external payable {
        // 获取代币数据
        MemeData memory meme = memeTokens[tokenAddr];
        // 检查代币是否存在
        require(meme.issuer != address(0), "Meme not found");
        
        // 检查支付金额是否正确
        require(msg.value == meme.price, "Incorrect payment");
        
        // 计算费用分配
        uint256 projectFee = msg.value / 100; // 1% 给项目方
        uint256 issuerFee = msg.value - projectFee; // 99% 给发行者
        // 验证费用计算
        require(issuerFee <= msg.value, "Fee calculation error");
        
        // 铸造代币
        MemeToken(tokenAddr).mint(msg.sender, meme.perMint);
        
        // 分配费用给项目方
        (bool projectSuccess, ) = payable(projectOwner).call{value: projectFee}("");
        require(projectSuccess, "Project fee transfer failed");
        // 分配费用给发行者
        (bool issuerSuccess, ) = payable(meme.issuer).call{value: issuerFee}("");
        require(issuerSuccess, "Issuer fee transfer failed");
        
        // 触发铸造事件
        emit MemeMinted(tokenAddr, msg.sender, meme.perMint, msg.value);
    }
    
    /**
     * @dev 创建最小代理
     * @return 代理合约地址
     */
    function createMinimalProxy() internal returns (address) {
        // EIP-1167 最小代理合约字节码
        bytes memory initCode = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73", // 代理合约前缀
            bytes20(implementation), // 实现合约地址
            hex"5af43d82803e903d91602b57fd5bf3" // 代理合约后缀
        );
        
        address proxy;
        // 使用汇编创建代理合约
        assembly {
            proxy := create(0, add(initCode, 0x20), mload(initCode))
        }
        
        // 确保代理合约创建成功
        require(proxy != address(0), "Failed to create proxy");
        return proxy;
    }
}
