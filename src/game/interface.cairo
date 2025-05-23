use starknet::ContractAddress;

#[starknet::interface]
pub trait IGameContract<TContractState> {
    // admin functions
    fn enable_contract(ref self: TContractState);
    fn disable_contract(ref self: TContractState);
    fn set_game_currency(ref self: TContractState, currency: ContractAddress);
    fn update_boot_amount(ref self: TContractState, amount: felt252);
    fn get_game_currency(self: @TContractState) -> ContractAddress;
    fn get_bot_to_player(self: @TContractState, bot: ContractAddress) -> ContractAddress;
    fn get_total_bots_of_player(self: @TContractState, player: ContractAddress) -> felt252;
    fn get_bot_of_player(
        self: @TContractState, player: ContractAddress, index: felt252,
    ) -> ContractAddress;
    fn update_executor_contract(ref self: TContractState, sequencer: ContractAddress);
    fn update_bomb_value(ref self: TContractState, bomb_value: u128);
    fn manage_bot_suspension(ref self: TContractState, bot: ContractAddress, suspend: bool);
    fn update_block_points(ref self: TContractState, block_id: felt252, points: u128);
    fn set_appchain_bridge(ref self: TContractState, bridge: ContractAddress);
    fn withdraw_game_currency(ref self: TContractState, amount: u128, recipient: ContractAddress);

    // game functions
    fn deploy_bot(ref self: TContractState, player: ContractAddress, location: felt252);
    fn mine(ref self: TContractState, bot: ContractAddress, seed: u128);

    // view functions
    fn is_contract_enabled(self: @TContractState) -> bool;
    fn check_if_already_mined(self: @TContractState, block_id: felt252) -> bool;
    fn get_bot_deployment_salt(self: @TContractState) -> felt252;
    fn get_total_diamonds_mined(self: @TContractState) -> felt252;
    fn get_appchain_bridge(self: @TContractState) -> ContractAddress;

    fn get_magic_diamond_status(self: @TContractState) -> (bool, bool, bool);
    fn get_block_points(self: @TContractState, block_id: felt252) -> u128;
    fn get_total_bombs_mined(self: @TContractState) -> felt252;
}
