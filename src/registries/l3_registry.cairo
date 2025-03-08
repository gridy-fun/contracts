#[starknet::contract]
mod l3_registry {
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, syscalls};

    #[storage]
    struct Storage {
        gridy_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, gridy_address: ContractAddress) {
        self.gridy_address.write(gridy_address);
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
}
