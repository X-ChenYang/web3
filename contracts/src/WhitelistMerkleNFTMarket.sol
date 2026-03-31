// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MyPermitToken.sol";
import "./SimpleNFT.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

/**
 * @title WhitelistMerkleNFTMarket
 * @dev 基于Merkle树白名单的NFT市场合约
 * @notice 本合约实现了基于Merkle树验证的白名单系统，允许白名单用户以优惠价格购买NFT
 */
contract WhitelistMerkleNFTMarket is Multicall {
    // 支付代币合约
    MyPermitToken public paymentToken;
    
    // NFT合约
    SimpleNFT public nftContract;
    
    // Merkle树根节点
    bytes32 public merkleRoot;
    
    // NFT价格（原价）
    uint256 public nftPrice;
    
    // 优惠折扣（50%）
    uint256 public constant DISCOUNT = 50; // 50%
    uint256 public constant DISCOUNT_DIVISOR = 100; // 100%
    
    // 记录已领取的用户
    mapping(address => bool) public hasClaimed;
    
    // 记录已使用的permit签名
    mapping(bytes32 => bool) public usedPermitSignatures;
    
    // NFT上架信息
    struct NFTListing {
        uint256 tokenId; // NFT代币ID
        uint256 price; // NFT价格
        bool active; // 是否活跃
    }
    
    // 记录NFT上架信息
    mapping(uint256 => NFTListing) public listings;
    // 记录活跃的NFT列表
    uint256[] public activeListings;
    
    // 事件
    event NFTListed(uint256 indexed tokenId, uint256 price, bool whitelisted);
    event NFTPurchased(uint256 indexed tokenId, address indexed buyer, uint256 paidAmount, bool usedDiscount);
    event MerkleRootUpdated(bytes32 newRoot);
    event PermitUsed(bytes32 indexed permitHash);

    /**
     * @dev 构造函数
     * @param _paymentToken 支付代币合约地址
     * @param _nftContract NFT合约地址
     * @param _nftPrice NFT价格
     * @param _merkleRoot Merkle树根节点
     */
    constructor(
        address _paymentToken,
        address _nftContract,
        uint256 _nftPrice,
        bytes32 _merkleRoot
    ) {
        require(_paymentToken != address(0), "Invalid payment token address");
        require(_nftContract != address(0), "Invalid NFT contract address");
        
        paymentToken = MyPermitToken(_paymentToken);
        nftContract = SimpleNFT(_nftContract);
        nftPrice = _nftPrice;
        merkleRoot = _merkleRoot;
    }

    /**
     * @dev 上架NFT
     * @param tokenId NFT代币ID
     * @param price NFT价格
     */
    function listNFT(uint256 tokenId, uint256 price) external {
        require(nftContract.ownerOf(tokenId) == address(this), "NFT not owned by contract");
        require(price > 0, "Price must be greater than 0");
        
        listings[tokenId] = NFTListing(tokenId, price, true);
        activeListings.push(tokenId);
        
        emit NFTListed(tokenId, price, false);
    }

    /**
     * @dev 上架NFT（白名单用户）
     * @param tokenId NFT代币ID
     * @param price NFT价格
     * @param isWhitelisted 是否白名单用户
     */
    function listNFTWhitelist(uint256 tokenId, uint256 price, bool isWhitelisted) external {
        require(nftContract.ownerOf(tokenId) == address(this), "NFT not owned by contract");
        require(price > 0, "Price must be greater than 0");
        
        listings[tokenId] = NFTListing(tokenId, price, true);
        activeListings.push(tokenId);
        
        emit NFTListed(tokenId, price, isWhitelisted);
    }

    /**
     * @dev 更新Merkle树根节点
     * @param _merkleRoot 新的Merkle树根节点
     */
    function updateMerkleRoot(bytes32 _merkleRoot) external {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    /**
     * @dev 更新NFT价格
     * @param _nftPrice 新的NFT价格
     */
    function updateNFTPrice(uint256 _nftPrice) external {
        nftPrice = _nftPrice;
    }

    /**
     * @dev 计算实际支付价格（白名单用户享受50%折扣）
     * @param isWhitelisted 是否白名单用户
     * @return 实际支付价格
     */
    function calculatePrice(bool isWhitelisted) public view returns (uint256) {
        if (isWhitelisted) {
            return (nftPrice * (DISCOUNT_DIVISOR - DISCOUNT)) / DISCOUNT_DIVISOR;
        }
        return nftPrice;
    }

    /**
     * @dev 验证Merkle证明
     * @param proof Merkle证明
     * @return 是否在白名单中
     */
    function verifyWhitelist(bytes32[] calldata proof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        return _verifyProof(proof, merkleRoot, leaf);
    }
    
    /**
     * @dev 验证Merkle证明的内部函数
     * @param proof Merkle证明
     * @param root Merkle树根节点
     * @param leaf 叶子节点
     * @return 是否验证成功
     */
    function _verifyProof(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;
        
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        
        return computedHash == root;
    }

    /**
     * @dev Permit预支付函数（用于Multicall）
     * @param owner 代币所有者
     * @param spender 支出者地址
     * @param value 授权金额
     * @param deadline 过期时间
     * @param v 签名v值
     * @param r 签名r值
     * @param s 签名s值
     */
    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 直接调用token的permit函数
        paymentToken.permit(owner, spender, value, deadline, v, r, s);
        
        // 标记permit已使用
        bytes32 permitHash = keccak256(
            abi.encodePacked(owner, spender, value, deadline, v, r, s)
        );
        usedPermitSignatures[permitHash] = true;
        
        emit PermitUsed(permitHash);
    }

    /**
     * @dev 白名单用户购买NFT
     * @param tokenId NFT代币ID
     * @param proof Merkle证明
     */
    function buyNFTInWhitelist(
        uint256 tokenId,
        bytes32[] calldata proof
    ) external {
        // 验证NFT是否上架
        require(listings[tokenId].active, "NFT not listed");
        // 验证用户是否已领取
        require(!hasClaimed[msg.sender], "Already claimed");
        
        // 验证白名单
        require(verifyWhitelist(proof), "Not in whitelist");
        
        // 调用MyPermitToken.addToWhitelist()方法
        paymentToken.addToWhitelist(msg.sender);
        
        // 计算支付价格（白名单用户享受50%折扣）
        uint256 price = calculatePrice(true);
        
        // 转移代币
        require(paymentToken.transferFrom(msg.sender, address(this), price), "Payment failed");
        
        // 转移NFT
        nftContract.safeTransferFrom(address(this), msg.sender, tokenId);
        
        // 标记为已领取
        hasClaimed[msg.sender] = true;
        
        // 下架NFT
        listings[tokenId].active = false;
        
        emit NFTPurchased(tokenId, msg.sender, price, true);
    }

    /**
     * @dev 普通用户购买NFT
     * @param tokenId NFT代币ID
     */
    function buyNFT(uint256 tokenId) external {
        // 验证NFT是否上架
        require(listings[tokenId].active, "NFT not listed");
        // 验证用户是否已领取
        require(!hasClaimed[msg.sender], "Already claimed");
        
        // 计算支付价格（全价）
        uint256 price = calculatePrice(false);
        
        // 转移代币
        require(paymentToken.transferFrom(msg.sender, address(this), price), "Payment failed");
        
        // 转移NFT
        nftContract.safeTransferFrom(address(this), msg.sender, tokenId);
        
        // 标记为已领取
        hasClaimed[msg.sender] = true;
        
        // 下架NFT
        listings[tokenId].active = false;
        
        emit NFTPurchased(tokenId, msg.sender, price, false);
    }

    /**
     * @dev 提取合约中的代币（仅所有者）
     * @param amount 提取金额
     */
    function withdrawTokens(uint256 amount) external {
        paymentToken.transfer(msg.sender, amount);
    }

    /**
     * @dev 提取合约中的NFT（仅所有者）
     * @param tokenId NFT代币ID
     */
    function withdrawNFT(uint256 tokenId) external {
        nftContract.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    /**
     * @dev 获取当前上架的NFT数量
     * @return 上架NFT数量
     */
    function getActiveListingsCount() public view returns (uint256) {
        return activeListings.length;
    }

    /**
     * @dev 获取指定索引的上架NFT
     * @param index 索引
     * @return NFT代币ID
     */
    function getActiveListing(uint256 index) public view returns (uint256) {
        require(index < activeListings.length, "Index out of bounds");
        return activeListings[index];
    }

    /**
     * @dev 获取NFT详细信息
     * @param tokenId NFT代币ID
     * @return NFT上架信息
     */
    function getNFTListing(uint256 tokenId) public view returns (NFTListing memory) {
        return listings[tokenId];
    }
}