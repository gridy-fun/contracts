#[starknet::contract]
pub mod BotContract{
    use core::traits::TryInto;
    use starknet::{ContractAddress,SyscallResultTrait, get_caller_address,get_block_number, get_block_timestamp,get_contract_address};
    use core::starknet::syscalls::get_block_hash_syscall;
    use gridy::bot::interface::IBotContract;
    use core::pedersen::pedersen;
    use core::option::OptionTrait;
    use gridy::game::interface::{IGameContractDispatcher, IGameContractDispatcherTrait};


    #[storage]
    struct Storage {
       owner : ContractAddress,
       spawned_by: ContractAddress,
       initial_location: felt252,
       bot_enabled: bool,
       grid_width: u128,
       grid_height: u128,
       game_contract: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        owner: ContractAddress, 
        spawned_by: ContractAddress, 
        game_contract: ContractAddress,
        initial_location: felt252,
        grid_width: u128,
        grid_height: u128,
    ) {
        self.owner.write(owner);
        self.spawned_by.write(spawned_by);
        self.initial_location.write(initial_location);
        self.bot_enabled.write(true);
        self.grid_width.write(grid_width);
        self.grid_height.write(grid_height);
        self.game_contract.write(game_contract);
    }

    #[abi(embed_v0)]
    impl BotContract of IBotContract<ContractState> {
        fn start_bot(ref self: ContractState) {
            assert(self.owner.read() == get_caller_address(),'Only admin can start');
            self.bot_enabled.write(true);
        }

        fn kill_bot(ref self: ContractState) {
            assert(self.owner.read() == get_caller_address(),'Only admin can kill');
            self.bot_enabled.write(false);
        }

        fn update_owner(ref self: ContractState, new_owner: ContractAddress) {
            assert(self.owner.read() == get_caller_address(),'Only admin can update');
            self.owner.write(new_owner);
        }

        fn compute_point(self: @ContractState, seed: u128) -> felt252 {
            assert(self.bot_enabled.read()==true, 'Bot is dead');

            let mut block_id: u256  = 0;
            let mut attempts = 100;

            let mut is_valid_point= false;

            loop {
                if is_valid_point || attempts == 0 {
                    break;
                }

                // generate random number
                let (x,y) = self.generate_random_number(seed);

                // check if block is mined
                block_id = self.get_blockid_from_coordinates(array![(x % self.grid_width.read()) + 1,((y / self.grid_height.read()) % self.grid_height.read()) + 1].span()).try_into().unwrap();
                let is_block_mined = IGameContractDispatcher { contract_address: self.game_contract.read() }.check_if_already_mined(block_id.low.into());

                // if block is not mined then break
                if(!is_block_mined) {
                    is_valid_point = true;
                }

                attempts -= 1;
            };
            
            block_id.low.into()
        }

        fn is_bot_alive(self: @ContractState) -> bool {
            self.bot_enabled.read()
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.spawned_by.read()
        }
    }


    #[generate_trait]
    impl InternalImpl of InternalTrait {

        fn generate_random_number(self: @ContractState, seed: u128) -> (u128,u128) {
            // get block hash
            let block_timestamp= get_block_timestamp();
            let block_number=get_block_number();
            let block_hash: felt252= get_block_hash_syscall(block_number-1).unwrap_syscall().into();

            // generate pedersen hash
            let random_number = pedersen(
                pedersen(block_hash.into(),pedersen(block_timestamp.into(),get_contract_address().into())),
                seed.into()
            );

            // generate random number
            let num: u256= random_number.try_into().unwrap();
            (num.high.try_into().unwrap(), num.low.try_into().unwrap())
        }

        fn get_coordinates_from_blockid(self: @ContractState, point: felt252) -> Span<u128> {
            let mut block_id_formatted : u128= point.try_into().unwrap();
            let divider: NonZero<u128> = self.grid_width.read().try_into().unwrap();
            let (q, r) = DivRem::<u128>::div_rem(block_id_formatted, divider);

            array![q, r].span()
        }

        fn get_blockid_from_coordinates(self: @ContractState, mut coordinates: Span<u128>) -> u256 {
            let grid_width = self.grid_width.read();
            let block_id : u256 = (*coordinates[0] + (grid_width * *coordinates[1])).try_into().unwrap();
            
            block_id.clone()
        }
    }
}
