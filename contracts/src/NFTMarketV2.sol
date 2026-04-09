// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./NFTMarketV1.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title NFTMarketV2
 * @dev 可升级的NFT市场合约V2版本，添加了离线签名上架功能
 */
contract NFTMarketV2 is NFTMarketV1 {

    /**
     * @dev 获取域名分隔符
     * @return 域名分隔符
     */
    function getDomainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("NFTMarket")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @dev 离线签名验证方法
     * @param tokenId 代币ID
     * @param price 价格
     * @param deadline 截止时间
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     * @return 签名是否有效
     */
    function permitList(uint256 tokenId, uint256 price, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public view returns (bool) {
        require(block.timestamp <= deadline, "Signature expired");
        
        bytes32 structHash = keccak256(abi.encode(tokenId, price, deadline));
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), structHash));
        
        address signer = ECDSA.recover(hash, v, r, s);
        return signer == msg.sender;
    }

    /**
     * @dev 通过签名购买NFT
     * @param nftContract NFT合约地址
     * @param tokenId 代币ID
     * @param price 价格
     * @param deadline 截止时间
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     */
    function permitBuy(address nftContract, uint256 tokenId, uint256 price, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external payable {
        // 验证签名
        require(permitList(tokenId, price, deadline, v, r, s), "Invalid signature");
        
        Listing storage listing = listings[nftContract][tokenId];
        
        // 检查NFT是否上架
        require(listing.active, "NFT not listed");
        
        // 检查价格是否匹配
        require(listing.price == price, "Price mismatch");
        
        // 检查支付金额是否正确
        require(msg.value == price, "Incorrect payment amount");
        
        // 完成购买
        _completePurchase(nftContract, tokenId, listing);
    }

    /**
     * @dev 通过签名上架NFT
     * @param nftContract NFT合约地址
     * @param tokenId 代币ID
     * @param price 价格
     * @param deadline 截止时间
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     */
    function permitListNFT(address nftContract, uint256 tokenId, uint256 price, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        // 验证签名
        require(permitList(tokenId, price, deadline, v, r, s), "Invalid signature");
        
        // 检查价格是否大于0
        require(price > 0, "Price must be greater than 0");
        
        // 检查NFT是否已经上架
        require(!listings[nftContract][tokenId].active, "NFT already listed");
        
        // 检查调用者是否是NFT的所有者
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner of the NFT");
        
        // 检查NFT是否已经授权给市场合约
        require(nft.isApprovedForAll(msg.sender, address(this)) || nft.getApproved(tokenId) == address(this), "NFT not approved for market");
        
        // 创建上架信息
        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });
        
        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }

    
    /**
     * @dev 升级到新实现
     * @param newImplementation 新实现合约地址
     */
    function upgradeTo(address newImplementation) external onlyOwner override {
        // 授权升级
        _authorizeUpgrade(newImplementation);
        // 执行真正的升级操作
        upgradeToAndCall(newImplementation, "");
        // 这里不实现具体的升级逻辑，因为UUPSUpgradeable已经提供了默认实现
        // 升级操作会通过代理合约的fallback函数调用到UUPSUpgradeable的upgradeTo函数
    }
  
}
