#[derive(Drop, Serde,Copy,Debug, starknet::Store)]
pub struct BlockPoint {
    pub id: felt252,
    pub points: u128,
}
