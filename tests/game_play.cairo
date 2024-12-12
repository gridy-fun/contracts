use snforge_std::{declare,ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, start_cheat_block_timestamp, start_cheat_block_number};
use gridy::{
    game::interface::{IGameContractDispatcher, IGameContractDispatcherTrait},
    bot::interface::{IBotContractDispatcher, IBotContractDispatcherTrait}
};
use starknet::{ContractAddress};
use gridy::constants::{
    player_id, block_id, grid_height, grid_width, bomb_value, mining_points
};


fn setup_user_account(pub_key: felt252) -> ContractAddress {
    let account = declare("SnakeAccountMock").unwrap().contract_class();
    let mut account_constructor_args = ArrayTrait::new();
    pub_key.serialize(ref account_constructor_args);
    let (account_contract_address, _) =  account.deploy(@account_constructor_args).unwrap();
    account_contract_address
}

fn deploy_contract() -> (ContractAddress, ContractAddress, ContractAddress) {
    // setup admin account
    let executor_address = setup_user_account('PUBKEY');

    // declare bot contract
    let bot_contract= declare("BotContract").unwrap().contract_class();

    // deploy game contract
    let game_contract = declare("GameContract").unwrap().contract_class();
    let mut game_contract_constructor_args = ArrayTrait::new();
    executor_address.serialize(ref game_contract_constructor_args);
    bot_contract.serialize(ref game_contract_constructor_args);
    bomb_value.serialize(ref game_contract_constructor_args);
    mining_points.serialize(ref game_contract_constructor_args);
    grid_width.serialize(ref game_contract_constructor_args);
    grid_height.serialize(ref game_contract_constructor_args);
    let (game_contract_address, _) = game_contract.deploy(@game_contract_constructor_args).unwrap();

    // deploy bot contract
    let mut bot_contract_constructor_args = ArrayTrait::new();
    let player_address : ContractAddress = player_id.try_into().unwrap();
    executor_address.serialize(ref bot_contract_constructor_args);
    player_address.serialize(ref bot_contract_constructor_args);
    game_contract_address.serialize(ref bot_contract_constructor_args);
    block_id.serialize(ref bot_contract_constructor_args);
    grid_height.serialize(ref bot_contract_constructor_args);
    grid_width.serialize(ref bot_contract_constructor_args);
    let (bot_contract_address, _) = bot_contract.deploy(@bot_contract_constructor_args).unwrap();

    (game_contract_address, bot_contract_address,executor_address)
}

#[test]
#[should_panic(expected: 'contract is disabled')]
fn check_game_contract_enabled_status() {
    let (game_contract_address, _,_) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let game = game_contract.is_contract_enabled();
    assert(game == true, 'contract is disabled');
}


#[test]
fn check_bot_contract_enabled_status() {
    let (_, bot_contract_address,_) = deploy_contract();
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };
    let bot = bot_contract.is_bot_alive();
    assert(bot == true, 'contract is disabled');
}
#[test]
fn check_game_bot_enabled() {
    // First declare and deploy a contract
    let (game_contract_address, bot_contract_address,executor_address) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    // owner operations 
    start_cheat_caller_address(game_contract_address,executor_address);
    game_contract.enable_contract();

    // check storage of the contract
    let bot = bot_contract.is_bot_alive();
    assert(bot == true, 'contract is disabled'); 
}

#[test]
fn mine_block() {
    // First declare and deploy a contract
    let (game_contract_address, bot_contract_address,executor_address) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    // owner operations 
    start_cheat_caller_address(game_contract_address, executor_address);
    start_cheat_caller_address(bot_contract_address, executor_address);

    game_contract.enable_contract();

    start_cheat_block_number(bot_contract_address, 0x420_u64);
    start_cheat_block_timestamp(bot_contract_address, 0x2137_u64);

    // add seed value 
    let seed = 0x7b; // 123

    game_contract.mine(bot_contract_address, seed);
}

#[test]
fn mine_same_block_twice_success() {
    // First declare and deploy a contract
    let (game_contract_address, bot_contract_address,executor_address) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    // owner operations 
    start_cheat_caller_address(game_contract_address,executor_address);
    game_contract.enable_contract();

    start_cheat_block_number(bot_contract_address, 0x420_u64);
    start_cheat_block_timestamp(bot_contract_address, 0x2137_u64);

    let seed = 0x7b; // 123

    game_contract.mine(bot_contract_address, seed);
    game_contract.mine(bot_contract_address, seed);
}

#[test]
fn mine_different_blocks() {
    // First declare and deploy a contract
    let (game_contract_address, bot_contract_address,executor_address) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    // owner operations 
    start_cheat_caller_address(game_contract_address,executor_address);
    game_contract.enable_contract();

    start_cheat_block_number(bot_contract_address, 0x420_u64);
    start_cheat_block_timestamp(bot_contract_address, 0x2137_u64);

    let seed_1 = 0x7b; // 123
    let seed_2 = 0x7c; // 124

    game_contract.mine(bot_contract_address, seed_1);
    game_contract.mine(bot_contract_address, seed_2);
}

#[test]
#[should_panic(expected: 'Bot is dead')]
fn mine_with_dead_bot() {
    // First declare and deploy a contract
    let (game_contract_address, bot_contract_address,executor_address) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    // owner operations 
    start_cheat_caller_address(game_contract_address,executor_address);
    game_contract.enable_contract();

    start_cheat_block_number(bot_contract_address, 0x420_u64);
    start_cheat_block_timestamp(bot_contract_address, 0x2137_u64);

    let seed = 0x7b; // 123

    game_contract.mine(bot_contract_address, seed);

    // kill bot
    start_cheat_caller_address(bot_contract_address, executor_address);
    bot_contract.kill_bot();

    game_contract.mine(bot_contract_address, seed);
}