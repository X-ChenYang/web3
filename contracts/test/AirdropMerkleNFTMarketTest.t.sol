// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleToken.sol";
import "../src/SimpleNFT.sol";
import "../src/AirdropMerkleNFTMarket.sol";
import "../src/MulticallHelper.sol";

/**
 * @title AirdropMerkleNFTMarketTest
 * @dev AirdropMerkleNFTMarket合约的完整测试用例
 * @notice 本测试合约测试了AirdropMerkleNFTMarket的各种功能，包括Merkle树验证、NFT购买、Permit签名等
 */
contract AirdropMerkleNFTMarketTest is Test {
    // 合约实例
    SimpleToken public token; // 代币合约
    SimpleNFT public nft; // NFT合约
    AirdropMerkleNFTMarket public market; // 市场合约
    MulticallHelper public multicallHelper; // 多调用辅助合约
    
    // 测试用户地址
    address public owner = address(this); // 测试合约地址（部署者）
    address public user1 = address(1); // 测试用户1
    address public user2 = address(2); // 测试用户2
    address public user3 = address(3); // 测试用户3
    address public user4 = address(4); // 测试用户4
    address public user5 = address(5); // 测试用户5
    
    // 测试金额
    uint256 public initialTokenSupply = 1000000 ether; // 初始代币供应量
    uint256 public nftPrice = 100 ether; // NFT原价
    uint256 public discountPrice = 50 ether; // 50% 折扣价格
    
    // Merkle树相关
    bytes32 public merkleRoot; // Merkle树根节点
    bytes32[][] public userProofs; // 用户Merkle证明
    
    // Permit相关
    uint256 public permitDeadline; // Permit过期时间
    uint8 public permitV; // Permit签名v值
    bytes32 public permitR; // Permit签名r值
    bytes32 public permitS; // Permit签名s值

    /**
     * @dev 测试设置
     */
    function setUp() public {
        // 部署代币合约
        token = new SimpleToken("Airdrop Token", "ADT", initialTokenSupply);
        
        // 部署NFT合约
        nft = new SimpleNFT("Airdrop NFT", "ADN");
        
        // 部署Multicall辅助合约
        multicallHelper = new MulticallHelper();
        
        // 构建Merkle树
        buildMerkleTree();
        
        // 部署市场合约
        market = new AirdropMerkleNFTMarket(
            address(token),
            address(nft),
            nftPrice,
            merkleRoot
        );
        
        // 铸造NFT给市场合约
        uint256[] memory tokenIds = nft.batchMintNFT(
            address(market),
            new string[](10)
        );
        
        // 设置permit过期时间
        permitDeadline = block.timestamp + 1 days;
        
        // 分配代币给测试用户
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(user3, 1000 ether);
        vm.deal(user4, 1000 ether);
        vm.deal(user5, 1000 ether);
        
        // 铸造代币给测试用户
        token.mint(user1, 1000 ether);
        token.mint(user2, 1000 ether);
        token.mint(user3, 1000 ether);
        token.mint(user4, 1000 ether);
        token.mint(user5, 1000 ether);
        
        // 上架NFT
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(address(market));
            market.listNFT(i, nftPrice);
        }
    }

    /**
     * @dev 构建Merkle树
     */
    function buildMerkleTree() internal {
        // 创建白名单地址数组
        address[] memory addresses = new address[](5);
        addresses[0] = user1;
        addresses[1] = user2;
        addresses[2] = user3;
        addresses[3] = user4;
        addresses[4] = user5;
        
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

    // 测试1: 基本Merkle树验证
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

    // 测试2: 白名单用户购买NFT（享受50%折扣）
    function testWhitelistUserPurchaseNFT() public {
        // 生成Permit签名
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(
            user1,
            address(market),
            discountPrice,
            0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        );
        
        // 构建Multicall调用
        MulticallHelper.Call[] memory calls = new MulticallHelper.Call[](2);
        
        // 第一个调用：permitPrePay
        calls[0] = MulticallHelper.Call({
            target: address(market),
            data: abi.encodeWithSelector(
                market.permitPrePay.selector,
                user1,
                address(market),
                discountPrice,
                permitDeadline,
                v,
                r,
                s
            )
        });
        
        // 第二个调用：claimNFT
        calls[1] = MulticallHelper.Call({
            target: address(market),
            data: abi.encodeWithSelector(
                market.claimNFT.selector,
                0, // tokenId
                userProofs[0], // proof
                true // isWhitelisted
            )
        });
        
        // 执行Multicall
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        vm.expectEmit(true, true, false, true);
        multicallHelper.multicall(calls);
        
        // 验证NFT已转移
        assertEq(nft.balanceOf(user1), 1);
        assertEq(token.balanceOf(user1), 1000 ether - discountPrice);
    }

    // 测试3: 非白名单用户购买NFT（全价）
    function testNonWhitelistUserPurchaseNFT() public {
        // 生成Permit签名
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(
            user3,
            address(market),
            nftPrice,
            0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
        );
        
        // 构建Multicall调用
        MulticallHelper.Call[] memory calls = new MulticallHelper.Call[](2);
        
        // 第一个调用：permitPrePay
        calls[0] = MulticallHelper.Call({
            target: address(market),
            data: abi.encodeWithSelector(
                market.permitPrePay.selector,
                user3,
                address(market),
                nftPrice,
                permitDeadline,
                v,
                r,
                s
            )
        });
        
        // 第二个调用：claimNFT
        calls[1] = MulticallHelper.Call({
            target: address(market),
            data: abi.encodeWithSelector(
                market.claimNFT.selector,
                1, // tokenId
                new bytes32[](0), // empty proof
                false // isWhitelisted
            )
        });
        
        // 执行Multicall
        vm.prank(user3);
        multicallHelper.multicall(calls);
        
        // 验证NFT已转移
        assertEq(nft.balanceOf(user3), 1);
        assertEq(token.balanceOf(user3), 1000 ether - nftPrice);
    }

    // 测试4: 重复购买NFT（应该失败）
    function testDuplicateClaimNFT() public {
        // 第一次购买
        testWhitelistUserPurchaseNFT();
        
        // 第二次购买（应该失败）
        vm.prank(user1);
        vm.expectRevert("Already claimed");
        market.claimNFT(0, userProofs[0], true);
    }

    // 测试5: 更新Merkle树根节点
    function testUpdateMerkleRoot() public {
        bytes32 newRoot = keccak256("new root");
        
        vm.prank(address(market));
        vm.expectEmit(true, true, false, true);
        market.updateMerkleRoot(newRoot);
        
        assertEq(market.merkleRoot(), newRoot);
    }

    // 测试6: NFT上架功能
    function testListNFT() public {
        // 铸造新的NFT
        uint256 tokenId = nft.mintNFT(address(this), "ipfs://test-uri");
        
        // 转移NFT给市场合约
        nft.transferFrom(address(this), address(market), tokenId);
        
        // 上架NFT
        vm.prank(address(market));
        vm.expectEmit(true, true, false, true);
        market.listNFT(tokenId, nftPrice);
        
        // 验证NFT已上架
        AirdropMerkleNFTMarket.NFTListing memory listing = market.getNFTListing(tokenId);
        assertEq(listing.price, nftPrice);
        assertTrue(listing.active);
    }

    // 测试7: 价格计算功能
    function testPriceCalculation() public {
        // 白名单用户价格
        uint256 whitelistPrice = market.calculatePrice(true);
        assertEq(whitelistPrice, discountPrice);
        
        // 非白名单用户价格
        uint256 normalPrice = market.calculatePrice(false);
        assertEq(normalPrice, nftPrice);
    }

    // 测试8: 批量购买NFT
    function testBatchClaimNFT() public {
        // 生成Permit签名
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(
            user4,
            address(market),
            discountPrice * 2,
            0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
        );
        
        // 批量购买NFT
        MulticallHelper.Call[] memory calls = new MulticallHelper.Call[](4);
        
        // 第一组调用：permitPrePay + claimNFT
        calls[0] = MulticallHelper.Call({
            target: address(market),
            data: abi.encodeWithSelector(
                market.permitPrePay.selector,
                user4,
                address(market),
                discountPrice,
                permitDeadline,
                v,
                r,
                s
            )
        });
        
        calls[1] = MulticallHelper.Call({
            target: address(market),
            data: abi.encodeWithSelector(
                market.claimNFT.selector,
                2, // tokenId
                userProofs[3], // proof
                true // isWhitelisted
            )
        });
        
        // 第二组调用：permitPrePay + claimNFT
        calls[2] = MulticallHelper.Call({
            target: address(market),
            data: abi.encodeWithSelector(
                market.permitPrePay.selector,
                user4,
                address(market),
                discountPrice,
                permitDeadline,
                v,
                r,
                s
            )
        });
        
        calls[3] = MulticallHelper.Call({
            target: address(market),
            data: abi.encodeWithSelector(
                market.claimNFT.selector,
                3, // tokenId
                userProofs[3], // proof
                true // isWhitelisted
            )
        });
        
        // 执行Multicall
        vm.prank(user4);
        multicallHelper.multicall(calls);
        
        // 验证NFT已转移
        assertEq(nft.balanceOf(user4), 2);
        assertEq(token.balanceOf(user4), 1000 ether - discountPrice * 2);
    }

    // 测试9: 提取功能
    function testWithdrawTokens() public {
        // 部署者提取代币
        vm.prank(address(market));
        market.withdrawTokens(address(token), 100 ether);
        
        assertEq(token.balanceOf(address(market)), 100 ether);
    }

    // 测试10: 更新NFT价格
    function testUpdateNFTPrice() public {
        uint256 newPrice = 200 ether;
        
        vm.prank(address(market));
        market.updateNFTPrice(newPrice);
        
        assertEq(market.nftPrice(), newPrice);
    }

    // 测试11: Permit签名验证
    function testPermitSignature() public {
        // 生成Permit签名
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(
            user5,
            address(market),
            nftPrice,
            0xef3972c9bf3fcc6b6b1f058c82750c18270bfe2eae912c03d5e6cab90a956d78
        );
        
        // 执行permit
        vm.prank(user5);
        token.permit(
            user5,
            address(market),
            nftPrice,
            permitDeadline,
            v,
            r,
            s
        );
        
        // 验证授权
        assertEq(token.allowance(user5, address(market)), nftPrice);
    }

    // 测试12: 无效的Merkle证明
    function testInvalidMerkleProof() public {
        // 使用无效的proof
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = keccak256("invalid proof");
        
        vm.prank(user1);
        vm.expectRevert("Not in whitelist");
        market.claimNFT(0, invalidProof, true);
    }

    // 测试13: 获取上架NFT列表
    function testGetActiveListings() public {
        uint256 count = market.getActiveListingsCount();
        assertEq(count, 10);
        
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = market.getActiveListing(i);
            assertTrue(tokenId < 10);
        }
    }
}