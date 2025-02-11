#[starknet::contract]
pub mod GameContract{
    use starknet::{ContractAddress,ClassHash,get_contract_address, get_caller_address, SyscallResultTrait};
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
        sequencer: ContractAddress,

        //mined tiles map
        mined_tiles: Map<felt252, bool>,

        // total count of diamonds and bombs
        total_diamonds_and_bombs: u128,

        // counter for block point locations
        block_points_counter: u128,

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
        SuspendBot: SuspendBot,
        ReviveBot: ReviveBot,
        TileAlreadyMined: TileAlreadyMined,
    }


    #[derive(Drop, starknet::Event)]
    struct DiamondFound {
        bot_address: ContractAddress,
        points: u128,
        location: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct SpawnedBot {
        bot_address: ContractAddress,
        player: ContractAddress,
        location: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct BombFound {
        bot_address: ContractAddress,
        location: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct SuspendBot {
        bot_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct ReviveBot {
        bot_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct TileAlreadyMined {
        bot_address: ContractAddress,
        location: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct TileMined {
        bot_address: ContractAddress,
        points: u128,
        location: felt252,
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
        total_diamonds_and_bombs: u128,
        sequencer: ContractAddress
    ) {
        // Set the initial owner of the contract
        self.ownable.initializer(executor);
        self.contract_enabled.write(false);
        self.mining_points.write(mining_points);
        self.sequencer.write(sequencer);
        self.grid_width.write(grid_width);
        self.grid_height.write(grid_height);
        self.bomb_value.write(bomb_value);
        self.bot_contract_class_hash.write(bot_contract_class_hash);
        self.total_diamonds_and_bombs.write(total_diamonds_and_bombs);
        self.block_points_counter.write(0);
    }


    #[abi(embed_v0)]
    impl GameContract of IGameContract<ContractState> {
        fn enable_contract(ref self: ContractState) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            if self.block_points_counter.read() == self.total_diamonds_and_bombs.read() {
                self.contract_enabled.write(true);
            }
            else {
                panic!("Insufficient block points");
            }

        }

        fn disable_contract(ref self: ContractState) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            self.contract_enabled.write(false);
        }

        fn update_executor_contract(ref self: ContractState, sequencer: ContractAddress) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            self.sequencer.write(sequencer);
        }

        fn update_block_points(ref self: ContractState, block_id: felt252, points: u128) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            self.block_points_map.entry(block_id).write(points);
            self.block_points_counter.write(self.block_points_counter.read() + 1);
        }

        fn update_bomb_value(ref self: ContractState, bomb_value: u128){
             // This function can only be called by the owner
             self.ownable.assert_only_owner();

             self.bomb_value.write(bomb_value);
        }

        fn deploy_bot(ref self: ContractState, player: ContractAddress, location: felt252) {
            assert(self.is_contract_enabled(), 'Contract is disabled');
            
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            // check if location not mined
            assert(!self.check_if_already_mined(location), 'block already mined');

            // deploy bot class hash
            let bot_contract_class_hash = self.bot_contract_class_hash.read();
            let contract_address = get_contract_address();
            let mut bot_contract_constructor_args = ArrayTrait::new();
            self.ownable.owner().serialize(ref bot_contract_constructor_args);
            player.serialize(ref bot_contract_constructor_args);
            contract_address.serialize(ref bot_contract_constructor_args);
            location.serialize(ref bot_contract_constructor_args);
            self.grid_width.read().serialize(ref bot_contract_constructor_args);
            self.grid_height.read().serialize(ref bot_contract_constructor_args);
            let (deployed_address,_) = deploy_syscall(bot_contract_class_hash.try_into().unwrap(), 0, bot_contract_constructor_args.span(), true).unwrap_syscall();

            self.emit(Event::SpawnedBot(SpawnedBot { player: player, location: location, bot_address: deployed_address }));
        }

        fn mine(ref self: ContractState, bot: ContractAddress, seed: u128) {
            let caller = get_caller_address();
            
            // This function can only be called by the admins
            assert(self.sequencer.read() == caller || self.ownable.owner() == caller, 'Only admins can mine');

            // check if contract is disabled
            assert(self.is_contract_enabled(), 'Contract is disabled');

            // get bot contract 
            let bot_contract = IBotContractDispatcher { contract_address: bot };

            // generate random point from bot
            let new_mine : felt252 = bot_contract.compute_point(seed);

            // check if 0
            if (new_mine == 119001055159669204776739172) {
                return;
            }
            // get bomb denotion value
            let bomb_value=self.bomb_value.read();

            // check if block is already mined
            if(self.check_if_already_mined(new_mine)){
                self.emit(Event::TileAlreadyMined(TileAlreadyMined { bot_address : bot, location: new_mine }));
                return;
            }

            // check for diamond or bomb
            let block_points : u128 = self.block_points_map.entry(new_mine).read();

            // check if location contains a diamond
            if block_points != 0 && block_points != bomb_value {
                self.emit(Event::DiamondFound(DiamondFound { bot_address : bot, points: block_points, location: new_mine }));
            }

            // check if location contains a bomb
            else if block_points == bomb_value {
                bot_contract.kill_bot();
                self.emit(Event::BombFound(BombFound { bot_address: bot, location: new_mine }));
            }

            // mine the tile
            self.mined_tiles.entry(new_mine).write(true);

            self.emit(Event::TileMined(TileMined { bot_address: bot, points: self.mining_points.read(), location: new_mine }));
        }

        fn is_contract_enabled(self: @ContractState) -> bool {
            self.contract_enabled.read()
        }

        fn manage_bot_suspension(ref self: ContractState, bot: ContractAddress, suspend: bool) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            let bot_contract = IBotContractDispatcher { contract_address: bot };

            if suspend {
                bot_contract.kill_bot();
                self.emit(Event::SuspendBot(SuspendBot { bot_address: bot }));
                return;
            }

            bot_contract.start_bot();
            self.emit(Event::ReviveBot(ReviveBot { bot_address: bot }));
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
