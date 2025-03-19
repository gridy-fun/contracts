import * as dotenv from "dotenv";
dotenv.config();

import { deployContract, getAccount, declareContract, getContracts, getProvider, Layer, getEthereumClient } from "./utils";
import {
  Account, Contract, num
} from 'starknet';

import { parseAbi, parseEther, WalletClient } from "viem";
import { sepolia } from "viem/chains";
import { Account as EthAccount } from "viem";

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function checkClass(acc_l3: Account) {
  // // Locally calculated class hash after building the contract
  // const compiledSierra = json.parse(
  //   readFileSync(`./starkgate-contracts/cairo_contracts/starkgate_contracts_TokenBridge.contract_class.json`).toString("ascii")
  // )
  // let calculated_class_hash = hash.computeContractClassHash(compiledSierra);
  // // Class hash saved in the contracts.json file
  // let local_class_hash = getContracts().class_hashes["TokenBridge_starkgate_contracts"];
  //
  // // Class hash of the deployed contract
  // let appchainBridge = getContracts().contracts["TokenBridge_starkgate_contracts"];
  // let class_hash = await acc_l3.getClassHashAt(appchainBridge);
  //
  //
  // console.log("class_hash of contract: ", class_hash);
  // console.log("class_hash_local: ", calculated_class_hash);
  // console.log("class_hash_saved: ", local_class_hash);


  let l3Registry = getContracts().contracts["L3Registry"];
  let cls = await acc_l3.getClassAt(l3Registry);
  let l3RegistryContract = new Contract(cls.abi, l3Registry, acc_l3);

  let on_receive_call = l3RegistryContract.populate('on_receive', [
    "0xc811e776b41e5bb5e80e992d64c4ac1eb52c5a16c32d1882b1341b9344186c",
    1,
    "0x05bcf773a0bb4e867826f47aabacb6c6371cfbb76cc29e82c33e91cc3b3e0b42",
    []
  ]);

  let result = await acc_l3.execute([on_receive_call]);
  console.log("on_receive_call: ", result);
}

async function getAppchainBridge() {
  const gridTokenAddress = getContracts().contracts["ERC20_starknet_bridge"];
  const tokenBridge = getContracts().contracts["TokenBridge_starknet_bridge"];

  const provider = getProvider(Layer.L2);
  const cls = await provider.getClassAt(tokenBridge);
  const tokenBridgeContract = new Contract(cls.abi, tokenBridge, provider);


  const call = await tokenBridgeContract.call('appchain_bridge');
  if (typeof call === 'bigint') {
    console.log("Appchain bridge on TokenBridge is: ", call, num.toHex(call));
  }
}

async function deployTestingContract() {
  await declareContract("TestingContract", "starknet_bridge", Layer.L2);
  console.log("Testing contract declared !!");
  await sleep(1000);
  const class_hash = await getContracts().class_hashes["TestingContract_starknet_bridge"];
  const contract = await deployContract("TestingContract_starknet_bridge", class_hash, [], Layer.L2);
  console.log("Testing Contract deployed at: ", contract.address);
}

async function declareAndUpgradeL2Bridge(acc_l2: Account) {
  await declareContract("TokenBridge", "starknet_bridge", Layer.L2);
  console.log("TokenBridge declared !!");
  await sleep(1000);
  const tokenBridge = getContracts().contracts["TokenBridge_starknet_bridge"];
  const cls = await acc_l2.getClassAt(tokenBridge);
  let tokenBridgeContract = new Contract(cls.abi, tokenBridge, acc_l2);
  const upgradeCall = tokenBridgeContract.populate('upgrade', {
    new_class_hash: getContracts().class_hashes["TokenBridge_starknet_bridge"]
  });
  let result = await acc_l2.execute([upgradeCall]);
  console.log("Upgrade success !!", result);
  await sleep(5000);
  tokenBridgeContract = new Contract(getContracts().class_hashes["TokenBridge_starkgate_contracts"], tokenBridge, acc_l2);
  const messaging_contract = await tokenBridgeContract.call('get_messaging_contract');
  console.log("Messaging contract: ", num.toHex(messaging_contract as string));
  await sleep(1000);
}


async function declareAndUpgradeL3Bridge(acc_l3: Account) {
  await declareContract("TokenBridge", "starkgate_contracts", Layer.L3);
  console.log("TokenBridge declared !!");
  await sleep(1000);
  const tokenBridge = getContracts().contracts["TokenBridge_starknet_bridge"];
  const cls = await acc_l3.getClassAt(tokenBridge);
  let tokenBridgeContract = new Contract(cls.abi, tokenBridge, acc_l3);
  const upgradeCall = tokenBridgeContract.populate('upgrade', {
    new_class_hash: getContracts().class_hashes["TokenBridge_starknet_bridge"]
  });
  let result = await acc_l3.execute([upgradeCall]);
  console.log("Upgrade success !!", result);
  await sleep(5000);
  tokenBridgeContract = new Contract(getContracts().class_hashes["TokenBridge_starkgate_contracts"], tokenBridge, acc_l3);
  const messaging_contract = await tokenBridgeContract.call('get_messaging_contract');
  console.log("Messaging contract: ", num.toHex(messaging_contract as string));
  await sleep(1000);
}

async function depositWithMessageL1toL3(acc_l1: WalletClient, token: string = "MyL1GameToken") {
  const l1GameToken = "0x2196d41378b9332682aAB47C5e5aE342b4429060";
  const tokenBridge = "0xF6217de888fD6E6b2CbFBB2370973BE4c36a152D";


  // Approval
  {

    const tokenAbi = parseAbi([
      'function approve(address spender, uint256 amount) returns (bool)',
    ])

    const approveTx = await acc_l1.writeContract({
      address: l1GameToken,
      abi: tokenAbi,
      functionName: 'approve',
      args: [tokenBridge, 10n ** 15n],
      chain: sepolia,
      account: acc_l1.account as EthAccount
    });

    console.log('Approval transaction hash:', approveTx);
    await sleep(2000);
  }


  // Deposit
  {
    // const l2Registry = getContracts().contracts["L2Registry"];
    // const l2GameToken = getContracts().contracts["MyL2GameToken"];
    // const l3Registry = getContracts().contracts["L3Registry"];
    // const player = process.env.ACCOUNT_L2_ADDRESS as string;
    //
    // const depositWithMessageAbi = parseAbi([
    //   'function depositWithMessage(address token, uint256 amount, uint256 l2Recipient, uint256[] memory message) external payable',
    // ]);

    // const depositWithMessageAbi = parseAbi([
    //   'function depositWithMessage(address token, uint256 amount, uint256 l2Recipient, uint256[] memory message) external payable',
    // ]);
    // function depositWithMessage(
    //   address token,
    //   uint256 amount,
    //   uint256 l2Recipient,
    //   uint256[] calldata message
    // ) external payable onlyServicingToken(token)


    // const depositWithMessasgeTx = await acc_l1.writeContract({
    //   address: tokenBridge,
    //   abi: depositWithMessageAbi,
    //   functionName: 'depositWithMessage',
    //   args: [
    //     l1GameToken,  // l1 token
    //     10n ** 15n,   // amount
    //     l2Registry,   // l2Recipient
    //     [
    //       BigInt(player),
    //       15n
    //     ]
    //   ],
    //   value: parseEther('0.01'),
    //   account: acc_l1.account as EthAccount,
    //   chain: sepolia,
    // });

    const depositAbi = parseAbi([
      "function deposit(address token, uint256 amount, uint256 l2Recipient) external payable",
    ]);

    const depositTx = await acc_l1.writeContract({
      address: tokenBridge,
      abi: depositAbi,
      functionName: "deposit",
      args: [l1GameToken, 1n ** 15n, BigInt("0x0463A5a7D814c754E6C3c10f9De8024B2bdF20eb56aD5168076636A858402D7e")],
      value: parseEther("0.01"),
      account: acc_l1.account as EthAccount, // Removed TypeScript casting
      chain: sepolia,
    });

    console.log("Deposit transaction hash:", depositTx);

  }
}


async function depositWithMessageL2toL3(acc_l2: Account) {
  const gridTokenAddress = getContracts().contracts["ERC20_starknet_bridge"];
  const tokenBridge = getContracts().contracts["TokenBridge_starknet_bridge"];



  // Approval
  {
    const gridCls = await acc_l2.getClassAt(gridTokenAddress);
    const gridToken = new Contract(gridCls.abi, gridTokenAddress, acc_l2);

    const call = gridToken.populate('approve', {
      spender: tokenBridge,
      amount: 12n * 10n ** 18n
    });
    let result = await acc_l2.execute([call]);
    console.log("Approval success !!", result);
  }
  await sleep(4000);



  // Deposit
  {
    const Bridgecls = await acc_l2.getClassAt(tokenBridge);
    const tokenBridgeContract = new Contract(Bridgecls.abi, tokenBridge, acc_l2);
    const l3Registry = getContracts().contracts["L3Registry"];

    const call = tokenBridgeContract.populate('deposit_with_message', {
      token: gridTokenAddress,
      amount: 11n * 10n ** 18n,
      appchain_recipient: l3Registry,
      message: [
        process.env.ACCOUNT_L2_ADDRESS as string, // Player in game
        4n // Initial location to mine
      ]
    });
    let result = await acc_l2.execute([call]);
    console.log("Deposit success !!", result);
    await sleep(10000);
  }
}

async function getGameState(acc_l3: Account) {
  const game = getContracts().contracts["Game"];
  const cls = await acc_l3.getClassAt(game);
  const gameContract = new Contract(cls.abi, game, acc_l3);

  const call = await gameContract.call('get_total_bots_of_player', [
    process.env.ACCOUNT_L2_ADDRESS as string
  ])
  console.log("Total bots of player: ", call);

  const botAddress = await gameContract.call('get_bot_of_player', [
    process.env.ACCOUNT_L2_ADDRESS as string,
    2
  ]);

  console.log("Bot address: ", num.toHex(botAddress as string));
}

function main() {
  let acc_l1 = getEthereumClient();
  depositWithMessageL1toL3(acc_l1, "MyL1GameToken");
}

main();
