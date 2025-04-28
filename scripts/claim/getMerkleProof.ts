import { SimpleMerkleTree } from "@ericnordelo/strk-merkle-tree";
import fs from "fs";
import readline from "readline";
import { calculateLeafHash, formatValuesFromLeaderboard } from "./getMerkleRoot";

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});


export async function getMerkleProof(address: string): Promise<{ v: any[], p: string[] }> {
  const tree = SimpleMerkleTree.load(JSON.parse(fs.readFileSync("tree.json", "utf8")));
  const leaderboard = JSON.parse(fs.readFileSync("values.json", "utf8"));
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
