// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SimpleNFT
 * @dev 简化的ERC721 NFT合约
 * @notice 本合约实现了基本的NFT功能，包括铸造、转移、授权等操作
 */
contract SimpleNFT {
    // NFT名称
    string public name;
    // NFT符号
    string public symbol;
    // 总供应量
    uint256 public totalSupply;
    
    // 记录代币ID对应的所有者
    mapping(uint256 => address) public ownerOf;
    // 记录地址拥有的NFT数量
    mapping(address => uint256) public balanceOf;
    // 记录代币ID对应的授权地址
    mapping(uint256 => address) public getApproved;
    // 记录地址对另一个地址的授权状态
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    // 记录代币ID对应的URI
    mapping(uint256 => string) public tokenURI;
    
    // 代币ID计数器
    uint256 private _tokenIdCounter;
    
    // 事件
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    
    /**
     * @dev 构造函数
     * @param _name NFT名称
     * @param _symbol NFT符号
     */
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }
    
    /**
     * @dev 铸造单个NFT
     * @param to 接收地址
     * @param uri NFT的URI
     * @return tokenId 铸造的代币ID
     */
    function mintNFT(address to, string memory uri) public returns (uint256) {
        // 获取当前代币ID
        uint256 tokenId = _tokenIdCounter;
        // 增加代币ID计数器
        _tokenIdCounter++;
        
        // 记录所有权
        ownerOf[tokenId] = to;
        // 增加接收地址的NFT数量
        balanceOf[to]++;
        // 设置代币URI
        tokenURI[tokenId] = uri;
        // 增加总供应量
        totalSupply++;
        
        // 触发转移事件
        emit Transfer(address(0), to, tokenId);
        // 返回铸造的代币ID
        return tokenId;
    }
    
    /**
     * @dev 批量铸造NFT
     * @param to 接收地址
     * @param uris NFT的URI数组
     * @return tokenIds 铸造的代币ID数组
     */
    function batchMintNFT(address to, string[] memory uris) public returns (uint256[] memory) {
        // 创建代币ID数组
        uint256[] memory tokenIds = new uint256[](uris.length);
        
        // 遍历URI数组，铸造每个NFT
        for (uint256 i = 0; i < uris.length; i++) {
            // 铸造单个NFT
            tokenIds[i] = mintNFT(to, uris[i]);
        }
        
        // 返回铸造的代币ID数组
        return tokenIds;
    }
    
    /**
     * @dev 转移NFT
     * @param from 发送地址
     * @param to 接收地址
     * @param tokenId 代币ID
     */
    function transferFrom(address from, address to, uint256 tokenId) public {
        // 检查调用者是否是所有者或授权地址
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not approved");
        // 检查发送地址是否是当前所有者
        require(ownerOf[tokenId] == from, "Invalid owner");
        // 检查接收地址是否有效
        require(to != address(0), "Invalid recipient");
        
        // 更新所有权
        ownerOf[tokenId] = to;
        // 更新余额
        balanceOf[from]--;
        balanceOf[to]++;
        
        // 触发转移事件
        emit Transfer(from, to, tokenId);
    }
    
    /**
     * @dev 安全转移NFT
     * @param from 发送地址
     * @param to 接收地址
     * @param tokenId 代币ID
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        // 调用转移函数
        transferFrom(from, to, tokenId);
        // 检查接收地址是否是ERC721接收器
        _checkOnERC721Received(from, to, tokenId, "");
    }
    
    /**
     * @dev 授权NFT
     * @param to 授权地址
     * @param tokenId 代币ID
     */
    function approve(address to, uint256 tokenId) public {
        // 检查调用者是否是所有者或授权地址
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not approved");
        // 设置授权
        getApproved[tokenId] = to;
        // 触发授权事件
        emit Approval(ownerOf[tokenId], to, tokenId);
    }
    
    /**
     * @dev 批量授权NFT
     * @param operator 操作地址
     * @param approved 授权状态
     */
    function setApprovalForAll(address operator, bool approved) public {
        // 设置批量授权
        isApprovedForAll[msg.sender][operator] = approved;
        // 触发批量授权事件
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    /**
     * @dev 检查地址是否是所有者或授权地址
     * @param spender 检查的地址
     * @param tokenId 代币ID
     * @return bool 是否是所有者或授权地址
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf[tokenId];
        return (spender == owner || getApproved[tokenId] == spender || isApprovedForAll[owner][spender]);
    }
    
    /**
     * @dev 检查接收地址是否是ERC721接收器
     * @param from 发送地址
     * @param to 接收地址
     * @param tokenId 代币ID
     * @param data 附加数据
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                require(retval == IERC721Receiver.onERC721Received.selector, "Not ERC721Receiver");
            } catch {
                revert("Not ERC721Receiver");
            }
        }
    }
    
    /**
     * @dev 获取当前代币ID
     * @return uint256 当前代币ID
     */
    function getCurrentTokenId() public view returns (uint256) {
        return _tokenIdCounter;
    }
}

/**
 * @title IERC721Receiver
 * @dev ERC721接收器接口
 */
interface IERC721Receiver {
    /**
     * @dev 接收ERC721代币
     * @param operator 操作者
     * @param from 发送者
     * @param tokenId 代币ID
     * @param data 附加数据
     * @return bytes4 接口选择器
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}