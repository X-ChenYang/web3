// SPDX-License-Identifier: MIT
// 许可证声明：MIT 开源许可证
pragma solidity ^0.8.20;  // Solidity 版本：0.8.20 及以上
// 导入 OpenZeppelin 库

// 定义 MyToken 合约
contract MyToken {
    // 代币名称
    string public name;
    // 代币符号
    string public symbol;
    // 代币小数位数
    uint8 public decimals;
    // 代币总供应量
    uint256 public totalSupply;
    
    // 余额映射：地址 => 余额
    mapping(address => uint256) public balanceOf;
    // 授权映射：(授权方, 被授权方) => 授权额度
    mapping(address => mapping(address => uint256)) public allowance;
    
    // 事件：当代币被转移时触发
    event Transfer(address indexed from, address indexed to, uint256 value);
    // 事件：当授权发生时触发
    event Approval(address indexed owner, address indexed spender, uint256 value);
    // 事件：当铸造新代币时触发
    event TokensMinted(address indexed to, uint256 amount);
    // 事件：当销毁代币时触发
    event TokensBurned(address indexed from, uint256 amount);
    
    // 构造函数：合约部署时执行一次
    // 参数：
    //   name_ - 代币名称，例如 "MyToken"
    //   symbol_ - 代币符号，例如 "MTK"
    //   decimals_ - 代币小数位数，通常为 18
    //   initialSupply - 初始供应量（不包含小数位）
    constructor(
        string memory name_, 
        string memory symbol_, 
        uint8 decimals_,
        uint256 initialSupply
    ) {
        // 设置代币基本信息
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        
        // 铸造初始供应量给部署者
        // 10 ** decimals_ 是为了考虑小数位，例如 1000 * 10^18 = 1000000000000000000000
        _mint(msg.sender, initialSupply * 10 ** uint256(decimals_));
    }
    
    // 内部函数：铸造代币
    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
        emit TokensMinted(to, amount);
    }
    
    // 内部函数：销毁代币
    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
        emit TokensBurned(from, amount);
    }
    
    // 内部函数：扣除授权额度
    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            allowance[owner][spender] = currentAllowance - amount;
        }
    }
    
    // 转账函数
    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    // 内部转账函数
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(balanceOf[from] >= amount, "ERC20: insufficient balance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
    
    // 授权函数
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    // 内部授权函数
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    // 授权转账函数
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }
    
    // 铸造代币函数
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
    
    // 销毁代币函数
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
    
    // 代币授权销毁函数
    function burnFrom(address account, uint256 amount) public {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }
    // 实现 ERC165 接口
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
    return interfaceId == 0x36372b07;
    }

}
