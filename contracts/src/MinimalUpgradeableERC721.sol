// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title MinimalUpgradeableERC721
 * @dev 最小可升级ERC721合约
 * @notice 基于UUPS代理模式的可升级ERC721合约实现
 */
contract MinimalUpgradeableERC721 is 
    Initializable, 
    ERC721Upgradeable, 
    OwnableUpgradeable, 
    UUPSUpgradeable
{
    // 代币ID计数器
    uint256 public tokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数（替代构造函数）
     */
    function initialize() public initializer {
        // 1. 初始化ERC721名称、符号
        __ERC721_init("Upgradeable NFT", "UNFT");
        // 2. 初始化所有权，将部署者设为 owner（必须传 msg.sender）
        __Ownable_init(msg.sender);
        
        tokenId = 0;
    }

    /**
     * @dev 铸造NFT
     * @param to 接收地址
     * @return 铸造的代币ID
     */
    function mint(address to) public onlyOwner returns (uint256) {
        tokenId++;
        _mint(to, tokenId);
        return tokenId;
    }

    /**
     * @dev 授权升级
     * @param newImplementation 新的实现合约地址
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
