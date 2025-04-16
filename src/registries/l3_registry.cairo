#[starknet::contract]
mod l3_registry {
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::access::ownable::OwnableComponent;
    use OwnableComponent::InternalTrait;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ClassHash, ContractAddress, syscalls};


    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        gridy_address: ContractAddress,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, gridy_address: ContractAddress, owner: ContractAddress,
    ) {
        self.gridy_address.write(gridy_address);
        self.ownable.initializer(owner);
    }


    #[external(v0)]
    fn on_receive(
        ref self: ContractState,
        l3_token: ContractAddress,
        amount: u256,
        depositor: ContractAddress,
        message: Span<felt252>,
    ) -> bool {
        let token = ERC20ABIDispatcher { contract_address: l3_token };
        token.approve(self.gridy_address.read(), amount);
        let deploy_bot_selector = selector!("deploy_bot");

        let res = syscalls::call_contract_syscall(
            self.gridy_address.read(), deploy_bot_selector, message,
        );

        assert(res.is_ok(), 'Failed to deploy bot');
        return true;
    }

    #[external(v0)]
    fn set_gridy_address(ref self: ContractState, gridy_address: ContractAddress) {
        self.ownable.assert_only_owner();
        self.gridy_address.write(gridy_address);
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
