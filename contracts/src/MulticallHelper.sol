// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MulticallHelper
 * @dev Multicall封装合约，用于一次性调用多个方法
 * @notice 本合约提供了多种批量调用函数的方法，支持不同类型的返回值
 */
contract MulticallHelper {
    
    /**
     * @dev Call结构体
     * @param target 目标合约地址
     * @param data 调用数据
     */
    struct Call {
        address target;
        bytes data;
    }
    
    /**
     * @dev Result结构体
     * @param success 调用是否成功
     * @param data 调用返回数据
     */
    struct Result {
        bool success;
        bytes data;
    }
    
    /**
     * @dev 批量调用函数（使用call）
     * @param calls 调用数组
     * @return results 调用结果数组
     */
    function multicall(Call[] calldata calls) external returns (Result[] memory results) {
        results = new Result[](calls.length);
        
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory data) = calls[i].target.call(calls[i].data);
            results[i] = Result(success, data);
        }
    }
    
    /**
     * @dev 批量调用函数（使用delegatecall，返回解码后的uint256结果）
     * @param calls 调用数组
     * @return results 调用结果数组
     */
    function multicallUint256(Call[] calldata calls) external returns (uint256[] memory results) {
        results = new uint256[](calls.length);
        
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory data) = calls[i].target.delegatecall(calls[i].data);
            require(success, "Call failed");
            
            if (data.length > 0) {
                results[i] = abi.decode(data, (uint256));
            } else {
                results[i] = 0;
            }
        }
    }
    
    /**
     * @dev 批量调用函数（使用delegatecall，返回解码后的bool结果）
     * @param calls 调用数组
     * @return results 调用结果数组
     */
    function multicallBool(Call[] calldata calls) external returns (bool[] memory results) {
        results = new bool[](calls.length);
        
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory data) = calls[i].target.delegatecall(calls[i].data);
            require(success, "Call failed");
            
            if (data.length > 0) {
                results[i] = abi.decode(data, (bool));
            } else {
                results[i] = false;
            }
        }
    }
    
    /**
     * @dev 批量调用函数（使用delegatecall，返回解码后的address结果）
     * @param calls 调用数组
     * @return results 调用结果数组
     */
    function multicallAddress(Call[] calldata calls) external returns (address[] memory results) {
        results = new address[](calls.length);
        
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory data) = calls[i].target.delegatecall(calls[i].data);
            require(success, "Call failed");
            
            if (data.length > 0) {
                results[i] = abi.decode(data, (address));
            } else {
                results[i] = address(0);
            }
        }
    }
    
    /**
     * @dev 批量调用函数（使用delegatecall，返回解码后的bytes32结果）
     * @param calls 调用数组
     * @return results 调用结果数组
     */
    function multicallBytes32(Call[] calldata calls) external returns (bytes32[] memory results) {
        results = new bytes32[](calls.length);
        
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory data) = calls[i].target.delegatecall(calls[i].data);
            require(success, "Call failed");
            
            if (data.length > 0) {
                results[i] = abi.decode(data, (bytes32));
            } else {
                results[i] = bytes32(0);
            }
        }
    }
    
    /**
     * @dev 批量调用函数（使用delegatecall，返回解码后的uint256[]结果）
     * @param calls 调用数组
     * @return results 调用结果数组
     */
    function multicallUint256Array(Call[] calldata calls) external returns (uint256[][] memory results) {
        results = new uint256[][](calls.length);
        
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory data) = calls[i].target.delegatecall(calls[i].data);
            require(success, "Call failed");
            
            if (data.length > 0) {
                results[i] = abi.decode(data, (uint256[]));
            } else {
                results[i] = new uint256[](0);
            }
        }
    }
}