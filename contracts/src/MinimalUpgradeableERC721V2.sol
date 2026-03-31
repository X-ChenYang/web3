// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title MinimalUpgradeableERC721V2
 * @dev 最小可升级ERC721合约V2版本
 * @notice 基于UUPS代理模式的可升级ERC721合约实现，添加了新功能
 */
contract MinimalUpgradeableERC721V2 is 
    Initializable, 
    ERC721Upgradeable, 
    OwnableUpgradeable, 
    UUPSUpgradeable
{
    // 代币ID计数器（与V1保持一致）
    uint256 public tokenId;
    
    // V2版本新增：最大供应量
    uint256 public maxSupply;
    
    // V2版本新增：基础URI
    string public baseURI;

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
        maxSupply = 1000;
        baseURI = "https://example.com/nfts/";
    }

    /**
     * @dev 铸造NFT
     * @param to 接收地址
     * @return 铸造的代币ID
     */
    function mint(address to) public onlyOwner returns (uint256) {
        require(tokenId < maxSupply, "Max supply reached");
        tokenId++;
        _mint(to, tokenId);
        return tokenId;
    }

    /**
     * @dev 设置最大供应量
     * @param _maxSupply 新的最大供应量
     */
    function setMaxSupply(uint256 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
    }

    /**
     * @dev 设置基础URI
     * @param _baseURI 新的基础URI
     */
    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    /**
     * @dev 获取代币URI
     * @param _tokenId 代币ID
     * @return 代币URI
     */
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(ownerOf(_tokenId) != address(0), "Token does not exist");
        return string(abi.encodePacked(baseURI, _toString(_tokenId)));
    }

    /**
     * @dev 将uint256转换为字符串
     * @param value 要转换的值
     * @return 转换后的字符串
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev 授权升级
     * @param newImplementation 新的实现合约地址
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
