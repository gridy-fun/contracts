use starknet::ContractAddress;

#[starknet::interface]
pub trait IBotContract<TContractState> {
    // admin functions 
    fn start_bot(ref self: TContractState);
    fn kill_bot(ref self: TContractState);
    fn update_owner(ref self: TContractState, new_executor: ContractAddress);

    // game functions
    fn compute_point(self: @TContractState, seed: u128) -> felt252;

    // view functions
    fn is_bot_alive(self: @TContractState) -> bool;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_coordinates_from_block_id(self: @TContractState, location: felt252) -> Span<u128>;
}