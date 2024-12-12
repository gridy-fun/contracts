pub mod bot {
    pub mod main;
    pub mod interface;

    pub use interface::{
        IBotContract
    };
}

pub mod game {
    pub mod interface;
    pub mod main;
}

pub mod mocks {
    pub mod account_mock;
}

pub mod constants;