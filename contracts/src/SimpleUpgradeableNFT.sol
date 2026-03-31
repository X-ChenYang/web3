// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SimpleNFT.sol";

/**
 * @title SimpleUpgradeableNFT
 * @dev 简单的可升级NFT合约
 * @notice 本合约演示了如何通过代理模式实现可升级的NFT合约
 */
contract SimpleUpgradeableNFT is SimpleNFT {
    // 版本号
    uint256 public version;
    
    // 额外的存储变量
    string public baseURI;

    /**
     * @dev 构造函数
     * @param _name NFT名称
     * @param _symbol NFT符号
     */
    constructor(string memory _name, string memory _symbol) SimpleNFT(_name, _symbol) {
        version = 1;
        baseURI = "https://example.com/nfts/";
    }

    /**
     * @dev 设置基础URI
     * @param _baseURI 新的基础URI
     */
    function setBaseURI(string memory _baseURI) public {
        baseURI = _baseURI;
    }

    /**
     * @dev 获取代币URI
     * @param tokenId 代币ID
     * @return 代币URI
     */
    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        require(ownerOf[tokenId] != address(0), "Token does not exist");
        return string(abi.encodePacked(baseURI, toString(tokenId)));
    }

    /**
     * @dev 将uint256转换为字符串
     * @param value 要转换的值
     * @return 转换后的字符串
     */
    function toString(uint256 value) internal pure returns (string memory) {
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
}
