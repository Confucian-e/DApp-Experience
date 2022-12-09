const { ethers } = require("ethers");
const { parseUnits } = require("ethers/lib/utils");
const fs = require('fs');

const ALCHEMY_KEY = "";         // 你自己的KEY
const private_key = "";         // 你自己的私钥
const accountlist = fs.readFileSync('./dapp.json', 'utf-8');
const account = JSON.parse(accountlist);

async function main() {
    const provider = await new ethers.providers.AlchemyProvider("maticmum", ALCHEMY_KEY);
    const wallet = await new ethers.Wallet(private_key, provider);

    const abi = await JSON.parse(fs.readFileSync('./abi.json'));
    const bytecode = await JSON.parse(fs.readFileSync('./bytecode.json'));

    const MyToken_factory = await new ethers.ContractFactory(abi, bytecode, wallet);

    const MyToken = await MyToken_factory.deploy();

    const contract_address = await MyToken.address;

    console.log(`The contract address is ${contract_address}`);

    /**
     * 部署 ERC20 合约完成
     * 下面开始转账
    */

    await(async () => {
        for (let index = 0; index < account.length; index++) {
            const receiver = account[index].address;
            const tx = await MyToken.transfer(receiver, parseUnits('201'));
            const tx_hash = tx.hash;

            console.log(`tx ${index} succeed, the tx hash is ${tx_hash}`);
        }
    })();
    
}

main();