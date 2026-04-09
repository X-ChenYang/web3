// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IToken 接口
 * @dev 扩展了ERC20接口，添加了mint方法
 */
interface IToken is IERC20 {
    /**
     * @dev 铸造新的代币
     * @param to 接收代币的地址
     * @param amount 铸造的代币数量
     */
    function mint(address to, uint256 amount) external;
}

/**
 * @title KK Token 合约
 * @dev 实现了IToken接口，是一个可铸造的ERC20代币
 * 初始供应量为0，只有Owner可以铸造新代币
 */
contract KKToken is ERC20, Ownable, IToken {
    /**
     * @dev 构造函数
     * @notice 初始化KK Token合约，设置名称和符号
     * 初始供应量为0，Owner为部署者
     */
    constructor(address initialOwner) ERC20("KK Token", "KK") Ownable(initialOwner) {
        // 初始供应量为0
    }

    /**
     * @dev 铸造新的KK Token
     * @param to 接收代币的地址
     * @param amount 铸造的代币数量
     * @notice 只有合约Owner可以调用此方法
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

