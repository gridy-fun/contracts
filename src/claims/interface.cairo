use starknet::ContractAddress;

#[starknet::interface]
pub trait IClaimContract<TState> {
    fn claim(ref self: TState, proof: Span<felt252>, address: ContractAddress, amount: u128);
    fn get_token_address(self: @TState) -> ContractAddress;
    fn verify(self: @TState, proof: Span<felt252>, address: ContractAddress, amount: u128) -> bool;
    fn leaf_hash(self: @TState, address: ContractAddress, amount: u128) -> felt252;
}

#[starknet::interface]
pub trait IClaimAdmin<TState> {
    fn withdraw_tokens(ref self: TState, amount: u128);
}

