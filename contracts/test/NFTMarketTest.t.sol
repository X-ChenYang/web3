// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/NFTMarketV1.sol";
import "../src/NFTMarketV2.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title TestNFT
 * @dev 测试用的NFT合约
 */
contract TestNFT is ERC721 {
    uint256 private _nextTokenId;

    constructor() ERC721("TestNFT", "TNFT") {}

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId;
        _mint(to, tokenId);
        _nextTokenId++;
        return tokenId;
    }
}

/**
 * @title NFTMarketTest
 * @dev 测试可升级NFT市场合约
 */
contract NFTMarketTest is Test {
    NFTMarketV1 public marketV1;
    NFTMarketV2 public marketV2;
    ERC1967Proxy public proxy;
    TestNFT public nft;

    address public owner = address(1);
    address public seller = address(2);
    address public buyer = address(3);

    uint256 public tokenId = 0;
    uint256 public price = 1 ether;

    /**
     * @dev 设置测试环境
     */
    function setUp() public {
        // 部署测试NFT合约
        nft = new TestNFT();

        // 部署V1实现合约
        marketV1 = new NFTMarketV1();

        // 部署代理合约
        proxy = new ERC1967Proxy(
            address(marketV1),
            abi.encodeWithSelector(NFTMarketV1.initialize.selector)
        );

        //  mint NFT给卖家
        vm.prank(owner);
        nft.mint(seller);

        // 卖家授权NFT给市场合约
        vm.prank(seller);
        nft.setApprovalForAll(address(proxy), true);
    }

    /**
     * @dev 测试V1版本的上架和购买功能
     */
    function testV1ListAndBuy() public {
        NFTMarketV1 market = NFTMarketV1(address(proxy));

        // 卖家上架NFT
        vm.prank(seller);
        market.listNFT(address(nft), tokenId, price);

        // 检查上架信息
        (address listedSeller, uint256 listedPrice, bool active) = market.listings(address(nft), tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
        assertTrue(active);

        // 买家购买NFT
        vm.deal(buyer, price);
        vm.prank(buyer);
        market.buyNFT{value: price}(address(nft), tokenId);

        // 检查NFT所有权转移
        assertEq(nft.ownerOf(tokenId), buyer);

        // 检查上架状态
        (listedSeller, listedPrice, active) = market.listings(address(nft), tokenId);
        assertFalse(active);
    }

    /**
     * @dev 测试升级到V2版本
     */
    function testUpgradeToV2() public {
        NFTMarketV1 marketV1Instance = NFTMarketV1(address(proxy));

        // 卖家上架NFT
        vm.prank(seller);
        marketV1Instance.listNFT(address(nft), tokenId, price);

        // 检查上架信息
        (address listedSeller, uint256 listedPrice, bool active) = marketV1Instance.listings(address(nft), tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
        assertTrue(active);

        // 部署V2实现合约
        marketV2 = new NFTMarketV2();

        // 升级到V2版本
        vm.prank(owner);
        (bool success, ) = address(proxy).call(abi.encodeWithSignature("upgradeTo(address)", address(marketV2)));
        require(success, "Upgrade failed");

        // 通过V2接口访问
        NFTMarketV2 marketV2Instance = NFTMarketV2(address(proxy));

        // 检查升级后状态保持一致
        (listedSeller, listedPrice, active) = marketV2Instance.listings(address(nft), tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
        assertTrue(active);

        // 买家购买NFT
        vm.deal(buyer, price);
        vm.prank(buyer);
        marketV2Instance.buyNFT{value: price}(address(nft), tokenId);

        // 检查NFT所有权转移
        assertEq(nft.ownerOf(tokenId), buyer);

        // 检查上架状态
        (listedSeller, listedPrice, active) = marketV2Instance.listings(address(nft), tokenId);
        assertFalse(active);
    }

    /**
     * @dev 测试V2版本的签名购买功能
     */
    function testV2PermitBuy() public {
        // 升级到V2版本
        marketV2 = new NFTMarketV2();
        vm.prank(owner);
        (bool success, ) = address(proxy).call(abi.encodeWithSignature("upgradeTo(address)", address(marketV2)));
        require(success, "Upgrade failed");

        NFTMarketV2 marketV2Instance = NFTMarketV2(address(proxy));

        // 卖家上架NFT
        vm.prank(seller);
        marketV2Instance.listNFT(address(nft), tokenId, price);

        // 生成签名
        uint256 deadline = block.timestamp + 1 days;
        bytes32 structHash = keccak256(abi.encode(tokenId, price, deadline));
        bytes32 domainSeparator = marketV2Instance.getDomainSeparator();
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hash); // 使用私钥1签名

        // 买家通过签名购买NFT
        vm.deal(buyer, price);
        vm.prank(buyer);
        marketV2Instance.permitBuy{value: price}(address(nft), tokenId, price, deadline, v, r, s);

        // 检查NFT所有权转移
        assertEq(nft.ownerOf(tokenId), buyer);

        // 检查上架状态
        (address listedSeller, uint256 listedPrice, bool active) = marketV2Instance.listings(address(nft), tokenId);
        assertFalse(active);
    }

    /**
     * @dev 测试V2版本的签名上架功能
     */
    function testV2PermitListNFT() public {
        // 升级到V2版本
        marketV2 = new NFTMarketV2();
        vm.prank(owner);
        (bool success, ) = address(proxy).call(abi.encodeWithSignature("upgradeTo(address)", address(marketV2)));
        require(success, "Upgrade failed");

        NFTMarketV2 marketV2Instance = NFTMarketV2(address(proxy));

        // 生成签名
        uint256 deadline = block.timestamp + 1 days;
        bytes32 structHash = keccak256(abi.encode(tokenId, price, deadline));
        bytes32 domainSeparator = marketV2Instance.getDomainSeparator();
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hash); // 使用私钥1签名

        // 卖家通过签名上架NFT
        vm.prank(seller);
        marketV2Instance.permitListNFT(address(nft), tokenId, price, deadline, v, r, s);

        // 检查上架信息
        (address listedSeller, uint256 listedPrice, bool active) = marketV2Instance.listings(address(nft), tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
        assertTrue(active);
    }
}
