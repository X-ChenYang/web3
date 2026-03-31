// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SimpleToken
 * @dev 简化的ERC20代币合约，支持Permit功能
 * @notice 本合约实现了基本的ERC20功能，包括转账、授权等操作，并支持EIP-2612 Permit功能
 */
contract SimpleToken {
    // 代币名称
    string public name;
    // 代币符号
    string public symbol;
    // 小数位数
    uint8 public decimals = 18;
    // 总供应量
    uint256 public totalSupply;
    
    // 记录地址的余额
    mapping(address => uint256) public balanceOf;
    // 记录授权关系
    mapping(address => mapping(address => uint256)) public allowance;
    // 记录地址的nonce（用于Permit）
    mapping(address => uint256) public nonces;
    
    // 事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    /**
     * @dev 构造函数
     * @param _name 代币名称
     * @param _symbol 代币符号
     * @param _totalSupply 总供应量
     */
    constructor(string memory _name, string memory _symbol, uint256 _totalSupply) {
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }
    
    /**
     * @dev 转账函数
     * @param to 接收地址
     * @param value 转账金额
     * @return bool 转账是否成功
     */
    function transfer(address to, uint256 value) public returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    /**
     * @dev 授权函数
     * @param spender 授权地址
     * @param value 授权金额
     * @return bool 授权是否成功
     */
    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    /**
     * @dev 授权转账函数
     * @param from 发送地址
     * @param to 接收地址
     * @param value 转账金额
     * @return bool 转账是否成功
     */
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        require(balanceOf[from] >= value, "Insufficient balance");
        
        allowance[from][msg.sender] -= value;
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
    
    /**
     * @dev 铸造代币
     * @param to 接收地址
     * @param amount 铸造金额
     */
    function mint(address to, uint256 amount) public {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
    
    /**
     * @dev EIP-2612 Permit函数
     * @param owner 代币所有者
     * @param spender 授权的接收者
     * @param value 授权金额
     * @param deadline 过期时间
     * @param v 签名的v值
     * @param r 签名的r值
     * @param s 签名的s值
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(block.timestamp <= deadline, "Permit expired");
        
        // 构建EIP-712消息
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                31337, // Anvil默认链ID
                address(this)
            )
        );
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonces[owner],
                deadline
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );
        
        address signer = ecrecover(digest, v, r, s);
        require(signer == owner, "Invalid signature");
        
        nonces[owner]++;
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
}