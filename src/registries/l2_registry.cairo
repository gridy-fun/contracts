#[starknet::contract]
mod l2_registry {
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::access::ownable::OwnableComponent;
    use OwnableComponent::InternalTrait;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ClassHash, ContractAddress, SyscallResultTrait, syscalls};


    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        bridge: ContractAddress,
        l3Registry: ContractAddress,
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
        ref self: ContractState,
        bridge: ContractAddress,
        l3Registry: ContractAddress,
        owner: ContractAddress,
    ) {
        self.bridge.write(bridge);
        self.l3Registry.write(l3Registry);
        self.ownable.initializer(owner);
    }

    #[external(v0)]
    fn on_receive(
        ref self: ContractState,
        l2_token: ContractAddress,
        amount: u256,
        depositor: ContractAddress,
        message: Span<felt252>,
    ) -> bool {
        let token = ERC20ABIDispatcher { contract_address: l2_token };
        token.approve(self.bridge.read(), amount);
        let deposit_with_message_selector = selector!("deposit_with_message");

        let mut calldata = array![];
        l2_token.serialize(ref calldata);
        amount.serialize(ref calldata);
        self.l3Registry.read().serialize(ref calldata);
        message.serialize(ref calldata);

        syscalls::call_contract_syscall(
            self.bridge.read(), deposit_with_message_selector, calldata.span(),
        )
            .unwrap_syscall();
        return true;
    }

    #[external(v0)]
    fn get_bridge(self: @ContractState) -> ContractAddress {
        return self.bridge.read();
    }

    #[external(v0)]
    fn get_l3_registry(self: @ContractState) -> ContractAddress {
        return self.l3Registry.read();
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
