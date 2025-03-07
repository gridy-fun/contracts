#[starknet::contract]
pub mod BotContract {
    use core::option::OptionTrait;
    use core::pedersen::pedersen;
    use core::traits::TryInto;
    use gridy::bot::interface::IBotContract;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{
        ContractAddress, get_block_number, get_block_timestamp, get_caller_address,
        get_contract_address,
    };

    #[storage]
    struct Storage {
        executor: ContractAddress,
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
        executor: ContractAddress, // owner of game contract
        spawned_by: ContractAddress, // player who spawned the bot
        game_contract: ContractAddress,
        initial_location: felt252,
        grid_width: u128,
        grid_height: u128,
    ) {
        self.executor.write(executor);
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
            assert(self.executor.read() == get_caller_address(), 'Only admin can start');
            self.bot_enabled.write(true);
        }

        fn kill_bot(ref self: ContractState) {
            assert(
                self.executor.read() == get_caller_address()
                    || self.game_contract.read() == get_caller_address(),
                'Only admin can kill',
            );
            self.bot_enabled.write(false);
        }

        fn update_owner(ref self: ContractState, new_executor: ContractAddress) {
            assert(self.executor.read() == get_caller_address(), 'Only admin can update');
            self.executor.write(new_executor);
        }

        fn get_coordinates_from_block_id(self: @ContractState, location: felt252) -> Span<u128> {
            self.get_coordinates_from_blockid(location)
        }

        fn compute_point(self: @ContractState, seed: u128) -> felt252 {
            if (!self.bot_enabled.read()) {
                return 119001055159669204776739172.into();
            }

            // generate random number
            let (x, y) = self.generate_random_number(seed);

            // check if block is mined
            let block_id: u256 = self
                .get_blockid_from_coordinates(
                    array![(x % self.grid_width.read()), (y % self.grid_height.read())].span(),
                )
                .try_into()
                .unwrap();

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
        fn generate_random_number(self: @ContractState, seed: u128) -> (u128, u128) {
            // get block hash
            let block_timestamp = get_block_timestamp();
            let block_number = get_block_number();

            // generate pedersen hash
            let random_number = pedersen(
                pedersen(
                    block_number.into(),
                    pedersen(block_timestamp.into(), get_contract_address().into()),
                ),
                seed.into(),
            );

            // generate random number
            let num: u256 = random_number.try_into().unwrap();
            (num.high.try_into().unwrap(), num.low.try_into().unwrap())
        }

        fn get_coordinates_from_blockid(self: @ContractState, point: felt252) -> Span<u128> {
            let mut block_id_formatted: u128 = point.try_into().unwrap();
            let divider: NonZero<u128> = self.grid_width.read().try_into().unwrap();
            let (q, r) = DivRem::<u128>::div_rem(block_id_formatted, divider);

            array![r, q].span()
        }

        fn get_blockid_from_coordinates(self: @ContractState, mut coordinates: Span<u128>) -> u128 {
            let grid_width = self.grid_width.read();
            let block_id = (*coordinates[0] + (grid_width * *coordinates[1])).try_into().unwrap();

            block_id.clone()
        }
    }
}
