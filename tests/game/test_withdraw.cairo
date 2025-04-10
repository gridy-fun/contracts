use starknet::ContractAddress;
use starknet::testing::{set_caller_address, set_contract_address};
use gridy::game::main::GameContract;
use gridy::game::interface::IGameContract;
use openzeppelin::token::erc20::ERC20ABIDispatcher;
use openzeppelin::token::erc20::interface::IERC20;
use openzeppelin::upgrades::interface::IUpgradeable;

#[test]
fn test_withdraw_game_currency() {
    // Setup
    let mut state = GameContract::contract_state_for_testing();
    let owner: ContractAddress = 0x123.try_into().unwrap();
    let recipient: ContractAddress = 0x456.try_into().unwrap();
    let game_currency: ContractAddress = 0x789.try_into().unwrap();
    let appchain_bridge: ContractAddress = 0xabc.try_into().unwrap();
    let l1_token: ContractAddress = 0xdef.try_into().unwrap();
    
    // Initialize contract
    GameContract::constructor(
        ref state,
        owner,
        0x1234, // bot_contract_class_hash
        100, // bomb_value
        50, // diamond_points
        10, // mining_points
        10, // grid_width
        10, // grid_height
        100, // total_diamonds_and_bombs
        owner, // sequencer
        1000, // boot_amount
    );
    
    // Set game currency and appchain bridge
    set_caller_address(owner);
    state.set_game_currency(game_currency);
    state.set_appchain_bridge(appchain_bridge);
    
    // Mock token bridge behavior
    let token_bridge = ITokenBridgeDispatcher { contract_address: appchain_bridge };
    // Mock get_l1_token to return l1_token
    // This would be done with a mock in a real test
    
    // Test withdrawal
    let amount: u128 = 100;
    state.withdraw_game_currency(amount, recipient);
    
    // Verify the withdrawal was initiated
    // In a real test, you would verify that initiate_token_withdraw was called
    // with the correct parameters (l1_token, recipient, amount)
} 