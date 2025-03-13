#[starknet::contract]
mod l2_registry {
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, SyscallResultTrait, syscalls};

    #[storage]
    struct Storage {
        bridge: ContractAddress,
        l3Registry: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, bridge: ContractAddress, l3Registry: ContractAddress) {
        self.bridge.write(bridge);
        self.l3Registry.write(l3Registry);
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
    fn get_bridge(ref self: ContractState) -> ContractAddress {
        return self.bridge.read();
    }

    #[external(v0)]
    fn get_l3_registry(ref self: ContractState) -> ContractAddress {
        return self.l3Registry.read();
    }
}
