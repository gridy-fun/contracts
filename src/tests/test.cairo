use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use gridy::interface::{
    IGameContractDispatcher, IGameContractDispatcherTrait
};
use starknet::ContractAddress;

fn deploy_contract() -> ContractAddress {
    let contract = declare("GameContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}

#[test]
fn check_contract_enabled() {
    // First declare and deploy a contract
    let game_contract_address = deploy_contract();
    let dispatcher = IGameContractDispatcher { contract_address: game_contract_address };

    dispatcher.enable_contract();

    // check storage of the contract
    let bot = dispatcher.is_contract_enabled();
    assert(bot == true, 'contract is disabled'); 
}

#[test]
fn check_deploy_bot() {
    // First declare and deploy a contract
    let game_contract_address = deploy_contract();
    let dispatcher = IGameContractDispatcher { contract_address: game_contract_address };

    dispatcher.enable_contract();
    let player : ContractAddress = 0x2d55d6f311413945595788818d4e89e151360a2c2c6b5270d5d0ed16475505f.try_into().unwrap();
    let block_id : felt252 = 234234234324;
    dispatcher.deploy_bot(player, block_id);
}