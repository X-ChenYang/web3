// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/**
 * @title MerkleTreeTest
 * @dev 测试Merkle树的基本功能
 * @notice 本合约测试了Merkle树的构建、根节点计算和证明验证功能
 */
contract MerkleTreeTest is Test {
    // 测试用户地址
    address public user1 = address(1); // 测试用户1
    address public user2 = address(2); // 测试用户2
    address public user3 = address(3); // 测试用户3
    address public user4 = address(4); // 测试用户4
    address public user5 = address(5); // 测试用户5
    
    // Merkle树相关
    bytes32 public merkleRoot; // Merkle树根节点
    bytes32[][] public userProofs; // 用户Merkle证明数组

    /**
     * @dev 测试设置函数
     * @notice 在每个测试用例执行前运行，构建Merkle树
     */
    function setUp() public {
        // 构建Merkle树
        buildMerkleTree();
    }

    /**
     * @dev 构建Merkle树
     * @notice 为测试用户构建Merkle树并生成每个用户的证明
     */
    function buildMerkleTree() internal {
        // 创建白名单地址数组
        address[] memory addresses = new address[](5);
        addresses[0] = user1;
        addresses[1] = user2;
        addresses[2] = user3;
        addresses[3] = user4;
        addresses[4] = user5;
        
        // 构建Merkle树叶子节点
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
     * @notice 递归计算Merkle树根节点，处理偶数和奇数数量的叶子节点
     */
    function computeMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        // 处理空叶子节点数组
        if (leaves.length == 0) {
            return bytes32(0);
        }
        
        // 初始化当前层为叶子节点层
        bytes32[] memory currentLayer = leaves;
        uint256 currentLayerSize = leaves.length;
        
        // 循环计算直到只剩一个节点（根节点）
        while (currentLayerSize > 1) {
            // 计算下一层节点数量
            bytes32[] memory nextLayer = new bytes32[]((currentLayerSize + 1) / 2);
            
            // 遍历当前层节点，两两组合计算下一层节点
            for (uint256 i = 0; i < currentLayerSize; i += 2) {
                if (i + 1 == currentLayerSize) {
                    // 处理奇数数量的情况，直接使用最后一个节点
                    nextLayer[i / 2] = currentLayer[i];
                } else {
                    // 确保哈希顺序正确（小的在前，大的在后）
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
            
            // 更新当前层和层大小
            currentLayer = nextLayer;
            currentLayerSize = (currentLayerSize + 1) / 2;
        }
        
        // 返回根节点
        return currentLayer[0];
    }

    /**
     * @dev 获取Merkle证明
     * @param leaves 叶子节点数组
     * @param index 目标叶子节点的索引
     * @return bytes32[] Merkle证明数组
     * @notice 生成指定索引叶子节点的Merkle证明
     */
    function getMerkleProof(bytes32[] memory leaves, uint256 index) internal pure returns (bytes32[] memory) {
        // 预分配最大可能的证明大小
        bytes32[] memory proof = new bytes32[](32);
        uint256 proofSize = 0;
        
        // 初始化当前层和索引
        bytes32[] memory currentLayer = leaves;
        uint256 currentLayerSize = leaves.length;
        uint256 currentIndex = index;
        
        // 循环生成证明直到到达根节点
        while (currentLayerSize > 1) {
            // 计算下一层节点
            bytes32[] memory nextLayer = new bytes32[]((currentLayerSize + 1) / 2);
            
            // 遍历当前层节点，两两组合计算下一层节点
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
            
            // 生成当前层的证明元素
            if (currentIndex % 2 == 0) {
                // 当前索引是偶数，证明元素是右侧节点
                if (currentIndex + 1 < currentLayerSize) {
                    proof[proofSize++] = currentLayer[currentIndex + 1];
                }
            } else {
                // 当前索引是奇数，证明元素是左侧节点
                proof[proofSize++] = currentLayer[currentIndex - 1];
            }
            
            // 更新索引和当前层
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
     * @dev 验证Merkle证明
     * @param proof Merkle证明数组
     * @param root Merkle树根节点
     * @param leaf 要验证的叶子节点
     * @return bool 验证是否成功
     * @notice 使用Merkle证明验证叶子节点是否属于Merkle树
     */
    function verifyProof(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        // 从叶子节点开始计算
        bytes32 computedHash = leaf;
        
        // 遍历证明元素，逐步计算到根节点
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            
            // 确保哈希顺序正确
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        
        // 验证计算出的根节点是否与提供的根节点匹配
        return computedHash == root;
    }

    /**
     * @dev 测试Merkle树根节点计算
     * @notice 验证Merkle树根节点是否正确计算
     */
    function testMerkleRootCalculation() public {
        // 验证根节点不为零
        assertTrue(merkleRoot != bytes32(0), "Merkle root should not be zero");
    }

    /**
     * @dev 验证user1的Merkle证明
     * @notice 测试user1的Merkle证明是否有效
     */
    function testUser1Proof() public {
        // 计算user1的叶子节点
        bytes32 leaf = keccak256(abi.encodePacked(user1));
        // 验证证明
        bool verified = verifyProof(userProofs[0], merkleRoot, leaf);
        // 断言验证成功
        assertTrue(verified, "User1 should be in whitelist");
    }

    /**
     * @dev 验证user2的Merkle证明
     * @notice 测试user2的Merkle证明是否有效
     */
    function testUser2Proof() public {
        // 计算user2的叶子节点
        bytes32 leaf = keccak256(abi.encodePacked(user2));
        // 验证证明
        bool verified = verifyProof(userProofs[1], merkleRoot, leaf);
        // 断言验证成功
        assertTrue(verified, "User2 should be in whitelist");
    }

    /**
     * @dev 验证无效的Merkle证明
     * @notice 测试无效的Merkle证明是否被正确拒绝
     */
    function testInvalidProof() public {
        // 创建无效的证明
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = keccak256("invalid");
        
        // 计算user1的叶子节点
        bytes32 leaf = keccak256(abi.encodePacked(user1));
        // 验证无效证明
        bool verified = verifyProof(invalidProof, merkleRoot, leaf);
        // 断言验证失败
        assertFalse(verified, "Invalid proof should fail");
    }
}