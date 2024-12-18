#[starknet::contract]
pub mod GameContract{
    use starknet::{ContractAddress,ClassHash,get_contract_address, SyscallResultTrait};
    use gridy::{
        game::{interface::IGameContract},
        bot::{interface::{IBotContractDispatcher,IBotContractDispatcherTrait}},
    };
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use openzeppelin::{
        access::ownable::OwnableComponent,
        upgrades::{UpgradeableComponent, interface::IUpgradeable},
    };
    use starknet::syscalls::deploy_syscall;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    
    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // Flag to enable/disable the contract
        contract_enabled: bool,

        // bot contract class hash
        bot_contract_class_hash: ClassHash,

        // diamond location -> we use a map to make it easy to search for the diamond in O(1)
        block_points_map: Map<felt252, u128>,

        // bomb value -> flag value to identify a bomb
        bomb_value: u128,

        // points for mining
        mining_points: u128,

        // address of executor contract
        executor: ContractAddress,

        //mined tiles map
        mined_tiles: Map<felt252, bool>,

        // add grid dimensions
        grid_width: u128,
        grid_height: u128,

        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {        
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        DiamondFound: DiamondFound,
        BombFound: BombFound,
        TileMined: TileMined,
        SpawnedBot: SpawnedBot,
    }


    #[derive(Drop, starknet::Event)]
    struct DiamondFound {
        #[key]
        bot: ContractAddress,
        #[key]
        points: u128,
        #[key]
        location: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct SpawnedBot {
        #[key]
        player: ContractAddress,
        #[key]
        location: felt252,
        #[key]
        bot_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct BombFound {
        #[key]
        bot: ContractAddress,
        #[key]
        location: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct TileMined {
        #[key]
        bot: ContractAddress,
        #[key]
        points: u128,
        #[key]
        location: felt252,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct BlockPoint {
        id: felt252,
        points: u128,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        executor: ContractAddress, 
        bot_contract_class_hash: ClassHash,
        bomb_value: u128,
        mining_points: u128, 
        grid_width: u128, 
        grid_height: u128, 
        // block_points: Span<BlockPoint>,
    ) {
        // Set the initial owner of the contract
        self.ownable.initializer(executor);
        self.contract_enabled.write(false);
        self.mining_points.write(mining_points);
        self.executor.write(executor);
        self.grid_width.write(grid_width);
        self.grid_height.write(grid_height);
        self.bomb_value.write(bomb_value);
        self.bot_contract_class_hash.write(bot_contract_class_hash);

        self.block_points_map.entry(14991605).write(666);

        // add block points
        // let mut index=0;
        // loop {
        //     if index == block_points.len() {
        //         break;
        //     }
        //     let block_point = *block_points.at(index);
        //     let block_point = block_point.unwrap();
        //     self.block_points_map.entry(block_point.id).write(block_point.points);
        //     index += 1;
        // }
    }


    #[abi(embed_v0)]
    impl GameContract of IGameContract<ContractState> {
        fn enable_contract(ref self: ContractState) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            self.contract_enabled.write(true);
        }

        fn disable_contract(ref self: ContractState) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            self.contract_enabled.write(false);
        }

        fn update_executor_contract(ref self: ContractState, executor: ContractAddress) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            self.executor.write(executor);
        }

        fn update_bomb_value(ref self: ContractState, bomb_value: u128){
             // This function can only be called by the owner
             self.ownable.assert_only_owner();

             self.bomb_value.write(bomb_value);
        }

        fn deploy_bot(ref self: ContractState, player: ContractAddress, location: felt252) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();
            
            assert(self.is_contract_enabled(), 'Contract is disabled');

            // deploy bot class hash
            let bot_contract_class_hash = self.bot_contract_class_hash.read();
            let contract_address = get_contract_address();
            let mut bot_contract_constructor_args = ArrayTrait::new();
            self.executor.read().serialize(ref bot_contract_constructor_args);
            player.serialize(ref bot_contract_constructor_args);
            contract_address.serialize(ref bot_contract_constructor_args);
            location.serialize(ref bot_contract_constructor_args);
            self.grid_width.read().serialize(ref bot_contract_constructor_args);
            self.grid_height.read().serialize(ref bot_contract_constructor_args);
            let (deployed_address,_) = deploy_syscall(bot_contract_class_hash.try_into().unwrap(), 0, bot_contract_constructor_args.span(), false).unwrap_syscall();

            self.emit(Event::SpawnedBot(SpawnedBot { player: player, location: location, bot_address: deployed_address }));
        }

        fn mine(ref self: ContractState, bot: ContractAddress, seed: u128) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            // check if contract is disabled
            assert(self.is_contract_enabled(), 'Contract is disabled');

            // get bot contract 
            let bot_contract = IBotContractDispatcher { contract_address: bot };

            // generate random point from bot
            let new_mine : felt252 = bot_contract.compute_point(seed);

            // get bomb denotion value
            let bomb_value=self.bomb_value.read();

            // check if block is already mined
            assert(!self.check_if_already_mined(new_mine), 'block already mined');

            // check for diamond or bomb
            let block_points : u128 = self.block_points_map.entry(new_mine).read();

            // check if location contains a diamond
            if block_points != 0 && block_points != bomb_value {
                self.emit(Event::DiamondFound(DiamondFound { bot, points: block_points, location: new_mine }));
            }

            // check if location contains a bomb
            else if block_points == bomb_value {
                bot_contract.kill_bot();
                self.emit(Event::BombFound(BombFound { bot: bot, location: new_mine }));
            }

            // mine the tile
            self.mined_tiles.entry(new_mine).write(true);

            self.emit(Event::TileMined(TileMined { bot, points: self.mining_points.read(), location: new_mine }));
        }

        fn is_contract_enabled(self: @ContractState) -> bool {
            self.contract_enabled.read()
        }

        fn check_if_already_mined(self: @ContractState, block_id: felt252) -> bool {
            self.mined_tiles.entry(block_id).read()
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            // Replace the class hash upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }
    }

}
