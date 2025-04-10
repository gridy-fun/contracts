use starknet::ContractAddress;

#[starknet::interface]
trait ITokenBridge<TContractState> {
    fn get_version(self: @TContractState) -> felt252;
    fn get_identity(self: @TContractState) -> felt252;
    fn get_l1_token(self: @TContractState, l2_token: ContractAddress) -> ContractAddress;
    fn get_l1_bridge(self: @TContractState) -> ContractAddress;
    fn get_l2_token(self: @TContractState, l1_token: ContractAddress) -> ContractAddress;
    fn get_remaining_withdrawal_quota(self: @TContractState, l1_token: ContractAddress) -> u256;
    fn initiate_withdraw(ref self: TContractState, l1_recipient: ContractAddress, amount: u256);
    fn initiate_token_withdraw(
        ref self: TContractState,
        l1_token: ContractAddress,
        l1_recipient: ContractAddress,
        amount: u256,
    );
}

#[starknet::contract]
pub mod GameContract {
    use gridy::bot::interface::{IBotContractDispatcher, IBotContractDispatcherTrait};
    use gridy::game::interface::IGameContract;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::syscalls::deploy_syscall;
    use starknet::{
        ClassHash, ContractAddress, SyscallResultTrait, get_caller_address, get_contract_address,
    };

    use super::{ITokenBridgeDispatcher, ITokenBridgeDispatcherTrait};

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
        bot_deployment_salt: felt252,
        // Flag to enable/disable the contract
        contract_enabled: bool,
        // bot contract class hash
        bot_contract_class_hash: ClassHash,
        // diamond location -> we use a map to make it easy to search for the diamond in O(1)
        block_points_map: Map<felt252, u128>,
        // bomb value -> flag value to identify a bomb
        bomb_value: u128,
        diamond_points: u128,
        // points for mining
        mining_points: u128,
        // address of executor contract
        sequencer: ContractAddress,
        total_diamonds_mined: felt252,
        // mined tiles map
        mined_tiles: Map<felt252, bool>,
        // total count of diamonds and bombs
        total_diamonds_and_bombs: u128,
        // counter for block point locations
        block_points_counter: u128, 
        // add grid dimensions
        grid_width: u128,
        grid_height: u128,
        // starting amount to play the game
        boot_amount: felt252,
        // magic diamonds
        magic_500: bool,
        magic_300: bool,
        magic_200: bool,
        // l3 bridge
        appchain_bridge: ContractAddress,
        // Total points awarded yet
        total_points: felt252,
        total_players: felt252,
        id_to_player: Map<felt252, ContractAddress>,
        player_to_points: Map<ContractAddress, felt252>,
        bot_to_player: Map<ContractAddress, ContractAddress>,
        total_bots_player: Map<ContractAddress, felt252>, // No of bots deployed by a player
        bots: Map<
            (ContractAddress, felt252), ContractAddress,
        >, // (Player, BotNo of player) to botAddress mapping
        played_till: felt252,
        game_currency: ERC20ABIDispatcher,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
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
        bot_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ReviveBot {
        bot_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct TileAlreadyMined {
        bot_address: ContractAddress,
        location: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TileMined {
        pub bot_address: ContractAddress,
        pub points: u128,
        pub location: felt252,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        executor: ContractAddress,
        bot_contract_class_hash: ClassHash,
        bomb_value: u128,
        diamond_points: u128,
        mining_points: u128,
        grid_width: u128,
        grid_height: u128,
        total_diamonds_and_bombs: u128,
        sequencer: ContractAddress,
        boot_amount: felt252,
    ) {
        // Set the initial owner of the contract
        self.ownable.initializer(executor);
        self.contract_enabled.write(false);
        self.diamond_points.write(diamond_points);
        self.mining_points.write(mining_points);
        self.sequencer.write(sequencer);
        self.grid_width.write(grid_width);
        self.grid_height.write(grid_height);
        self.bomb_value.write(bomb_value);
        self.bot_contract_class_hash.write(bot_contract_class_hash);
        self.total_diamonds_and_bombs.write(total_diamonds_and_bombs);
        self.block_points_counter.write(0);

        self.boot_amount.write(boot_amount);
    }


    #[abi(embed_v0)]
    impl GameContract of IGameContract<ContractState> {
        fn enable_contract(ref self: ContractState) {
            // This function can only be called by the owner
            // self.ownable.assert_only_owner();

            if self.block_points_counter.read() >= self.total_diamonds_and_bombs.read() {
                self.contract_enabled.write(true);
            } else {
                panic!("Insufficient block points");
            }
        }

        fn set_game_currency(ref self: ContractState, currency: ContractAddress) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();
            self.game_currency.write(ERC20ABIDispatcher { contract_address: currency });
        }

        fn set_appchain_bridge(ref self: ContractState, bridge: ContractAddress) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();
            self.appchain_bridge.write(bridge);
        }

        fn withdraw_game_currency(
            ref self: ContractState, amount: u128, recipient: ContractAddress,
        ) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();
            assert(!self.game_currency.read().contract_address.is_zero(), 'Game currency not set');
            assert(!self.appchain_bridge.read().is_zero(), 'Appchain bridge not set');
            let token_bridge = ITokenBridgeDispatcher {
                contract_address: self.appchain_bridge.read(),
            };
            let l2_token = self.game_currency.read().contract_address;
            let l1_token = token_bridge.get_l1_token(l2_token);
            token_bridge.initiate_token_withdraw(l1_token, recipient, amount.into());
        }

        fn get_appchain_bridge(self: @ContractState) -> ContractAddress {
            self.appchain_bridge.read()
        }

        fn get_game_currency(self: @ContractState) -> ContractAddress {
            self.game_currency.read().contract_address
        }

        fn update_boot_amount(ref self: ContractState, amount: felt252) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            self.boot_amount.write(amount);
        }

        fn get_bot_to_player(self: @ContractState, bot: ContractAddress) -> ContractAddress {
            self.bot_to_player.entry(bot).read()
        }

        fn get_total_bots_of_player(self: @ContractState, player: ContractAddress) -> felt252 {
            self.total_bots_player.entry(player).read()
        }

        fn get_bot_of_player(
            self: @ContractState, player: ContractAddress, index: felt252,
        ) -> ContractAddress {
            self.bots.entry((player, index)).read()
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
            // self.ownable.assert_only_owner();

            self.block_points_map.entry(block_id).write(points);
            self.block_points_counter.write(self.block_points_counter.read() + 1);
        }

        fn update_bomb_value(ref self: ContractState, bomb_value: u128) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            self.bomb_value.write(bomb_value);
        }

        fn deploy_bot(ref self: ContractState, player: ContractAddress, location: felt252) {
            assert(self.is_contract_enabled(), 'Contract is disabled');

            // check if location not mined
            assert(!self.check_if_already_mined(location), 'block already mined');
            assert(!self.game_currency.read().contract_address.is_zero(), 'Game currency not set');

            self
                .game_currency
                .read()
                .transfer_from(
                    get_caller_address(), get_contract_address(), self.boot_amount.read().into(),
                );

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
            self.bot_deployment_salt.write(self.bot_deployment_salt.read() + 1);
            let (deployed_address, _) = deploy_syscall(
                bot_contract_class_hash.try_into().unwrap(),
                self.bot_deployment_salt.read(),
                bot_contract_constructor_args.span(),
                true,
            )
                .unwrap_syscall();

            self.setup_player(player, deployed_address);

            self
                .emit(
                    Event::SpawnedBot(
                        SpawnedBot {
                            player: player, location: location, bot_address: deployed_address,
                        },
                    ),
                );
        }

        fn mine(ref self: ContractState, bot: ContractAddress, seed: u128) {
            // check if contract is disabled
            assert(self.is_contract_enabled(), 'Contract is disabled');

            // get bot contract
            let bot_contract = IBotContractDispatcher { contract_address: bot };

            // generate random point from bot
            let new_mine: felt252 = bot_contract.compute_point(seed);

            // check if 0
            if (new_mine == 119001055159669204776739172) {
                return;
            }
            // get bomb denotion value
            let bomb_value = self.bomb_value.read();

            // check if block is already mined
            if (self.check_if_already_mined(new_mine)) {
                self
                    .emit(
                        Event::TileAlreadyMined(
                            TileAlreadyMined { bot_address: bot, location: new_mine },
                        ),
                    );
                return;
            }

            // check for diamond or bomb
            let block_points: u128 = self.block_points_map.entry(new_mine).read();

            // check if location contains a bomb
            if block_points == bomb_value {
                bot_contract.kill_bot();
                self.mined_tiles.entry(new_mine).write(true);
                self.emit(Event::BombFound(BombFound { bot_address: bot, location: new_mine }));
            } // check if location contains a diamond
            else if block_points != 0 {
                let diamond_value = self.diamond_points.read();
                if block_points == diamond_value * 500 {
                    self.magic_500.write(true);
                } else if block_points == diamond_value * 300 {
                    self.magic_300.write(true);
                } else if block_points == diamond_value * 200 {
                    self.magic_200.write(true);
                }
                let player = self.bot_to_player.entry(bot).read();
                // mine the tile
                self.mined_tiles.entry(new_mine).write(true);

                self
                    .player_to_points
                    .entry(bot)
                    .write(self.player_to_points.entry(player).read() + block_points.into());
                self.total_diamonds_mined.write(self.total_diamonds_mined.read() + 1);
                self
                    .emit(
                        Event::DiamondFound(
                            DiamondFound {
                                bot_address: bot, points: block_points, location: new_mine,
                            },
                        ),
                    );
            }
            self
                .emit(
                    Event::TileMined(
                        TileMined {
                            bot_address: bot, points: self.mining_points.read(), location: new_mine,
                        },
                    ),
                );
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

        fn get_bot_deployment_salt(self: @ContractState) -> felt252 {
            self.bot_deployment_salt.read()
        }


        fn get_total_diamonds_mined(self: @ContractState) -> felt252 {
            self.total_diamonds_mined.read()
        }

        fn get_magic_diamond_status(self: @ContractState) -> (bool, bool, bool) {
            (self.magic_500.read(), self.magic_300.read(), self.magic_200.read())
        }
    }

    #[generate_trait]
    pub impl GameContractImpl of GameContractInternalTrait {
        fn setup_player(
            ref self: ContractState, player: ContractAddress, bot_address: ContractAddress,
        ) {
            self.total_players.write(self.total_players.read() + 1);
            self.id_to_player.entry(self.total_players.read()).write(player);
            self.bot_to_player.entry(bot_address).write(player);
            self
                .total_bots_player
                .entry(player)
                .write(self.total_bots_player.entry(player).read() + 1);
            self
                .bots
                .entry((player, self.total_bots_player.entry(player).read()))
                .write(bot_address);
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
