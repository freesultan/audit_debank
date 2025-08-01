/*
    Copyright Debank
    SPDX-License-Identifier: BUSL-1.1
*/

pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../../library/UniversalERC20.sol";

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

contract UniAdapter is ReentrancyGuard {
    address public immutable Permit2;
    address public immutable Uni_Router;

    using UniversalERC20 for IERC20;
    using SafeERC20 for IERC20;
    using Address for address;
    using Address for address payable;

    constructor(address approver, address router) {
        Permit2 = approver;
        Uni_Router = router;
    }

    function swapOnAdapter(
        address fromToken,
        address toToken,
        address receipent,
        bytes memory data
    ) external payable nonReentrant {
        uint256 fromTokenAmount = IERC20(fromToken).universalBalanceOf(address(this));
        if (fromToken != UniversalERC20.ETH) {
            // approve
            IERC20(fromToken).forceApprove(Permit2, fromTokenAmount);
            IPermit2(Permit2).approve(fromToken, Uni_Router, SafeCast.toUint160(fromTokenAmount), SafeCast.toUint48(block.timestamp));
            Uni_Router.functionCallWithValue(data, 0);
        } else {
            // For ETH, use fromTokenAmount instead of msg.value to handle fee deduction
            Uni_Router.functionCallWithValue(data, fromTokenAmount);
        }

        // transfer remaining tokens
        uint256 fromTokenBalance = IERC20(fromToken).universalBalanceOf(address(this));
        if (fromTokenBalance > 0) {
            IERC20(fromToken).universalTransfer(payable(receipent), fromTokenBalance);
        }

        uint256 toTokenBalance = IERC20(toToken).universalBalanceOf(address(this));
        if (toTokenBalance > 0) {
            IERC20(toToken).universalTransfer(payable(msg.sender), toTokenBalance);
        }
    }
}
