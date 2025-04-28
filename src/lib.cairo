pub mod bot {
    pub mod main;
    pub mod interface;

    pub use interface::{IBotContract};
}

pub mod game {
    pub mod interface;
    pub mod main;
    pub mod types;
}

pub mod mocks {
    pub mod account_mock;
}

pub mod registries {
    pub mod l2_registry;
    pub mod l3_registry;
}

pub mod claims {
    pub mod main;
    pub mod interface;
}

pub mod constants;

