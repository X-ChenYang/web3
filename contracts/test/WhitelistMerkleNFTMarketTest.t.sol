// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MyPermitToken.sol";
import "../src/SimpleNFT.sol";
import "../src/WhitelistMerkleNFTMarket.sol";

/**
 * @title WhitelistMerkleNFTMarketTest
 * @dev WhitelistMerkleNFTMarket合约的测试用例
 * @notice 本测试合约测试了WhitelistMerkleNFTMarket的各种功能，包括Merkle树验证、NFT购买、Permit签名等
 */
contract WhitelistMerkleNFTMarketTest is Test {
    // 合约实例
    MyPermitToken public token; // 代币合约
    SimpleNFT public nft; // NFT合约
    WhitelistMerkleNFTMarket public market; // 市场合约
    
    // 测试用户地址
    address public owner = address(this); // 测试合约地址（部署者）
    uint256 public user1PrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public user1 = vm.addr(user1PrivateKey); // 测试用户1（与私钥匹配）
    address public user2 = address(2); // 测试用户2
    
    // 测试金额
    uint256 public initialTokenSupply = 1000000 ether; // 初始代币供应量
    uint256 public nftPrice = 100 ether; // NFT原价
    uint256 public discountPrice = 50 ether; // 50% 折扣价格
    
    // Merkle树相关
    bytes32 public merkleRoot; // Merkle树根节点
    bytes32[][] public userProofs; // 用户Merkle证明
    
    // Permit相关
    uint256 public permitDeadline; // Permit过期时间

    /**
     * @dev 测试设置
     */
    function setUp() public {
        // 部署代币合约
        token = new MyPermitToken("Whitelist Token", "WLT", initialTokenSupply);
        
        // 部署NFT合约
        nft = new SimpleNFT("Whitelist NFT", "WLN");
        
        // 构建Merkle树
        buildMerkleTree();
        
        // 部署市场合约
        market = new WhitelistMerkleNFTMarket(
            address(token),
            address(nft),
            nftPrice,
            merkleRoot
        );
        
        // 铸造NFT给市场合约
        uint256[] memory tokenIds = nft.batchMintNFT(
            address(market),
            new string[](5)
        );
        
        // 设置permit过期时间
        permitDeadline = block.timestamp + 1 days;
        
        // 分配代币给测试用户
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        
        // 转移代币给测试用户
        token.mint(user1, 1000 ether);
        token.mint(user2, 1000 ether);
        
        // 上架NFT
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(address(market));
            market.listNFT(i, nftPrice);
        }
    }

    /**
     * @dev 构建Merkle树
     */
    function buildMerkleTree() internal {
        // 创建白名单地址数组
        address[] memory addresses = new address[](2);
        addresses[0] = user1;
        addresses[1] = user2;
        
        // 构建Merkle树
        bytes32[] memory leaves = new bytes32[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(addresses[i]));
        }
        
        // 计算Merkle树根节点
        merkleRoot = computeMerkleRoot(leaves);
        
        // 为每个用户生成proof
        userProofs = new bytes32[][](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            userProofs[i] = getMerkleProof(leaves, i);
        }
    }

    /**
     * @dev 计算Merkle树根节点
     * @param leaves 叶子节点数组
     * @return bytes32 Merkle树根节点
     */
    function computeMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        if (leaves.length == 0) {
            return bytes32(0);
        }
        
        bytes32[] memory currentLayer = leaves;
        uint256 currentLayerSize = leaves.length;
        
        while (currentLayerSize > 1) {
            bytes32[] memory nextLayer = new bytes32[]((currentLayerSize + 1) / 2);
            
            for (uint256 i = 0; i < currentLayerSize; i += 2) {
                if (i + 1 == currentLayerSize) {
                    nextLayer[i / 2] = currentLayer[i];
                } else {
                    // 确保哈希顺序正确
                    if (currentLayer[i] <= currentLayer[i + 1]) {
                        nextLayer[i / 2] = keccak256(
                            abi.encodePacked(currentLayer[i], currentLayer[i + 1])
                        );
                    } else {
                        nextLayer[i / 2] = keccak256(
                            abi.encodePacked(currentLayer[i + 1], currentLayer[i])
                        );
                    }
                }
            }
            
            currentLayer = nextLayer;
            currentLayerSize = (currentLayerSize + 1) / 2;
        }
        
        return currentLayer[0];
    }

    /**
     * @dev 获取Merkle证明
     * @param leaves 叶子节点数组
     * @param index 索引
     * @return bytes32[] Merkle证明
     */
    function getMerkleProof(bytes32[] memory leaves, uint256 index) internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](32);
        uint256 proofSize = 0;
        
        bytes32[] memory currentLayer = leaves;
        uint256 currentLayerSize = leaves.length;
        uint256 currentIndex = index;
        
        while (currentLayerSize > 1) {
            bytes32[] memory nextLayer = new bytes32[]((currentLayerSize + 1) / 2);
            
            for (uint256 i = 0; i < currentLayerSize; i += 2) {
                if (i + 1 == currentLayerSize) {
                    nextLayer[i / 2] = currentLayer[i];
                } else {
                    // 确保哈希顺序正确
                    if (currentLayer[i] <= currentLayer[i + 1]) {
                        nextLayer[i / 2] = keccak256(
                            abi.encodePacked(currentLayer[i], currentLayer[i + 1])
                        );
                    } else {
                        nextLayer[i / 2] = keccak256(
                            abi.encodePacked(currentLayer[i + 1], currentLayer[i])
                        );
                    }
                }
            }
            
            // 生成proof
            if (currentIndex % 2 == 0) {
                if (currentIndex + 1 < currentLayerSize) {
                    proof[proofSize++] = currentLayer[currentIndex + 1];
                }
            } else {
                proof[proofSize++] = currentLayer[currentIndex - 1];
            }
            
            currentIndex = currentIndex / 2;
            currentLayer = nextLayer;
            currentLayerSize = (currentLayerSize + 1) / 2;
        }
        
        // 调整proof数组大小
        bytes32[] memory finalProof = new bytes32[](proofSize);
        for (uint256 i = 0; i < proofSize; i++) {
            finalProof[i] = proof[i];
        }
        
        return finalProof;
    }

    /**
     * @dev 生成Permit签名
     * @param tokenOwner 代币所有者
     * @param spender 支出者地址
     * @param value 授权金额
     * @param privateKey 私钥
     * @return v 签名v值
     * @return r 签名r值
     * @return s 签名s值
     */
    function generatePermitSignature(
        address tokenOwner,
        address spender,
        uint256 value,
        uint256 privateKey
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        uint256 nonce = token.nonces(tokenOwner);
        
        // 构建EIP-712消息
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(token.name())),
                keccak256(bytes("1")),
                31337, // Anvil默认链ID
                address(token)
            )
        );
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                tokenOwner,
                spender,
                value,
                nonce,
                permitDeadline
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );
        
        (v, r, s) = vm.sign(privateKey, digest);
    }

    /**
     * @dev 测试直接调用permitPrePay()和buyNFTInWhitelist()
     */
    function testDirectCallPermitAndBuyNFT() public {
        // 生成Permit签名
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(
            user1,
            address(market),
            discountPrice,
            user1PrivateKey
        );
        
        // 先授权
        vm.prank(user1);
        market.permitPrePay(
            user1,
            address(market),
            discountPrice,
            permitDeadline,
            v,
            r,
            s
        );
        
        // 再购买NFT
        vm.prank(user1);
        market.buyNFTInWhitelist(0, userProofs[0]);
        
        // 验证NFT已转移
        assertEq(nft.balanceOf(user1), 1);
        assertEq(token.balanceOf(user1), 1000 ether - discountPrice);
        
        // 验证用户已在白名单中
        assertTrue(token.isWhitelisted(user1));
        
        // 验证用户已领取
        assertTrue(market.hasClaimed(user1));
    }

    /**
     * @dev 测试multicall封装permitPrePay()和buyNFTInWhitelist()调用
     */
    function testMulticallPermitAndBuyNFT() public {
        // 生成Permit签名
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(
            user1,
            address(market),
            discountPrice,
            user1PrivateKey
        );
        
        // 构建Multicall调用
        bytes[] memory calls = new bytes[](2);
        
        // 第一个调用：permitPrePay
        calls[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            user1,
            address(market),
            discountPrice,
            permitDeadline,
            v,
            r,
            s
        );
        
        // 第二个调用：buyNFTInWhitelist
        calls[1] = abi.encodeWithSelector(
            market.buyNFTInWhitelist.selector,
            1, // tokenId
            userProofs[0] // proof
        );
        
        // 执行Multicall
        vm.prank(user1);
        market.multicall(calls);
        
        // 验证NFT已转移
        assertEq(nft.balanceOf(user1), 1);
        assertEq(token.balanceOf(user1), 1000 ether - discountPrice);
        
        // 验证用户已在白名单中
        assertTrue(token.isWhitelisted(user1));
        
        // 验证用户已领取
        assertTrue(market.hasClaimed(user1));
    }

    /**
     * @dev 测试Merkle树验证
     */
    function testMerkleTreeVerification() public {
        // 验证user1在白名单中
        vm.prank(user1);
        bool verified = market.verifyWhitelist(userProofs[0]);
        assertTrue(verified, "User1 should be in whitelist");
        
        // 验证user2在白名单中
        vm.prank(user2);
        verified = market.verifyWhitelist(userProofs[1]);
        assertTrue(verified, "User2 should be in whitelist");
    }

    /**
     * @dev 测试价格计算
     */
    function testPriceCalculation() public {
        // 白名单用户价格
        uint256 whitelistPrice = market.calculatePrice(true);
        assertEq(whitelistPrice, discountPrice);
        
        // 非白名单用户价格
        uint256 normalPrice = market.calculatePrice(false);
        assertEq(normalPrice, nftPrice);
    }

    /**
     * @dev 测试无效的Merkle证明
     */
    function testInvalidMerkleProof() public {
        // 使用无效的proof
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = keccak256("invalid proof");
        
        vm.prank(user1);
        vm.expectRevert("Not in whitelist");
        market.buyNFTInWhitelist(0, invalidProof);
    }

    /**
     * @dev 测试重复购买
     */
    function testDuplicatePurchase() public {
        // 第一次购买
        testDirectCallPermitAndBuyNFT();
        
        // 第二次购买（应该失败）
        vm.prank(user1);
        vm.expectRevert("Already claimed");
        market.buyNFTInWhitelist(1, userProofs[0]);
    }
}