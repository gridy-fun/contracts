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
    dispatcher.deploy_bot(player);

    // check storage of the contract
    let bot = dispatcher.get_bot(player);
    assert(bot == 1, 'bot is not deployed');
}

#[test]
fn check_bot_for_address() {
    // First declare and deploy a contract
    let game_contract_address = deploy_contract();
    let dispatcher = IGameContractDispatcher { contract_address: game_contract_address };

    // enable contract
    dispatcher.enable_contract();
    
    // deploy bot with true player
    let true_player : ContractAddress = 0x2d55d6f311413945595788818d4e89e151360a2c2c6b5270d5d0ed16475505f.try_into().unwrap();
    dispatcher.deploy_bot(true_player);

    // add a false player address
    let false_player: ContractAddress =0x2d55d6f311413945595788818d4e89e151360a2c2c6b5270d5d0ed16475505a.try_into().unwrap();

    // check storage of the contract
    let bot = dispatcher.get_bot(false_player);
    assert(bot == 0, 'bot is not deployed');
}