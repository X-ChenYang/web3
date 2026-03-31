// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/MinimalUpgradeableERC721.sol";
import "../src/MinimalUpgradeableERC721V2.sol";

/**
 * @title MinimalUpgradeableERC721Test
 * @dev 测试最小可升级ERC721合约
 */
contract MinimalUpgradeableERC721Test is Test {
    // 合约实例
    MinimalUpgradeableERC721 public nftV1;
    MinimalUpgradeableERC721V2 public nftV2;
    ERC1967Proxy public proxy;
    
    // 测试地址
    address public owner = address(1);
    address public user = address(2);

    /**
     * @dev 设置测试环境
     */
    function setUp() public {
        vm.startPrank(owner);
        
        // 部署V1实现合约
        nftV1 = new MinimalUpgradeableERC721();
        
        // 部署代理合约
        proxy = new ERC1967Proxy(
            address(nftV1),
            abi.encodeWithSelector(MinimalUpgradeableERC721.initialize.selector)
        );
        
        vm.stopPrank();
    }

    /**
     * @dev 测试V1版本功能
     */
    function testV1Functionality() public {
        vm.startPrank(owner);
        
        // 通过代理调用V1合约
        MinimalUpgradeableERC721 nft = MinimalUpgradeableERC721(address(proxy));
        
        // 测试铸造功能
        uint256 tokenId = nft.mint(user);
        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(tokenId), user);
        assertEq(nft.tokenId(), 1);
        
        // 测试再次铸造
        tokenId = nft.mint(user);
        assertEq(tokenId, 2);
        assertEq(nft.tokenId(), 2);
        
        vm.stopPrank();
    }

    /**
     * @dev 测试升级到V2版本
     */
    function testUpgradeToV2() public {
        vm.startPrank(owner);
        
        // 先测试V1版本
        MinimalUpgradeableERC721 nft = MinimalUpgradeableERC721(address(proxy));
        nft.mint(user);
        assertEq(nft.tokenId(), 1);
        
        // 部署V2实现合约
        nftV2 = new MinimalUpgradeableERC721V2();
        
        // 部署新的代理合约指向V2版本
        ERC1967Proxy proxyV2 = new ERC1967Proxy(
            address(nftV2),
            abi.encodeWithSelector(MinimalUpgradeableERC721V2.initialize.selector)
        );
        
        // 通过代理调用V2合约
        MinimalUpgradeableERC721V2 nftV2Proxy = MinimalUpgradeableERC721V2(address(proxyV2));
        
        // 测试V2版本的新功能
        assertEq(nftV2Proxy.maxSupply(), 1000);
        assertEq(nftV2Proxy.baseURI(), "https://example.com/nfts/");
        
        // 测试设置最大供应量
        nftV2Proxy.setMaxSupply(500);
        assertEq(nftV2Proxy.maxSupply(), 500);
        
        // 测试设置基础URI
        nftV2Proxy.setBaseURI("https://new-example.com/nfts/");
        assertEq(nftV2Proxy.baseURI(), "https://new-example.com/nfts/");
        
        // 测试铸造功能（V2版本）
        uint256 tokenId = nftV2Proxy.mint(user);
        assertEq(tokenId, 1);
        assertEq(nftV2Proxy.tokenId(), 1);
        
        // 测试代币URI
        string memory tokenURI = nftV2Proxy.tokenURI(1);
        assertEq(tokenURI, "https://new-example.com/nfts/1");
        
        vm.stopPrank();
    }

    /**
     * @dev 测试最大供应量限制
     */
    function testMaxSupply() public {
        vm.startPrank(owner);
        
        // 部署V2实现合约
        nftV2 = new MinimalUpgradeableERC721V2();
        
        // 部署代理合约指向V2版本
        ERC1967Proxy proxyV2 = new ERC1967Proxy(
            address(nftV2),
            abi.encodeWithSelector(MinimalUpgradeableERC721V2.initialize.selector)
        );
        
        MinimalUpgradeableERC721V2 nftV2Proxy = MinimalUpgradeableERC721V2(address(proxyV2));
        
        // 设置最大供应量为2
        nftV2Proxy.setMaxSupply(2);
        
        // 铸造2个NFT
        nftV2Proxy.mint(user);
        nftV2Proxy.mint(user);
        
        // 尝试铸造第3个NFT，应该失败
        vm.expectRevert("Max supply reached");
        nftV2Proxy.mint(user);
        
        vm.stopPrank();
    }
}
