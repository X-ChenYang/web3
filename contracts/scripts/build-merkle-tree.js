const { MerkleTree } = require('merkletreejs');
const { keccak256 } = require('js-sha3');
const { ethers } = require('ethers');

/**
 * Merkle树构建脚本
 * 用于生成白名单的Merkle树根节点和每个地址的proof
 */

// 白名单地址列表（可以根据需要修改）
const whitelistAddresses = [
    '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    '0x70997970C51812dc3A010C7d01b50e0dce2cff',
    '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
    '0x90F79bf6EB2c4f870365E785982EAc3678E22',
    '0x15d34AAf54267DB7D7c367839AAf97A9D925bF',
    '0x9965507D1a55bcC26d5F939895F69B48D9C873',
    '0x976EA74026E726554dB657fA547B40ED1c2b71',
    '0x14dC799B96d4b3b9C04144Db5985B9D11bA',
    '0x2358b674bC9aD612F3E3c8697F849bF0d563',
    '0x4B20993Bc481177ec7E8f7104916986b30122b',
];

/**
 * 构建Merkle树
 * @param addresses 地址数组
 * @returns Merkle树对象
 */
function buildMerkleTree(addresses) {
    // 将地址转换为叶子节点（使用keccak256哈希）
    const leaves = addresses.map(address => 
        keccak256(ethers.utils.defaultAbiCoder.encode(['address'], [address]))
    );
    
    // 创建Merkle树
    const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    
    return tree;
}

/**
 * 获取地址的Merkle证明
 * @param tree Merkle树对象
 * @param address 地址
 * @returns Merkle证明
 */
function getProof(tree, address) {
    const leaf = keccak256(ethers.utils.defaultAbiCoder.encode(['address'], [address]));
    return tree.getHexProof(leaf);
}

/**
 * 验证Merkle证明
 * @param proof Merkle证明
 * @param root Merkle树根节点
 * @param address 地址
 * @returns 是否有效
 */
function verifyProof(proof, root, address) {
    const leaf = keccak256(ethers.utils.defaultAbiCoder.encode(['address'], [address]));
    return MerkleTree.verify(proof, leaf, root);
}

/**
 * 主函数
 */
function main() {
    console.log('Building Merkle Tree for whitelist...\n');
    
    // 构建Merkle树
    const tree = buildMerkleTree(whitelistAddresses);
    
    // 获取Merkle树根节点
    const merkleRoot = tree.getHexRoot();
    console.log('Merkle Root:', merkleRoot);
    
    // 为每个地址生成proof
    console.log('\nGenerating proofs for whitelist addresses...\n');
    const proofs = {};
    
    whitelistAddresses.forEach((address, index) => {
        const proof = getProof(tree, address);
        proofs[address] = proof;
        
        console.log(`Address ${index + 1}: ${address}`);
        console.log(`  Proof: [${proof.join(', ')}]`);
        console.log(`  Verified: ${verifyProof(proof, merkleRoot, address)}`);
        console.log('');
    });
    
    // 导出结果
    const result = {
        merkleRoot: merkleRoot,
        whitelist: whitelistAddresses,
        proofs: proofs,
        totalAddresses: whitelistAddresses.length
    };
    
    console.log('\n=== Summary ===');
    console.log(`Total addresses: ${result.totalAddresses}`);
    console.log(`Merkle Root: ${result.merkleRoot}`);
    
    // 保存到文件
    const fs = require('fs');
    fs.writeFileSync(
        './merkle-tree-output.json',
        JSON.stringify(result, null, 2)
    );
    console.log('\nMerkle tree data saved to merkle-tree-output.json');
    
    return result;
}

// 执行主函数
try {
    main();
} catch (error) {
    console.error('Error building Merkle tree:', error);
    process.exit(1);
}