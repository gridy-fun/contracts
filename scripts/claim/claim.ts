import { Contract, hash } from "starknet";
import { getAccount,  getContracts, Layer } from "../utils";
import assert from "assert";

import { SimpleMerkleTree } from "@ericnordelo/strk-merkle-tree";
import fs from "fs";
import readline from "readline";

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});


export function formatValuesFromLeaderboard(leaderboard: any[]) {
  return leaderboard.map((player) => [player.player, Math.floor(player.score * 10 ** 6)]);
}

export function calculateLeafHash(address: string, amount: string) {
  const hashValue = hash.computePedersenHash(0, hash.computeHashOnElements([address, amount]));
  // Ensure the hex value has an even length
  if (hashValue.startsWith('0x')) {
    const hexPart = hashValue.substring(2);
    return hexPart.length % 2 === 0 ? hashValue : `0x0${hexPart}`;
  } else {
    return hashValue.length % 2 === 0 ? hashValue : `0${hashValue}`;
  }
}

export async function getMerkleRoot(): Promise<string> {
  const leaderboard = JSON.parse(fs.readFileSync("leaderboard-l2.json", "utf8"));
  const values = formatValuesFromLeaderboard(leaderboard);
  const leaves = values.map((value) => calculateLeafHash(value[0], value[1]));

  const tree = SimpleMerkleTree.of(leaves);
  console.log('Merkle Root:', tree.root);
  fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));
  return tree.root;
}


export async function getMerkleProof(address: string): Promise<{ v: any[], p: string[] }> {
  const tree = SimpleMerkleTree.load(JSON.parse(fs.readFileSync("tree.json", "utf8")));
  const leaderboard = JSON.parse(fs.readFileSync("leaderboard-l2.json", "utf8"));
  const values = formatValuesFromLeaderboard(leaderboard);

  for (const [i, v] of tree.entries()) {
    const [addr, amount] = values[i];
    if (addr === address) {
      const proof = tree.getProof(i);
      console.log('Value:', [addr, amount]);
      console.log('Proof:', proof);

      const leafHash = calculateLeafHash(addr, amount);
      console.log("Leaf Hash:", leafHash);

      const isVerified = tree.verify(i, proof);
      console.log('Is verified:', isVerified);

      return { v: [addr, amount], p: proof };
    }
  }

  throw new Error('Address not found');
}

export async function getMerkleProofQue() {
  rl.question('Enter address to get proof for: ', async (address) => {
    const { v, p } = await getMerkleProof(address);
    rl.close();
    return { v: v, p: p };
  });
}

async function claim() {
    const acc = getAccount(Layer.L2);
    const claim = getContracts().contracts.Claim;

    const cls = await acc.getClassAt(claim);
    const claimContract = new Contract(cls.abi, claim, acc);

    // Change the address below for which you want to claim
    let { v, p } = await getMerkleProof('0x541bfd168a64acb7fc3331bec8226e672c786ed76f4585229941a95b9d4a60b');
    const verified = await claimContract.call('verify', [p, v[0], v[1]]);
    if (verified) {
        const claimCall = claimContract.populate('claim', [p, v[0], v[1]]);
        const tx = await acc.execute(claimCall);
        let receipt = await acc.waitForTransaction(tx.transaction_hash);
        assert(receipt.isSuccess(), 'Claim failed');
        console.log(receipt);
    }
}