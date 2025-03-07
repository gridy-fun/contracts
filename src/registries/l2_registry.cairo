#[starknet::contract]
mod l3_registry {
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, EthAddress, SyscallResultTrait, syscalls};

    #[storage]
    struct Storage {
        bridge: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, bridge: ContractAddress) {
        self.bridge.write(bridge);
    }


    #[external(v0)]
    fn on_receive(
        ref self: ContractState,
        l2_token: ContractAddress,
        amount: u256,
        depositor: EthAddress,
        message: Span<felt252>,
    ) {
        let token = ERC20ABIDispatcher { contract_address: l2_token };
        token.approve(self.bridge.read(), amount);
        let deposit_with_message_selector = selector!("deposit_with_message");

        syscalls::call_contract_syscall(self.bridge.read(), deposit_with_message_selector, message)
            .unwrap_syscall();
    }
}
