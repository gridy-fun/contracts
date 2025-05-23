use gridy::bot::interface::{IBotContractDispatcher, IBotContractDispatcherTrait};
use gridy::constants::{
    block_id, bomb_value, grid_height, grid_width, mining_points, player_id, point_1, point_2,
    total_points,
};
use snforge_std as snf;
use gridy::game::main::GameContract;
use snforge_std::{EventSpy, EventSpyAssertionsTrait};
use gridy::game::interface::{IGameContractDispatcher, IGameContractDispatcherTrait};
use gridy::game::types::BlockPoint;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_number,
    start_cheat_block_timestamp, start_cheat_caller_address,
};
use starknet::ContractAddress;


fn setup_user_account(pub_key: felt252) -> ContractAddress {
    let account = declare("SnakeAccountMock").unwrap().contract_class();
    let mut account_constructor_args = ArrayTrait::new();
    pub_key.serialize(ref account_constructor_args);
    let (account_contract_address, _) = account.deploy(@account_constructor_args).unwrap();
    account_contract_address
}

fn deploy_contract() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    // setup admin account
    let executor_address = setup_user_account('PUBKEY_1');
    let sequencer_address = setup_user_account('PUBKEY_2');

    // declare bot contract
    let bot_contract = declare("BotContract").unwrap().contract_class();

    let mut block_points: Span<BlockPoint> = array![point_1, point_2].span();

    // deploy game contract
    let game_contract = declare("GameContract").unwrap().contract_class();
    let mut game_contract_constructor_args = ArrayTrait::new();
    executor_address.serialize(ref game_contract_constructor_args);
    bot_contract.serialize(ref game_contract_constructor_args);
    bomb_value.serialize(ref game_contract_constructor_args);
    0.serialize(ref game_contract_constructor_args);
    mining_points.serialize(ref game_contract_constructor_args);
    grid_width.serialize(ref game_contract_constructor_args);
    grid_height.serialize(ref game_contract_constructor_args);
    total_points.serialize(ref game_contract_constructor_args);
    sequencer_address.serialize(ref game_contract_constructor_args);
    0.serialize(ref game_contract_constructor_args);
    let (game_contract_address, _) = game_contract.deploy(@game_contract_constructor_args).unwrap();

    // deploy bot contract
    let mut bot_contract_constructor_args = ArrayTrait::new();
    let player_address: ContractAddress = player_id.try_into().unwrap();
    executor_address.serialize(ref bot_contract_constructor_args);
    player_address.serialize(ref bot_contract_constructor_args);
    game_contract_address.serialize(ref bot_contract_constructor_args);
    block_id.serialize(ref bot_contract_constructor_args);
    grid_height.serialize(ref bot_contract_constructor_args);
    grid_width.serialize(ref bot_contract_constructor_args);
    let (bot_contract_address, _) = bot_contract.deploy(@bot_contract_constructor_args).unwrap();

    (game_contract_address, bot_contract_address, executor_address, sequencer_address)
}


#[test]
fn game_contract_deploy_bot() {
    let (game_contract_address, _, executor_address, _) = deploy_contract();
    start_cheat_caller_address(game_contract_address, executor_address);
    let player_address: ContractAddress = player_id.try_into().unwrap();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };

    // add block points
    game_contract.update_block_points(12312312, 10);
    game_contract.update_block_points(1222222, 666);

    // enable contract
    game_contract.enable_contract();

    game_contract.deploy_bot(player_address, 132123213)
}

#[test]
#[should_panic(expected: 'contract is disabled')]
fn check_game_contract_enabled_status() {
    let (game_contract_address, _, _, _) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let game = game_contract.is_contract_enabled();
    assert(game == true, 'contract is disabled');
}


#[test]
fn check_bot_contract_enabled_status() {
    let (_, bot_contract_address, _, _) = deploy_contract();
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };
    let bot = bot_contract.is_bot_alive();
    assert(bot == true, 'contract is disabled');
}
#[test]
fn check_game_bot_enabled() {
    // First declare and deploy a contract
    let (game_contract_address, bot_contract_address, executor_address, _) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    // owner operations
    start_cheat_caller_address(game_contract_address, executor_address);

    // add block points
    game_contract.update_block_points(12312312, 10);
    game_contract.update_block_points(1222222, 666);

    // enable contract
    game_contract.enable_contract();

    // check storage of the contract
    let bot = bot_contract.is_bot_alive();
    assert(bot == true, 'contract is disabled');
}

#[test]
fn mine_block() {
    // First declare and deploy a contract
    let (game_contract_address, bot_contract_address, executor_address, sequencer_address) =
        deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    // owner operations
    start_cheat_caller_address(game_contract_address, executor_address);

    // add block points
    game_contract.update_block_points(12312312, 10);
    game_contract.update_block_points(1222222, 666);

    // enable contract
    game_contract.enable_contract();

    start_cheat_block_number(bot_contract_address, 0x420_u64);
    start_cheat_block_timestamp(bot_contract_address, 0x2137_u64);

    // add seed value
    let seed_1 = 0x7b; // 123

    game_contract.mine(bot_contract_address, seed_1);
}

#[test]
fn mine_different_blocks() {
    // First declare and deploy a contract
    let (game_contract_address, bot_contract_address, executor_address, _) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    // owner operations
    start_cheat_caller_address(game_contract_address, executor_address);

    // add block points
    game_contract.update_block_points(12312312, 10);
    game_contract.update_block_points(1222222, 666);

    // enable contract
    game_contract.enable_contract();

    start_cheat_block_number(bot_contract_address, 0x420_u64);
    start_cheat_block_timestamp(bot_contract_address, 0x2137_u64);

    let seed_1 = 0x7b; // 123
    let seed_2 = 0x7c; // 124

    game_contract.mine(bot_contract_address, seed_1);
    game_contract.mine(bot_contract_address, seed_2);
}

#[test]
fn mine_with_dead_bot() {
    // First declare and deploy a contract
    let (game_contract_address, bot_contract_address, executor_address, _) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    // owner operations
    start_cheat_caller_address(game_contract_address, executor_address);

    // add block points
    game_contract.update_block_points(12312312, 10);
    game_contract.update_block_points(1222222, 666);

    // enable contract
    game_contract.enable_contract();

    start_cheat_block_number(bot_contract_address, 0x420_u64);
    start_cheat_block_timestamp(bot_contract_address, 0x2137_u64);

    let seed = 0x7b; // 123

    game_contract.mine(bot_contract_address, seed);

    // kill bot
    start_cheat_caller_address(bot_contract_address, game_contract_address);
    bot_contract.kill_bot();

    game_contract.mine(bot_contract_address, seed);
}

#[test]
fn mine_a_bomb() {
    // First declare and deploy a contract
    let (game_contract_address, bot_contract_address, executor_address, _) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    // owner operations
    start_cheat_caller_address(game_contract_address, executor_address);

    // add block points
    game_contract.update_block_points(12312312, 10);
    game_contract.update_block_points(1222222, 666);

    // enable contract
    game_contract.enable_contract();

    start_cheat_block_number(bot_contract_address, 0x420_u64);
    start_cheat_block_timestamp(bot_contract_address, 0x2137_u64);

    let seed = 0x7b; // 123

    game_contract.mine(bot_contract_address, seed);
}

#[test]
fn deploy_multiple_bots() {
    // First declare and deploy a contract
    let (game_contract_address, bot_contract_address, executor_address, _) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    // owner operations
    start_cheat_caller_address(game_contract_address, executor_address);

    // add block points
    game_contract.update_block_points(12312312, 10);
    game_contract.update_block_points(1222222, 666);

    // enable contract
    game_contract.enable_contract();

    start_cheat_block_number(bot_contract_address, 0x420_u64);
    start_cheat_block_timestamp(bot_contract_address, 0x2137_u64);

    let seed = 0x7b; // 123

    game_contract.mine(bot_contract_address, seed);

    let player_address: ContractAddress = player_id.try_into().unwrap();
    game_contract.deploy_bot(player_address, 132123213);
    game_contract.deploy_bot(player_address, 123123);
    game_contract.deploy_bot(player_address, 132122123213);
}

#[test]
fn check_unique_block_id() {
    // First declare and deploy a contract
    let (game_contract_address, bot_contract_address, executor_address, _) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    // owner operations
    start_cheat_caller_address(game_contract_address, executor_address);

    // add block points
    game_contract.update_block_points(12312312, 10);
    game_contract.update_block_points(1222222, 666);

    // enable contract
    game_contract.enable_contract();

    start_cheat_block_number(bot_contract_address, 0x420_u64);
    start_cheat_block_timestamp(bot_contract_address, 0x2137_u64);
}

#[test]
fn mine_with_sequencer() {
    // First declare and deploy a contract
    let (game_contract_address, bot_contract_address, executor_address, sequencer_address) =
        deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    // owner operations
    start_cheat_caller_address(game_contract_address, executor_address);

    // add block points
    game_contract.update_block_points(12312312, 10);
    game_contract.update_block_points(1222222, 666);

    // enable contract
    game_contract.enable_contract();

    start_cheat_block_number(bot_contract_address, 0x420_u64);
    start_cheat_block_timestamp(bot_contract_address, 0x2137_u64);

    let seed_1 = 0x7c; // 124

    start_cheat_caller_address(game_contract_address, sequencer_address);
    game_contract.mine(bot_contract_address, seed_1);
}


#[test]
// #[should_panic(expected: 'Caller is not the owner')]
fn mine_with_random_address() {
    // First declare and deploy a contract
    let mut spy = snf::spy_events();
    let (game_contract_address, bot_contract_address, _, _) = deploy_contract();
    let game_contract = IGameContractDispatcher { contract_address: game_contract_address };
    let bot_contract = IBotContractDispatcher { contract_address: bot_contract_address };

    let player_address: ContractAddress = player_id.try_into().unwrap();

    // owner operations
    start_cheat_caller_address(game_contract_address, player_address);

    // // add block points
    game_contract.update_block_points(68, 10);
    game_contract.update_block_points(77, 666);

    // enable contract
    game_contract.enable_contract();

    start_cheat_block_number(bot_contract_address, 0x420_u64);
    start_cheat_block_timestamp(bot_contract_address, 0x2137_u64);

    let seed_1 = 0x7c; // 124

    game_contract.mine(bot_contract_address, seed_1);

    let expected_event = GameContract::TileMined {
        bot_address: bot_contract_address, points: 1, location: 24,
    };

    spy
        .assert_emitted(
            @array![(game_contract_address, GameContract::Event::TileMined(expected_event))],
        );
}
