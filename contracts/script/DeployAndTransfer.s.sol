// SPDX-License-Identifier: MIT
// 许可证声明：MIT 开源许可证
pragma solidity ^0.8.20;  // Solidity 版本：0.8.20 及以上

// 导入 Foundry 的测试脚本库
import "forge-std/Script.sol";
// 导入我们创建的 MyToken 合约
import "../src/MyToken.sol";

// 部署和转账脚本合约
contract DeployAndTransfer is Script {
    // 主函数：部署合约并执行转账
    function run() external {
        // 从环境变量中读取部署者的私钥
        // 环境变量需要在 .env 文件中配置
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 根据私钥计算部署者地址
        address deployer = vm.addr(deployerPrivateKey);
        
        // 开始广播交易：从这里开始的所有操作都会发送到区块链
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署 MyToken 合约
        // 参数：
        //   "MyToken" - 代币名称
        //   "MTK" - 代币符号
        //   18 - 小数位数（标准为 18）
        //   1000000 - 初始供应量（实际为 1000000 * 10^18）
        MyToken token = new MyToken("MyToken", "MTK", 18, 1000000);
        
        // 输出部署信息到控制台
        console.log("Token deployed at:", address(token));  // 合约地址
        console.log("Deployer address:", deployer);  // 部署者地址
        
        // 模拟三个接收地址（用于测试转账）
        address recipient1 = address(0x1234567890123456789012345678901234567890);
        address recipient2 = address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD);
        address recipient3 = address(0x1111111111111111111111111111111111111111);
        
        // 第一笔转账: 给 recipient1 转账 1000 MTK
        // 10**18 是因为代币有 18 位小数
        uint256 amount1 = 1000 * 10**18;
        token.transfer(recipient1, amount1);
        console.log("Transfer 1: to", recipient1, "amount", amount1);
        
        // 第二笔转账: 给 recipient2 转账 2000 MTK
        uint256 amount2 = 2000 * 10**18;
        token.transfer(recipient2, amount2);
        console.log("Transfer 2: to", recipient2, "amount", amount2);
        
        // 第三笔转账: 给 recipient3 转账 3000 MTK
        uint256 amount3 = 3000 * 10**18;
        token.transfer(recipient3, amount3);
        console.log("Transfer 3: to", recipient3, "amount", amount3);
        
        // 第四笔转账: 给 recipient1 再转账 500 MTK
        uint256 amount4 = 500 * 10**18;
        token.transfer(recipient1, amount4);
        console.log("Transfer 4: to", recipient1, "amount", amount4);
        
        // 第五笔转账: 给 recipient2 再转账 1500 MTK
        uint256 amount5 = 1500 * 10**18;
        token.transfer(recipient2, amount5);
        console.log("Transfer 5: to", recipient2, "amount", amount5);
        
        // 停止广播交易
        vm.stopBroadcast();
        
        // 输出合约地址，方便后续使用
        console.log("Token address:", address(token));
        console.log("Please save this address for backend configuration");
    }
}
