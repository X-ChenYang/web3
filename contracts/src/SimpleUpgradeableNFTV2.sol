// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SimpleUpgradeableNFT.sol";

/**
 * @title SimpleUpgradeableNFTV2
 * @dev 简单的可升级NFT合约 V2版本
 * @notice 本合约是SimpleUpgradeableNFT的V2版本，添加了新功能
 */
contract SimpleUpgradeableNFTV2 is SimpleUpgradeableNFT {
    // V2版本新增：最大供应量
    uint256 public maxSupply;
    
    // V2版本新增：铸造价格
    uint256 public mintPrice;

    /**
     * @dev 构造函数
     * @param _name NFT名称
     * @param _symbol NFT符号
     */
    constructor(string memory _name, string memory _symbol) SimpleUpgradeableNFT(_name, _symbol) {
        version = 2;
        maxSupply = 1000;
        mintPrice = 0.1 ether;
    }

    /**
     * @dev V2版本新增：设置最大供应量
     * @param _maxSupply 最大供应量
     */
    function setMaxSupply(uint256 _maxSupply) public {
        maxSupply = _maxSupply;
    }

    /**
     * @dev V2版本新增：设置铸造价格
     * @param _mintPrice 铸造价格
     */
    function setMintPrice(uint256 _mintPrice) public {
        mintPrice = _mintPrice;
    }

    /**
     * @dev V2版本重写：铸造NFT
     * @param to 接收地址
     * @param uri NFT的URI
     * @return tokenId 铸造的代币ID
     */
    function mintNFT(address to, string memory uri) public override returns (uint256) {
        // V2版本新增：检查最大供应量
        require(totalSupply < maxSupply, "Max supply reached");
        
        // 调用父合约的mintNFT函数
        return super.mintNFT(to, uri);
    }

    /**
     * @dev V2版本新增：带支付的铸造NFT
     * @param to 接收地址
     * @param uri NFT的URI
     * @return tokenId 铸造的代币ID
     */
    function mintNFTWithPayment(address to, string memory uri) public payable returns (uint256) {
        // 检查支付金额
        require(msg.value >= mintPrice, "Insufficient payment");
        
        // 调用mintNFT函数
        return mintNFT(to, uri);
    }

    /**
     * @dev V2版本新增：提取资金
     * @param amount 提取金额
     */
    function withdraw(uint256 amount) public {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(msg.sender).transfer(amount);
    }
}
