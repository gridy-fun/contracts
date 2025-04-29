import { deployContract, Layer, getAccount, declareContract, getContracts } from "../utils";
import { getMerkleRoot } from "./claim";

export async function deployClaim() {
    const acc = getAccount(Layer.L2);
    const tx = await declareContract("Claim", "gridy", Layer.L2, "./target/dev");
    if (!tx) {
        throw new Error("Failed to declare contract");
    }
    const merkleRoot = await getMerkleRoot();
    const token = getContracts().contracts.USDC;
    await deployContract("Claim", tx.class_hash, [token, acc.address, merkleRoot], Layer.L2);
}


deployClaim();