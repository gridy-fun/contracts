import { Contract } from "starknet";
import { getAccount,  getContracts, Layer } from "./utils";
import { getMerkleProof } from "./getMerkleProof";
import assert from "assert";


async function claim() {
    const acc = getAccount(Layer.L2);
    const claim = getContracts().contracts.Claim;

    const cls = await acc.getClassAt(claim);
    const claimContract = new Contract(cls.abi, claim, acc);

    let { v, p } = await getMerkleProof('0x541bfd168a64acb7fc3331bec8226e672c786ed76f4585229941a95b9d4a60b');
    const call = claimContract.populate('claim', [p, v[0], v[1]]);
    const tx = await acc.execute(call);
    let receipt = await acc.waitForTransaction(tx.transaction_hash);
    assert(receipt.isSuccess(), 'Claim failed');
    console.log(receipt);
}

claim();
