// SPDX-License-Identifier: MIT
// SPDX 许可证标识符：MIT
// Meme 代币合约 - ERC20 代币模板
pragma solidity ^0.8.20;

import "forge-std/console.sol";

/**
 * @title Meme Token
 * @dev ERC20 代币模板，用于最小代理部署
 * 这是一个标准的 ERC20 代币实现，包含铸造功能
 */
contract MemeToken {
    // 代币名称
    string public name;
    // 代币符号
    string public symbol;
    // 小数位数
    uint8 public decimals = 18;
    // 当前总供应量
    uint256 public totalSupply;
    // 最大供应量
    uint256 public maxSupply;
    // 每次铸造数量
    uint256 public perMint;
    // 铸造价格
    uint256 public price;
    // 代币发行者
    address public issuer;
    // 工厂合约地址
    address public factory;
    // 项目所有者
    address public projectOwner;
    // 已铸造数量
    uint256 public minted;

    // 余额映射
    mapping(address => uint256) public balanceOf;
    // 授权映射
    mapping(address => mapping(address => uint256)) public allowance;

    // 转账事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    // 授权事件
    event Approval(address indexed owner, address indexed spender, uint256 value);
    // 铸造事件
    event Mint(address indexed to, uint256 amount);

    /**
     * @dev 初始化函数，由工厂合约调用
     * @param _symbol 代币符号
     * @param _totalSupply 总供应量
     * @param _perMint 每次铸造数量
     * @param _price 铸造价格
     * @param _issuer 代币发行者
     * @param _factory 工厂合约地址
     * @param _projectOwner 项目所有者
     */
    function initialize(
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address _issuer,
        address _factory,
        address _projectOwner
    ) external {
        // 确保合约只初始化一次
        require(factory == address(0), "Already initialized");
        
        // 设置代币名称
        name = string(abi.encodePacked("Meme Token: ", _symbol));
        // 设置代币符号
        symbol = _symbol;
        // 设置最大供应量
        maxSupply = _totalSupply;
        // 设置每次铸造数量
        perMint = _perMint;
        // 设置铸造价格
        price = _price;
        // 设置代币发行者
        issuer = _issuer;
        // 设置工厂合约地址
        factory = _factory;
        // 设置项目所有者
        projectOwner = _projectOwner;
    }

    /**
     * @dev 铸造代币
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external {
        // 只有工厂合约可以铸造
        require(msg.sender == factory, "Only factory can mint");
        // 确保不超过最大供应量
        require(minted + amount <= maxSupply, "Exceeds max supply");
        
        // 增加接收者余额
        balanceOf[to] += amount;
        // 增加总供应量
        totalSupply += amount;
        // 增加已铸造数量
        minted += amount;
        
        // 触发铸造事件
        emit Mint(to, amount);
        // 触发转账事件（从地址0转账）
        emit Transfer(address(0), to, amount);
    }

    /**
     * @dev 转账
     * @param to 接收地址
     * @param value 转账金额
     * @return 是否成功
     */
    function transfer(address to, uint256 value) external returns (bool) {
        // 禁止转账到零地址
        require(to != address(0), "Transfer to zero address");
        // 检查余额是否足够
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        
        // 减少发送者余额
        balanceOf[msg.sender] -= value;
        // 增加接收者余额
        balanceOf[to] += value;
        
        // 触发转账事件
        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev 授权
     * @param spender 授权地址
     * @param value 授权金额
     * @return 是否成功
     */
    function approve(address spender, uint256 value) external returns (bool) {
        // 设置授权金额
        allowance[msg.sender][spender] = value;
        // 触发授权事件
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev 授权转账
     * @param from 发送地址
     * @param to 接收地址
     * @param value 转账金额
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        // 禁止转账到零地址
        require(to != address(0), "Transfer to zero address");
        // 检查余额是否足够
        require(balanceOf[from] >= value, "Insufficient balance");
        // 检查授权是否足够
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        
        // 减少发送者余额
        balanceOf[from] -= value;
        // 增加接收者余额
        balanceOf[to] += value;
        // 减少授权金额
        allowance[from][msg.sender] -= value;
        
        // 触发转账事件
        emit Transfer(from, to, value);
        return true;
    }
}
