import { SimpleMerkleTree } from "@ericnordelo/strk-merkle-tree";
import { hash } from "starknet";
import fs from "fs";

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

getMerkleRoot();