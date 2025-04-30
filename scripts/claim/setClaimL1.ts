import { getEthereumClient } from "../utils";
import fs from "fs";
import { abi } from "../../abi/claim";
import { mainnet } from "viem/chains";

import { createPublicClient, http } from 'viem'
import { privateKeyToAccount } from "viem/accounts";
 
export const publicClient = createPublicClient({
  chain: mainnet,
  transport: http()
})

function getLeaderboard(): { score: bigint[], player: `0x${string}`[] } {
    const leaderboard = JSON.parse(fs.readFileSync("leaderboard-l1.json", "utf8"));
    return {
        score: leaderboard.map((player: any) => Math.floor(player.score * 10 ** 6)),
        player: leaderboard.map((player: any) => player.player)
    }
}

async function setClaimL1() {
    const acc = getEthereumClient();
    const { score, player } = getLeaderboard();
    const account = privateKeyToAccount(`0x${process.env.ACCOUNT_L1_PRIVATE_KEY}`)
    const { request } = await publicClient.simulateContract({
        address: '0xcD2eC1540cEB8f8191166A6E295fB7cBA49577dC',
        abi: abi,
        functionName: 'setClaims',
        args: [score, player],
        account: account
    })
    console.log(request);
    const tx = await acc.writeContract(request)
    console.log(tx);
}

setClaimL1();
