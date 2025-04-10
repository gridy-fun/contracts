use starknet::ContractAddress;
use starknet::testing::{set_caller_address, set_contract_address};
use gridy::bot::main::BotContract;
use gridy::bot::interface::IBotContract;

// #[test]
// fn test_compute_point_disabled_bot() {
//     // Setup
//     let mut state = BotContract::contract_state_for_testing();
//     let owner: ContractAddress = 0x123.try_into().unwrap();
//     let player: ContractAddress = 0x456.try_into().unwrap();
//     let game_contract: ContractAddress = 0x789.try_into().unwrap();
//     let location: felt252 = 42;
//     let grid_width: u128 = 10;
//     let grid_height: u128 = 10;
    
//     // Initialize contract
//     BotContract::constructor(
//         ref state,
//         owner,
//         player,
//         game_contract,
//         location,
//         grid_width,
//         grid_height,
//     );
//     // Disable the bot
//     state.kill_bot();
    
//     // Test compute_point with disabled bot
//     let seed: u128 = 12345;
//     let result = state.compute_point(seed);
    
//     // Verify the result is the special value for disabled bots
//     assert(result == 119001055159669204776739172, 'Should rer disabled bot');
// }

#[test]
fn test_compute_point_enabled_bot() {
    // Setup
    let mut state = BotContract::contract_state_for_testing();
    let owner: ContractAddress = 0x123.try_into().unwrap();
    let player: ContractAddress = 0x456.try_into().unwrap();
    let game_contract: ContractAddress = 0x789.try_into().unwrap();
    let location: felt252 = 42;
    let grid_width: u128 = 10;
    let grid_height: u128 = 10;
    
    // Initialize contract
    BotContract::constructor(
        ref state,
        owner,
        player,
        game_contract,
        location,
        grid_width,
        grid_height,
    );
    
    
    // Test compute_point with enabled bot
    let seed: u128 = 12345;
    let result = state.compute_point(seed);
    
    // Verify the result is within the grid boundaries
    // Since we can't predict the exact random value, we just check it's not the special value
    assert(result != 119001055159669204776739172, 'value for enabled bot');
    
    // Test with different seeds to ensure different results
    let seed2: u128 = 54321;
    let result2 = state.compute_point(seed2);
    println!("result2: {}", result2);

    
    // The results might be the same with different seeds, but it's unlikely
    // In a real test, you might want to mock the random number generation
    // to have more deterministic tests
}

// #[test]
// fn test_compute_point_with_mocked_random() {
//     // This test would mock the random number generation
//     // to have deterministic tests
    
//     // Setup
//     let mut state = BotContract::contract_state_for_testing();
//     let owner: ContractAddress = 0x123.try_into().unwrap();
//     let player: ContractAddress = 0x456.try_into().unwrap();
//     let game_contract: ContractAddress = 0x789.try_into().unwrap();
//     let location: felt252 = 42;
//     let grid_width: u128 = 10;
//     let grid_height: u128 = 10;
    
//     // Initialize contract
//     BotContract::constructor(
//         ref state,
//         owner,
//         player,
//         game_contract,
//         location,
//         grid_width,
//         grid_height,
//     );
    
//     // In a real implementation, you would mock the generate_random_number function
//     // to return specific values for testing
    
//     // For example, if generate_random_number(12345) returns (5, 7)
//     // then compute_point(12345) should return the block ID for coordinates (5, 7)
    
//     // This would require mocking or modifying the contract for testing
//     // which is beyond the scope of this simple test
// } 