#[starknet::contract]
mod Claim {
    use core::hash::{HashStateExTrait, HashStateTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerWriteAccess,
        StorableStoragePointerReadAccess,
    };
    use starknet::{ContractAddress, ClassHash};
    use gridy::claims::interface::{IClaimContract, IClaimAdmin};
    use openzeppelin::merkle_tree::{merkle_proof::verify, hashes::PedersenCHasher};

    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use core::pedersen::{PedersenTrait, pedersen};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        merkle_root: felt252,
        token_address: IERC20Dispatcher,
        has_claimed: Map<ContractAddress, bool>,
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
    }

    pub mod Error {
        pub const InvalidProof: felt252 = 'Proof not verified';
        pub const AlreadyClaimed: felt252 = 'Already claimed';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_address: ContractAddress,
        owner: ContractAddress,
        merkle_root: felt252,
    ) {
        // Set the initial owner of the contract
        self.ownable.initializer(owner);
        self.token_address.write(IERC20Dispatcher { contract_address: token_address });
        self.merkle_root.write(merkle_root);
    }

    #[abi(embed_v0)]
    impl IClaimContractImpl of IClaimContract<ContractState> {
        fn claim(
            ref self: ContractState, proof: Span<felt252>, address: ContractAddress, amount: u128,
        ) {
            assert(self.verify(proof, address, amount), 'Verifier: invalid proof');

            assert(self.has_claimed.read(address) == false, 'Already claimed');
            
            let token = self.token_address.read();
            token.transfer(address, amount.into());

            self.has_claimed.write(address, true);
        }

        fn get_token_address(self: @ContractState) -> ContractAddress {
            self.token_address.read().contract_address
        }

        fn verify(
            self: @ContractState, proof: Span<felt252>, address: ContractAddress, amount: u128,
        ) -> bool {
            // Leaves hashes and internal nodes hashes are computed differently
            // to avoid second pre-image attacks.
            let leaf_hash = self.leaf_hash(address, amount);

            return verify::<PedersenCHasher>(proof, self.merkle_root.read(), leaf_hash);
        }

        fn leaf_hash(self: @ContractState, address: ContractAddress, amount: u128) -> felt252 {
            let hash_state = PedersenTrait::new(0);
            pedersen(
                0, hash_state.update_with(address).update_with(amount).update_with(2).finalize(),
            )
        }
    }

    #[abi(embed_v0)]
    impl IClaimAdminImpl of IClaimAdmin<ContractState> {
        fn withdraw_tokens(ref self: ContractState, amount: u128) {
            self.ownable.assert_only_owner();
            let token = self.token_address.read();
            token.transfer(self.ownable.owner(), amount.into());
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
