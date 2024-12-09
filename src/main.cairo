#[starknet::contract]
pub mod GameContract{
    use starknet::{ContractAddress,ClassHash,get_contract_address};
    use gridy::{
        interface::IGameContract,
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
        diamond_points_map: Map<felt252, u128>,

        // bomb location -> we use a map to make it easy to search for the bomb in O(1)
        bomb_location: Map<felt252, bool>,

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

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        owner: ContractAddress,
        executor: ContractAddress, 
        bot_contract_class_hash: ClassHash,
        mining_points: u128, 
        grid_width: u128, 
        grid_height: u128, 
    ) {
        // Set the initial owner of the contract
        self.ownable.initializer(owner);

        self.contract_enabled.write(false);
        self.mining_points.write(1);
        self.executor.write(executor);
        self.grid_width.write(10);
        self.grid_height.write(10);
        self.bot_contract_class_hash.write(bot_contract_class_hash);
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

        fn deploy_bot(ref self: ContractState, player: ContractAddress, location: felt252) {
            assert(self.is_contract_enabled(), 'Contract is disabled');

            // deploy bot class hash
            let bot_contract_class_hash = self.bot_contract_class_hash.read();
            deploy_syscall(bot_contract_class_hash.try_into().unwrap(), 0, @array![get_contract_address(), get_caller_address(), 0].span(), false);

            // TODO: add bot to the game using executor contract
            self.emit(Event::SpawnedBot(SpawnedBot { player: player, location: location }));
        }

        fn mine(ref self: ContractState, bot: ContractAddress, new_mine: felt252) {
            let diamond_points : u128 = self.diamond_points_map.entry(new_mine).read();

            // check if location contains a diamond
            if diamond_points > 0 {
                self.emit(Event::DiamondFound(DiamondFound { bot, points: diamond_points, location: new_mine }));
            }

            // check if location contains a bomb
            else if self.bomb_location.entry(new_mine).read() {
                // TODO: remove bot from the game in the executor contract
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
