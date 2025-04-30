// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Claim is Ownable {
    address public usdc;
    mapping(address => uint256) public claims;
    mapping(address => bool) public isClaimed;
    
    constructor(address _usdc) Ownable(msg.sender) {
        usdc = _usdc;
    }

    function setUsdc(address _usdc) public onlyOwner {
        usdc = _usdc;
    }

    function setClaims(uint256[] calldata newClaims, address[] calldata users) public onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            claims[users[i]] = newClaims[i];
        }
    }

    function claim(address user) public {
        require(!isClaimed[user], "Already claimed");
        require(claims[user] > 0, "No claim");
        isClaimed[user] = true;
        IERC20(usdc).transfer(user, claims[user]);
    }


    function withdraw(uint256 amount) public onlyOwner {
        IERC20(usdc).transfer(msg.sender, amount);
    }
}
