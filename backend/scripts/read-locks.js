// 导入viem库的必要函数
const { createPublicClient, http, getAddress, formatEther, toHex, keccak256, pad, hexToBigInt } = require('viem');
const { foundry } = require('viem/chains');

// 配置RPC URL和合约地址
const rpcUrl = process.env.ANVIL_URL || 'http://localhost:8545';
const contractAddress = process.env.ESRNT_ADDRESS || '0x5FbDB2315678afecb367f032d93F642f64180aa3';

// 常量定义
const LOCKS_SLOT = 0n; // _locks数组的存储槽位
const ADDRESS_MASK = (1n << 160n) - 1n; // 地址掩码，用于从打包值中提取地址
const UINT64_MASK = (1n << 64n) - 1n; // uint64掩码，用于从打包值中提取startTime
const STRUCT_SLOTS = 2n; // 每个结构体占用的存储槽位数

/**
 * 读取指定槽位的存储值
 * @param {ReturnType<typeof createPublicClient>} client - Viem公共客户端
 * @param {bigint} slot - 存储槽位
 * @returns {Promise<bigint>} - 存储值
 */
async function readSlot(client, slot) {
  const value = await client.getStorageAt({
    address: contractAddress,
    slot: toHex(slot),
  });
  return hexToBigInt(value || '0x0');
}

/**
 * 计算数组的基础槽位
 * @param {bigint} slot - 数组的存储槽位
 * @returns {bigint} - 数组的基础槽位
 */
function getArrayBaseSlot(slot) {
  return hexToBigInt(keccak256(pad(toHex(slot), { size: 32 })));
}

/**
 * 主函数，读取并打印_locks数组的所有元素
 */
async function main() {
  // 创建Viem公共客户端
  const client = createPublicClient({
    chain: foundry,
    transport: http(rpcUrl),
  });

  // 读取数组长度
  const length = await readSlot(client, LOCKS_SLOT);
  // 计算数组基础槽位
  const baseSlot = getArrayBaseSlot(LOCKS_SLOT);

  console.log(`RPC: ${rpcUrl}`);
  console.log(`ESRnt: ${contractAddress}`);
  console.log(`locks length: ${length}`);

  // 遍历数组元素
  for (let i = 0n; i < length; i++) {
    // 读取打包槽位（包含user和startTime）
    const packedSlot = await readSlot(client, baseSlot + i * STRUCT_SLOTS);
    // 读取amount槽位
    const amount = await readSlot(client, baseSlot + i * STRUCT_SLOTS + 1n);

    // 从打包槽位中解析user（最后20字节）
    const user = getAddress(`0x${(packedSlot & ADDRESS_MASK).toString(16).padStart(40, '0')}`);
    // 从打包槽位中解析startTime（中间8字节）
    const startTime = (packedSlot >> 160n) & UINT64_MASK;

    // 打印结果
    console.log(`locks[${i}]: user:${user}, startTime:${startTime}, amount:${formatEther(amount)}`);
  }
}

// 执行主函数
main().catch((error) => {
  console.error('Error reading locks:', error);
  process.exit(1);
});