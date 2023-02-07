// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract Meetup {

    event NewMeetCreated(
    bytes32 meetID,
    address creatorAddress,
    uint256 meetTimestamp,
    uint256 maxCapacity,
    uint256 deposit,
    string meetCID
);

event NewRSVP(bytes32 meetID, address attendeeAddress);
event ConfirmedAttendee(bytes32 meetID, address attendeeAddress);

event DepositsPaidOut(bytes32 meetID);

    struct CreateMeet{
    bytes32 meetId;
    string meetCID;  //IPFS hash for meet details
    address meetOwner;
    uint256 meetTimestamp;
    uint256 maxCapacity;
    uint256 deposit;
    address[] confirmedRSVPs;
    address[] claimedRSVPs;
    bool paidOut;
    // bytes32 groupId;  
    // string groupCID;
    //uint256 meetCreatedTime
  }

  mapping (bytes32 => CreateMeet) public idToMeet;

  function createNewMeet(
    uint256 meetTimestamp,
    uint256 deposit,
    uint256 maxCapacity,
    string calldata meetCID 
  ) external{
    bytes32 meetId = keccak256(
        abi.encodePacked(
            msg.sender,  //msg.sender is the address of the transaction invoker
            address(this), //address(this) is the address of the contract itself.
            meetTimestamp,
            deposit,
            maxCapacity
        )
    );

    address[] memory confirmedRSVPs;
    address[] memory claimedRSVPs;

    idToMeet[meetId] = CreateMeet(
        meetId,
        meetCID,
        msg.sender,
        meetTimestamp,
        maxCapacity,
        deposit,
        confirmedRSVPs,
        claimedRSVPs,
        false
    );

    emit NewMeetCreated(
    meetId,
    msg.sender,
    meetTimestamp,
    maxCapacity,
    deposit,
    meetCID
);

  }

  function createNewRSVP(bytes32 meetId) external payable{
    CreateMeet storage myMeet = idToMeet[meetId];

    require(msg.value == myMeet.deposit,"Not Enough");

    require(block.timestamp <= myMeet.meetTimestamp, "ALREADY HAPPENED");

    require(
        myMeet.confirmedRSVPs.length < myMeet.maxCapacity,
        "This event has reached capacity"
    );

    for (uint8 i = 0; i < myMeet.confirmedRSVPs.length; i++) {
        require(myMeet.confirmedRSVPs[i] != msg.sender, "ALREADY CONFIRMED");
    }

    myMeet.confirmedRSVPs.push(payable(msg.sender));

    emit NewRSVP(meetId, msg.sender);
  }

  function confirmAttendee(bytes32 meetId, address attendee) public {
    CreateMeet storage myMeet = idToMeet[meetId];
    require(msg.sender == myMeet.meetOwner, "NOT AUTHORIZED");

    // require that attendee trying to check in actually RSVP'd
    address rsvpConfirm;

    for (uint8 i = 0; i < myMeet.confirmedRSVPs.length; i++) {
        if(myMeet.confirmedRSVPs[i] == attendee){
            rsvpConfirm = myMeet.confirmedRSVPs[i];
        }
    }

    require(rsvpConfirm == attendee, "NO RSVP TO CONFIRM");


    // require that attendee is NOT already in the claimedRSVPs list AKA make sure they haven't already checked in
    for (uint8 i = 0; i < myMeet.claimedRSVPs.length; i++) {
        require(myMeet.claimedRSVPs[i] != attendee, "ALREADY CLAIMED");
    }

    // require that deposits are not already claimed by the event owner
    require(myMeet.paidOut == false, "ALREADY PAID OUT");

    // add the attendee to the claimedRSVPs list
    myMeet.claimedRSVPs.push(attendee);

    // sending eth back to the staker `https://solidity-by-example.org/sending-ether`
    (bool sent,) = attendee.call{value: myMeet.deposit}("");

    // if this fails, remove the user from the array of claimed RSVPs
    if (!sent) {
        myMeet.claimedRSVPs.pop();
    }
    require(sent, "Failed to send Ether");

    emit ConfirmedAttendee(meetId, attendee);
}

function confirmAllAttendees(bytes32 meetId) external {
    // look up event from our struct with the meetId
    CreateMeet memory myMeet = idToMeet[meetId];

    // make sure you require that msg.sender is the owner of the event
    require(msg.sender == myMeet.meetOwner, "NOT AUTHORIZED");

    // confirm each attendee in the rsvp array
    for (uint8 i = 0; i < myMeet.confirmedRSVPs.length; i++) {
        confirmAttendee(meetId, myMeet.confirmedRSVPs[i]);
    }
}

function withdrawUnclaimedDeposits(bytes32 meetId) external {
    // look up event
    CreateMeet memory myMeet = idToMeet[meetId];

    // check that the paidOut boolean still equals false AKA the money hasn't already been paid out
    require(!myMeet.paidOut, "ALREADY PAID");

    // check if it's been 7 days past myMeet.eventTimestamp
    require(
        block.timestamp >= (myMeet.meetTimestamp + 7 days),
        "TOO EARLY"
    );

    // only the event owner can withdraw
    require(msg.sender == myMeet.meetOwner, "MUST BE EVENT OWNER");

    // calculate how many people didn't claim by comparing
    uint256 unclaimed = myMeet.confirmedRSVPs.length - myMeet.claimedRSVPs.length;

    uint256 payout = unclaimed * myMeet.deposit;

    // mark as paid before sending to avoid reentrancy attack
    myMeet.paidOut = true;

    // send the payout to the owner
    (bool sent, ) = msg.sender.call{value: payout}("");

    // if this fails
    if (!sent) {
        myMeet.paidOut = false;
    }

    require(sent, "Failed to send Ether");

    emit DepositsPaidOut(meetId);

}
}





