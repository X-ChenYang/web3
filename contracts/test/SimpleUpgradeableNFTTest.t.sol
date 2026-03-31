// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleUpgradeableNFT.sol";
import "../src/SimpleUpgradeableNFTV2.sol";

/**
 * @title SimpleUpgradeableNFTTest
 * @dev 简单可升级NFT合约测试
 * @notice 本测试合约测试简单可升级NFT的功能
 */
contract SimpleUpgradeableNFTTest is Test {
    // 合约实例
    SimpleUpgradeableNFT public nftV1;
    SimpleUpgradeableNFTV2 public nftV2;
    
    // 测试地址
    address public owner = address(1);
    address public user = address(2);

    /**
     * @dev 测试设置
     */
    function setUp() public {
        vm.startPrank(owner);
        
        // 部署V1版本
        nftV1 = new SimpleUpgradeableNFT("Upgradeable NFT", "UNFT");
        
        // 部署V2版本
        nftV2 = new SimpleUpgradeableNFTV2("Upgradeable NFT", "UNFT");
        
        vm.stopPrank();
    }

    /**
     * @dev 测试V1版本的功能
     */
    function testV1Functionality() public {
        vm.startPrank(owner);
        
        // 测试铸造NFT
        uint256 tokenId = nftV1.mintNFT(user, "");
        assertEq(tokenId, 1);
        assertEq(nftV1.ownerOf(tokenId), user);
        assertEq(nftV1.balanceOf(user), 1);
        
        // 测试设置基础URI
        nftV1.setBaseURI("https://new-example.com/nfts/");
        assertEq(nftV1.baseURI(), "https://new-example.com/nfts/");
        
        // 测试获取代币URI
        string memory tokenURI = nftV1.getTokenURI(tokenId);
        assertEq(tokenURI, "https://new-example.com/nfts/1");
        
        // 测试版本号
        assertEq(nftV1.version(), 1);
        
        vm.stopPrank();
    }

    /**
     * @dev 测试V2版本的功能
     */
    function testV2Functionality() public {
        vm.startPrank(owner);
        
        // 测试铸造NFT
        uint256 tokenId = nftV2.mintNFT(user, "");
        assertEq(tokenId, 1);
        assertEq(nftV2.ownerOf(tokenId), user);
        
        // 测试设置最大供应量
        nftV2.setMaxSupply(5);
        assertEq(nftV2.maxSupply(), 5);
        
        // 测试设置铸造价格
        nftV2.setMintPrice(0.1 ether);
        assertEq(nftV2.mintPrice(), 0.1 ether);
        
        // 测试带支付的铸造
        vm.deal(owner, 1 ether);
        tokenId = nftV2.mintNFTWithPayment{value: 0.1 ether}(user, "");
        assertEq(tokenId, 2);
        
        // 测试提取资金
        uint256 balanceBefore = address(owner).balance;
        nftV2.withdraw(0.1 ether);
        assertEq(address(owner).balance, balanceBefore + 0.1 ether);
        
        // 测试最大供应量限制
        for (uint256 i = 0; i < 3; i++) {
            nftV2.mintNFT(user, "");
        }
        
        // 尝试铸造超过最大供应量
        vm.expectRevert();
        nftV2.mintNFT(user, "");
        
        // 测试版本号
        assertEq(nftV2.version(), 2);
        
        vm.stopPrank();
    }

    /**
     * @dev 测试V2版本的向后兼容性
     */
    function testV2BackwardCompatibility() public {
        vm.startPrank(owner);
        
        // 测试V1版本的功能在V2中仍然可用
        uint256 tokenId = nftV2.mintNFT(user, "");
        assertEq(tokenId, 1);
        
        nftV2.setBaseURI("https://v2-example.com/nfts/");
        assertEq(nftV2.baseURI(), "https://v2-example.com/nfts/");
        
        string memory tokenURI = nftV2.getTokenURI(tokenId);
        assertEq(tokenURI, "https://v2-example.com/nfts/1");
        
        vm.stopPrank();
    }
}
