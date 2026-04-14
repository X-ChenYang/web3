// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "./VotingToken.sol";
import "./BankV2.sol";

/**
 * @title Governance
 * @dev 治理合约，用于管理Bank合约的资金使用
 */
contract Governance is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction {
    BankV2 public bank;

    /**
     * @dev 构造函数，初始化治理合约
     * @param _token 投票代币合约
     * @param _bank BankV2合约实例
     */
    constructor(VotingToken _token, BankV2 _bank) 
        Governor("Governance")
        GovernorSettings(1 /* 1 block */, 45818 /* 1 week */, 0)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4)
    {
        bank = _bank;
    }

    /**
     * @dev 返回投票延迟（区块数）
     * @return 投票延迟的区块数
     */
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    /**
     * @dev 返回投票期长度（区块数）
     * @return 投票期的区块数
     */
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    /**
     * @dev 返回指定区块高度的法定人数要求
     * @param blockNumber 区块高度
     * @return 法定人数要求的投票数量
     */
    function quorum(uint256 blockNumber) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    /**
     * @dev 返回提案的当前状态
     * @param proposalId 提案ID
     * @return 提案的当前状态
     */
    function state(uint256 proposalId) public view override(Governor) returns (ProposalState) {
        return super.state(proposalId);
    }

    /**
     * @dev 发起新的提案
     * @param targets 目标合约地址数组
     * @param values 每个目标的ETH值数组
     * @param calldatas 每个目标的调用数据数组
     * @param description 提案描述
     * @return 提案ID
     */
    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public override(Governor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    /**
     * @dev 返回提案阈值
     * @return 提案阈值
     */
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    /**
     * @dev 取消提案
     * @param targets 目标合约地址数组
     * @param values 每个目标的ETH值数组
     * @param calldatas 每个目标的调用数据数组
     * @param descriptionHash 提案描述的哈希值
     * @return 取消的提案ID
     */
    function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) internal override(Governor) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /**
     * @dev 返回执行提案的地址
     * @return 执行提案的地址
     */
    function _executor() internal view override(Governor) returns (address) {
        return super._executor();
    }

    /**
     * @dev 检查合约是否支持指定的接口
     * @param interfaceId 接口ID
     * @return 是否支持该接口
     */
    function supportsInterface(bytes4 interfaceId) public view override(Governor) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev 发起从Bank提取资金的提案
     * @param to 接收资金的地址
     * @param amount 提取的金额
     * @param description 提案描述
     * @return 提案ID
     */
    function proposeWithdraw(address to, uint256 amount, string memory description) external returns (uint256) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("withdraw(address,uint256)", to, amount);

        return propose(targets, values, calldatas, description);
    }
}