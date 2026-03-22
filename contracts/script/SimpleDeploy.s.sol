// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyToken.sol";

contract SimpleDeploy is Script {
    function run() external {
        // 使用默认账户部署
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        vm.startBroadcast(deployerPrivateKey);
        
        MyToken token = new MyToken("MyToken", "MTK", 18, 1000000);
        
        console.log("Token deployed at:", address(token));
        console.log("Deployer address:", vm.addr(deployerPrivateKey));
        
        // 模拟一些转账
        address recipient1 = address(0x1234567890123456789012345678901234567890);
        address recipient2 = address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD);
        address recipient3 = address(0x1111111111111111111111111111111111111111);
        
        token.transfer(recipient1, 1000 * 10**18);
        console.log("Transfer 1: to", recipient1, "amount 1000");
        
        token.transfer(recipient2, 2000 * 10**18);
        console.log("Transfer 2: to", recipient2, "amount 2000");
        
        token.transfer(recipient3, 3000 * 10**18);
        console.log("Transfer 3: to", recipient3, "amount 3000");
        
        token.transfer(recipient1, 500 * 10**18);
        console.log("Transfer 4: to", recipient1, "amount 500");
        
        token.transfer(recipient2, 1500 * 10**18);
        console.log("Transfer 5: to", recipient2, "amount 1500");
        
        vm.stopBroadcast();
        
        console.log("Token address:", address(token));
    }
}
