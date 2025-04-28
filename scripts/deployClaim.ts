import { deployContract, Layer, getAccount, declareContract } from "./utils";
import { getMerkleRoot } from "./getMerkleRoot";

export async function deployClaim() {
    const acc = getAccount(Layer.L3);
    const tx = await declareContract("Verifier", "gridy", Layer.L2, "./target/dev");
    if (!tx) {
        throw new Error("Failed to declare contract");
    }
    const merkleRoot = await getMerkleRoot();
    const claim = await deployContract("Verifier", tx.class_hash, [merkleRoot], Layer.L2);
}


deployClaim();