use starknet::ContractAddress;

#[starknet::interface]
pub trait IGameContract<TContractState> {
    // admin functions 
    fn enable_contract(ref self: TContractState);
    fn disable_contract(ref self: TContractState);
    fn update_executor_contract(ref self: TContractState, executor: ContractAddress);

    // game functions
    fn deploy_bot(ref self: TContractState, player: ContractAddress);
    fn mine(ref self: TContractState, player: ContractAddress, new_mine: u64);

    // view functions
    fn is_contract_enabled(self: @TContractState) -> bool;
    fn check_if_already_mined(self: @TContractState, new_mine: u64) -> bool;
}