// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// 导入UUPSUpgradeable的接口
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title NFTMarketV1
 * @dev 可升级的NFT市场合约V1版本
 */
contract NFTMarketV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // 上架的NFT信息
    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    // NFT合约地址 => tokenId => 上架信息
    mapping(address => mapping(uint256 => Listing)) public listings;

    // 事件：NFT上架
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, uint256 price);
    // 事件：NFT购买
    event NFTPurchased(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, uint256 price);
    // 事件：NFT下架
    event NFTRemoved(address indexed nftContract, uint256 indexed tokenId, address indexed seller);

    /**
     * @dev 初始化函数
     */
    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    /**
     * @dev 上架NFT
     * @param nftContract NFT合约地址
     * @param tokenId 代币ID
     * @param price 价格
     */
    function listNFT(address nftContract, uint256 tokenId, uint256 price) external {
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
     * @dev 购买NFT
     * @param nftContract NFT合约地址
     * @param tokenId 代币ID
     */
    function buyNFT(address nftContract, uint256 tokenId) external payable {
        Listing storage listing = listings[nftContract][tokenId];
        
        // 检查NFT是否上架
        require(listing.active, "NFT not listed");
        
        // 检查支付金额是否正确
        require(msg.value == listing.price, "Incorrect payment amount");
        
        // 完成购买
        _completePurchase(nftContract, tokenId, listing);
    }

    /**
     * @dev 下架NFT
     * @param nftContract NFT合约地址
     * @param tokenId 代币ID
     */
    function removeNFT(address nftContract, uint256 tokenId) external {
        Listing storage listing = listings[nftContract][tokenId];
        
        // 检查NFT是否上架
        require(listing.active, "NFT not listed");
        
        // 检查调用者是否是卖家
        require(listing.seller == msg.sender, "Not the seller");
        
        // 下架NFT
        listing.active = false;
        
        emit NFTRemoved(nftContract, tokenId, msg.sender);
    }

    /**
     * @dev 完成购买
     * @param nftContract NFT合约地址
     * @param tokenId 代币ID
     * @param listing 上架信息
     */
    function _completePurchase(address nftContract, uint256 tokenId, Listing storage listing) internal {
        // 标记NFT为已售出
        listing.active = false;
        
        // 转移NFT
        IERC721 nft = IERC721(nftContract);
        nft.safeTransferFrom(listing.seller, msg.sender, tokenId);
        
        // 转移资金
        (bool success, ) = listing.seller.call{value: listing.price}("");
        require(success, "Failed to transfer funds");
        
        emit NFTPurchased(nftContract, tokenId, msg.sender, listing.price);
    }

    /**
     * @dev 授权升级
     * @param newImplementation 新实现合约地址
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    /**
     * @dev 升级到新实现
     * @param newImplementation 新实现合约地址
     */
    function upgradeTo(address newImplementation) external onlyOwner virtual {
        // 必须先授权（UUPS强制要求）
        _authorizeUpgrade(newImplementation);
        // 执行真正的升级操作
        upgradeToAndCall(newImplementation, "");
    }
}
