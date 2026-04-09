// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/NFTMarketV1.sol";
import "../src/NFTMarketV2.sol";

/**
 * @title DeployNFTMarket
 * @dev 部署可升级NFT市场合约的脚本
 */
contract DeployNFTMarket is Script {
    /**
     * @dev 部署函数
     */
    function run() external {
        console.log("=== Starting deployment of NFT Market contracts ===");
        
        // 开始广播交易
        vm.startBroadcast();
        
        console.log("1. Deploying NFTMarketV1 (V1)...");
        // 部署V1实现合约
        NFTMarketV1 marketV1 = new NFTMarketV1();
        console.log("   NFTMarketV1 deployed at:", address(marketV1));
        
        console.log("2. Deploying ERC1967Proxy...");
        // 部署代理合约，指向V1实现
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(marketV1),
            abi.encodeWithSelector(NFTMarketV1.initialize.selector)
        );
        console.log("   ERC1967Proxy deployed at:", address(proxy));
        
        console.log("3. Deploying NFTMarketV2 (V2)...");
        // 部署V2实现合约
        NFTMarketV2 marketV2 = new NFTMarketV2();
        console.log("   NFTMarketV2 deployed at:", address(marketV2));
        
        // 注意：升级功能需要在部署后手动调用
        // 这里我们只部署合约，不执行升级
        console.log("4. Deployment completed. Upgrade functionality available for future use");
        
        // 停止广播交易
        vm.stopBroadcast();
        
        console.log("=== Deployment completed successfully ===");
        console.log("Proxy contract address:", address(proxy));
        console.log("NFTMarketV1 implementation address:", address(marketV1));
        console.log("NFTMarketV2 implementation address:", address(marketV2));
    }
}
