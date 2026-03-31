// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SimpleToken.sol";
import "./SimpleNFT.sol";

/**
 * @title AirdropMerkleNFTMarket
 * @dev 基于Merkle树白名单的NFT市场合约，支持Permit授权和Multicall调用
 * @notice 本合约实现了基于Merkle树验证的白名单系统，允许白名单用户以优惠价格购买NFT
 */
contract AirdropMerkleNFTMarket {
    // 支付代币合约
    SimpleToken public paymentToken;
    // Permit代币合约
    SimpleToken public permitToken;
    
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
        
        paymentToken = SimpleToken(_paymentToken);
        permitToken = SimpleToken(_paymentToken);
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
        permitToken.permit(owner, spender, value, deadline, v, r, s);
        
        // 标记permit已使用
        bytes32 permitHash = keccak256(
            abi.encodePacked(owner, spender, value, deadline, v, r, s)
        );
        usedPermitSignatures[permitHash] = true;
        
        emit PermitUsed(permitHash);
    }

    /**
     * @dev 领取NFT（通过Merkle树验证白名单）
     * @param tokenId NFT代币ID
     * @param proof Merkle证明
     * @param isWhitelisted 是否使用白名单优惠
     */
    function claimNFT(
        uint256 tokenId,
        bytes32[] calldata proof,
        bool isWhitelisted
    ) external {
        _claimNFT(tokenId, proof, isWhitelisted);
    }

    /**
     * @dev 批量领取NFT
     * @param tokenIds NFT代币ID数组
     * @param proofs Merkle证明数组
     * @param isWhitelisted 是否使用白名单优惠
     */
    function batchClaimNFT(
        uint256[] calldata tokenIds,
        bytes32[][] calldata proofs,
        bool isWhitelisted
    ) external {
        require(tokenIds.length == proofs.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // 内部调用claimNFT的逻辑
            _claimNFT(tokenIds[i], proofs[i], isWhitelisted);
        }
    }

    /**
     * @dev 内部领取NFT函数
     * @param tokenId NFT代币ID
     * @param proof Merkle证明
     * @param isWhitelisted 是否使用白名单优惠
     */
    function _claimNFT(
        uint256 tokenId,
        bytes32[] calldata proof,
        bool isWhitelisted
    ) internal {
        require(listings[tokenId].active, "NFT not listed");
        require(!hasClaimed[msg.sender], "Already claimed");
        
        // 验证白名单
        if (isWhitelisted) {
            require(verifyWhitelist(proof), "Not in whitelist");
        }
        
        // 计算支付价格
        uint256 price = calculatePrice(isWhitelisted);
        
        // 转移代币
        require(paymentToken.transferFrom(msg.sender, address(this), price), "Payment failed");
        
        // 转移NFT
        nftContract.safeTransferFrom(address(this), msg.sender, tokenId);
        
        // 标记为已领取
        hasClaimed[msg.sender] = true;
        
        // 下架NFT
        listings[tokenId].active = false;
        
        emit NFTPurchased(tokenId, msg.sender, price, isWhitelisted);
    }

    /**
     * @dev 提取合约中的代币（仅所有者）
     * @param token 代币合约地址
     * @param amount 提取金额
     */
    function withdrawTokens(address token, uint256 amount) external {
        SimpleToken(token).transfer(msg.sender, amount);
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