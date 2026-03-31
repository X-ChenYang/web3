// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/MinimalUpgradeableERC721.sol";
import "../src/MinimalUpgradeableERC721V2.sol";

/**
 * @title DeployUpgradeableNFT
 * @dev 部署可升级ERC721合约的脚本
 */
contract DeployUpgradeableNFT is Script {
    /**
     * @dev 部署函数
     */
    function run() external {
        console.log("=== Starting deployment of Upgradeable NFT contracts ===");
        
        // 开始广播交易
        vm.startBroadcast();
        
        console.log("1. Deploying MinimalUpgradeableERC721 (V1)...");
        // 部署V1实现合约
        MinimalUpgradeableERC721 nftV1 = new MinimalUpgradeableERC721();
        console.log("   MinimalUpgradeableERC721 deployed at:", address(nftV1));
        
        console.log("2. Deploying ERC1967Proxy for V1...");
        // 部署代理合约，指向V1实现
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(nftV1),
            abi.encodeWithSelector(MinimalUpgradeableERC721.initialize.selector)
        );
        console.log("   ERC1967Proxy deployed at:", address(proxy));
        
        console.log("3. Testing V1 functionality...");
        // 通过代理调用V1合约
        MinimalUpgradeableERC721 proxyV1 = MinimalUpgradeableERC721(address(proxy));
        
        // 测试V1版本的铸造功能
        uint256 tokenId = proxyV1.mint(msg.sender);
        console.log("   Minted token ID:", tokenId);
        console.log("   Token owner:", proxyV1.ownerOf(tokenId));
        
        console.log("4. Deploying MinimalUpgradeableERC721V2 (V2)...");
        // 部署V2实现合约
        MinimalUpgradeableERC721V2 nftV2 = new MinimalUpgradeableERC721V2();
        console.log("   MinimalUpgradeableERC721V2 deployed at:", address(nftV2));
        
        console.log("5. Deploying ERC1967Proxy for V2...");
        // 部署新的代理合约指向V2版本
        ERC1967Proxy proxyV2 = new ERC1967Proxy(
            address(nftV2),
            abi.encodeWithSelector(MinimalUpgradeableERC721V2.initialize.selector)
        );
        console.log("   ERC1967Proxy V2 deployed at:", address(proxyV2));
        
        console.log("6. Testing V2 functionality...");
        // 通过代理调用V2合约
        MinimalUpgradeableERC721V2 proxyV2Instance = MinimalUpgradeableERC721V2(address(proxyV2));
        
        // 测试V2版本的新功能
        proxyV2Instance.setMaxSupply(10);
        console.log("   Max supply set to:", proxyV2Instance.maxSupply());
        
        proxyV2Instance.setBaseURI("https://example.com/nfts/");
        console.log("   Base URI set to:", proxyV2Instance.baseURI());
        
        // 测试V2版本的铸造功能
        tokenId = proxyV2Instance.mint(msg.sender);
        console.log("   Minted token ID (V2):", tokenId);
        console.log("   Token URI:", proxyV2Instance.tokenURI(tokenId));
        
        // 停止广播交易
        vm.stopBroadcast();
        
        console.log("=== Deployment completed successfully ===");
    }
}
