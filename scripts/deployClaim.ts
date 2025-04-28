import { deployContract, Layer, getAccount, declareContract, getContracts } from "./utils";
import { getMerkleRoot } from "./getMerkleRoot";

export async function deployClaim() {
    const acc = getAccount(Layer.L3);
    const tx = await declareContract("Claim", "gridy", Layer.L2, "./target/dev");
    if (!tx) {
        throw new Error("Failed to declare contract");
    }
    const merkleRoot = await getMerkleRoot();
    const token = getContracts().contracts.MyL2GameToken;
    const claim = await deployContract("Claim", tx.class_hash, [token, acc.address, merkleRoot], Layer.L2);
}


deployClaim();