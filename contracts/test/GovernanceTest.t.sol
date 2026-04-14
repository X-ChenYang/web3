// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/VotingToken.sol";
import "../src/BankV2.sol";
import "../src/Governance.sol";

/**
 * @title GovernanceTest
 * @dev 测试治理合约的功能
 */
contract GovernanceTest is Test {
    VotingToken public votingToken;
    BankV2 public bank;
    Governance public governance;
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    uint256 public constant PROPOSAL_DELAY = 1;
    uint256 public constant PROPOSAL_PERIOD = 45818;

    /**
     * @dev 测试设置
     */
    function setUp() public {
        owner = address(0x1);
        user1 = address(0x2);
        user2 = address(0x3);
        user3 = address(0x4);

        // 为账户分配ETH
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);

        // 部署VotingToken
        vm.startPrank(owner);
        votingToken = new VotingToken(owner);
        
        // 部署BankV2
        bank = new BankV2(owner);
        
        // 部署Governance
        governance = new Governance(votingToken, bank);
        
        // 将BankV2合约的所有权转移给治理合约
        bank.transferOwnership(address(governance));
        
        // 分配投票代币
        votingToken.transfer(user1, 300000 * 10 ** 18);
        votingToken.transfer(user2, 300000 * 10 ** 18);
        votingToken.transfer(user3, 300000 * 10 ** 18);
        
        // 为Bank合约存款
        bank.deposit{value: 50 ether}();
        vm.stopPrank();

        // 委托投票权
        vm.startPrank(user1);
        votingToken.delegate(user1);
        vm.stopPrank();

        vm.startPrank(user2);
        votingToken.delegate(user2);
        vm.stopPrank();

        vm.startPrank(user3);
        votingToken.delegate(user3);
        vm.stopPrank();
    }

    /**
     * @dev 测试治理流程
     */
    function testGovernanceProcess() public {
        // 发起提取资金的提案
        vm.startPrank(user1);
        uint256 proposalId = governance.proposeWithdraw(user1, 10 ether, "Withdraw 10 ETH to user1");
        vm.stopPrank();

        // 跳过投票延迟
        vm.roll(block.number + PROPOSAL_DELAY + 1);

        // 进行投票
        vm.startPrank(user1);
        governance.castVote(proposalId, 1); // 赞成
        vm.stopPrank();

        vm.startPrank(user2);
        governance.castVote(proposalId, 1); // 赞成
        vm.stopPrank();

        vm.startPrank(user3);
        governance.castVote(proposalId, 0); // 反对
        vm.stopPrank();

        // 跳过投票期
        vm.roll(block.number + PROPOSAL_PERIOD);

        // 执行提案
        vm.startPrank(user1);
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("withdraw(address,uint256)", user1, 10 ether);
        
        governance.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes("Withdraw 10 ETH to user1"))
        );
        vm.stopPrank();

        // 验证结果
        emit log_string("=== After Execution ===");
        emit log_named_uint("User1 ETH Balance (ETH)", address(user1).balance / 1 ether);
        emit log_named_uint("Bank Balance (ETH)", bank.getBalance() / 1 ether);
        assertEq(address(user1).balance, 100 ether + 10 ether);
        assertEq(bank.getBalance(), 50 ether - 10 ether);
    }

    /**
     * @dev 测试Bank合约存款功能
     */
    function testBankDeposit() public {
        vm.startPrank(user1);
        uint256 initialBalance = bank.getBalance();
        emit log_string("=== Before Deposit ===");
        emit log_named_uint("Bank Balance (ETH)", initialBalance / 1 ether);
        bank.deposit{value: 5 ether}();
        emit log_string("=== After Deposit ===");
        emit log_named_uint("Bank Balance (ETH)", bank.getBalance() / 1 ether);
        emit log_named_uint("user1 Balance (ETH)", address(user1).balance / 1 ether);
        assertEq(bank.getBalance(), initialBalance + 5 ether);
        vm.stopPrank();
    }

    /**
     * @dev 测试投票代币功能
     */
    function testVotingToken() public {
        emit log_string("=== sss Deposit ===");
        emit log_named_uint("user1 Balance (ETH)", votingToken.balanceOf(user1)/ 1 ether);
        emit log_named_uint("user2 Balance (ETH)", votingToken.balanceOf(user2)/ 1 ether);
        emit log_named_uint("user3 Balance (ETH)", votingToken.balanceOf(user3) / 1 ether);
        assertEq(votingToken.balanceOf(user1), 300000 * 10 ** 18);
        assertEq(votingToken.balanceOf(user2), 300000 * 10 ** 18);
        assertEq(votingToken.balanceOf(user3), 300000 * 10 ** 18);
    }

    /**
     * @dev 测试提案状态变化
     */
    function testProposalState() public {
        // 发起提案
        vm.startPrank(user1);
        uint256 proposalId = governance.proposeWithdraw(user1, 10 ether, "Withdraw 10 ETH to user1");
        vm.stopPrank();

        // 验证提案状态为Pending
        emit log_named_uint("governance Pending ", uint256(governance.state(proposalId)));
        assertEq(uint256(governance.state(proposalId)), 0);

        // 跳过投票延迟
        
        vm.roll(block.number + PROPOSAL_DELAY + 1);
        emit log_named_uint("governance Active ", uint256(governance.state(proposalId)));
        // 验证提案状态为Active
        assertEq(uint256(governance.state(proposalId)), 1);

        // 进行投票
        vm.startPrank(user1);
        governance.castVote(proposalId, 1);
        vm.stopPrank();

        // 跳过投票期
        vm.roll(block.number + PROPOSAL_PERIOD);

        // 验证提案状态为Succeeded
        emit log_named_uint("governance Succeeded ", uint256(governance.state(proposalId)));
        assertEq(uint256(governance.state(proposalId)), 4);
    }
}