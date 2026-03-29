// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ChainBank {
    // 存储每个地址的存款金额
    mapping(address => uint256) public balances;
    
    // 定义用户节点结构
    struct UserNode {
        address user;
        uint256 balance;
        uint256 next;
        uint256 prev;
    }
    
    // 存储用户节点
    mapping(uint256 => UserNode) public userNodes;
    
    // 链表相关变量
    uint256 public head;
    uint256 public tail;
    uint256 public nodeCount;
    uint256 public constant MAX_TOP_USERS = 10;
    
    // 存款事件
    event Deposit(address indexed user, uint256 amount, uint256 newBalance);
    
    // 接收ETH存款
    receive() external payable {
        deposit();
    }
    
    // 回退函数，处理没有数据的调用
    fallback() external payable {
        deposit();
    }
    
    // 存款函数
    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        // 更新用户余额
        balances[msg.sender] += msg.value;
        uint256 newBalance = balances[msg.sender];
        
        // 更新前10名用户链表
        updateTopUsers(msg.sender, newBalance);
        
        // 触发存款事件
        emit Deposit(msg.sender, msg.value, newBalance);
    }
    
    // 更新前10名用户链表
    function updateTopUsers(address user, uint256 balance) internal {
        // 检查用户是否已经在链表中
        bool inList = false;
        uint256 current = head;
        
        while (current != 0) {
            if (userNodes[current].user == user) {
                inList = true;
                break;
            }
            current = userNodes[current].next;
        }
        
        if (inList) {
            // 用户已在链表中，更新余额并重新排序
            updateExistingUser(current, balance);
        } else {
            // 用户不在链表中，添加新节点
            addNewUser(user, balance);
        }
    }
    
    // 更新已存在用户的余额并重新排序
    function updateExistingUser(uint256 nodeId, uint256 newBalance) internal {
        // 保存节点数据
        address user = userNodes[nodeId].user;
        
        // 更新余额
        userNodes[nodeId].balance = newBalance;
        
        // 从链表中移除节点
        removeNode(nodeId);
        
        // 恢复节点数据
        userNodes[nodeId] = UserNode(user, newBalance, 0, 0);
        
        // 重新插入节点到正确位置
        insertNode(nodeId);
    }
    
    // 添加新用户到链表
    function addNewUser(address user, uint256 balance) internal {
        // 如果链表已满且新用户余额小于等于尾节点余额，则不添加
        if (nodeCount >= MAX_TOP_USERS) {
            if (balance <= userNodes[tail].balance) {
                return;
            }
            // 移除尾节点
            removeNode(tail);
        }
        
        // 创建新节点
        uint256 newNodeId = nodeCount + 1;
        userNodes[newNodeId] = UserNode(user, balance, 0, 0);
        nodeCount++;
        
        // 插入节点到正确位置
        insertNode(newNodeId);
    }
    
    // 从链表中移除节点
    function removeNode(uint256 nodeId) internal {
        UserNode storage node = userNodes[nodeId];
        
        if (node.prev == 0) {
            // 移除头节点
            head = node.next;
            if (head != 0) {
                userNodes[head].prev = 0;
            }
        } else if (node.next == 0) {
            // 移除尾节点
            tail = node.prev;
            if (tail != 0) {
                userNodes[tail].next = 0;
            }
        } else {
            // 移除中间节点
            userNodes[node.prev].next = node.next;
            userNodes[node.next].prev = node.prev;
        }
        
        // 清空节点数据
        delete userNodes[nodeId];
        nodeCount--; // 添加这一行
    }
    
    // 插入节点到正确位置（按余额降序）
    function insertNode(uint256 nodeId) internal {
        UserNode storage newNode = userNodes[nodeId];
        
        if (head == 0) {
            // 链表为空，设置为头和尾
            head = nodeId;
            tail = nodeId;
            return;
        }
        
        // 找到插入位置
        uint256 current = head;
        while (current != 0 && userNodes[current].balance > newNode.balance) {
            current = userNodes[current].next;
        }
        
        if (current == 0) {
            // 插入到尾部
            userNodes[tail].next = nodeId;
            newNode.prev = tail;
            tail = nodeId;
        } else if (current == head) {
            // 插入到头部
            newNode.next = head;
            userNodes[head].prev = nodeId;
            head = nodeId;
        } else {
            // 插入到中间
            newNode.next = current;
            newNode.prev = userNodes[current].prev;
            userNodes[userNodes[current].prev].next = nodeId;
            userNodes[current].prev = nodeId;
        }
    }
    
    // 获取前10名用户
    function getTopUsers() public view returns (address[] memory, uint256[] memory) {
        address[] memory users = new address[](nodeCount);
        uint256[] memory balances = new uint256[](nodeCount);
        
        uint256 current = head;
        uint256 index = 0;
        
        while (current != 0 && index < MAX_TOP_USERS) {
            users[index] = userNodes[current].user;
            balances[index] = userNodes[current].balance;
            current = userNodes[current].next;
            index++;
        }
        
        return (users, balances);
    }
    
    // 获取指定用户的余额
    function getBalance(address user) public view returns (uint256) {
        return balances[user];
    }
    
    // 获取合约总存款
    function getTotalDeposits() public view returns (uint256) {
        return address(this).balance;
    }
}