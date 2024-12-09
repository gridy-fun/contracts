use starknet::ContractAddress;

#[starknet::interface]
pub trait IGameContract<TContractState> {
    // admin functions 
    fn enable_contract(ref self: TContractState);
    fn disable_contract(ref self: TContractState);
    fn update_executor_contract(ref self: TContractState, executor: ContractAddress);

    // game functions
    fn deploy_bot(ref self: TContractState, player: ContractAddress, location: felt252);
    fn mine(ref self: TContractState, bot: ContractAddress, new_mine: felt252);

    // view functions
    fn is_contract_enabled(self: @TContractState) -> bool;
    fn check_if_already_mined(self: @TContractState, new_mine: felt252) -> bool;
}