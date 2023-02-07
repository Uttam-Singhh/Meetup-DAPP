const hre = require("hardhat");

const main = async () => {
  const rsvpContractFactory = await hre.ethers.getContractFactory('Meetup');
  const rsvpContract = await rsvpContractFactory.deploy();
  await rsvpContract.deployed();
  console.log("Contract deployed to:", rsvpContract.address);

  const [deployer, address1, address2] = await hre.ethers.getSigners();

  let deposit = hre.ethers.utils.parseEther("1")
  let maxCapacity = 3
  let timestamp = 1718926200
  let meetCID = "bafybeibhwfzx6oo5rymsxmkdxpmkfwyvbjrrwcl7cekmbzlupmp5ypkyfi"
 
  let txn = await rsvpContract.createNewMeet(timestamp, deposit, maxCapacity, meetCID)
  let wait = await txn.wait()
  console.log("NEW EVENT CREATED:", wait.events[0].event, wait.events[0].args)

  let meetID = wait.events[0].args.meetID
  console.log("EVENT ID:", meetID)

  txn = await rsvpContract.createNewRSVP(meetID, {value: deposit})
  wait = await txn.wait()
  console.log("NEW RSVP:", wait.events[0].event, wait.events[0].args)

  txn = await rsvpContract.connect(address1).createNewRSVP(meetID, {value: deposit})
  wait = await txn.wait()
  console.log("NEW RSVP:", wait.events[0].event, wait.events[0].args)

  txn = await rsvpContract.connect(address2).createNewRSVP(meetID, {value: deposit})
  wait = await txn.wait()
  console.log("NEW RSVP:", wait.events[0].event, wait.events[0].args)

  txn = await rsvpContract.confirmAllAttendees(meetID)
  wait = await txn.wait()
  wait.events.forEach(event => console.log("CONFIRMED:", event.args.attendeeAddress))

  // wait 10 years
  await hre.network.provider.send("evm_increaseTime", [15778800000000])

  txn = await rsvpContract.withdrawUnclaimedDeposits(meetID)
  wait = await txn.wait()

  // this fails - not authorized
  // txn = await rsvpContract.connect(address1).confirmAttendee(meetID, address1.address)
  // wait = await txn.wait()
  
};

const runMain = async () => {
  try {
    await main();
    process.exit(0);
  } catch (error) {
    console.log(error);
    process.exit(1);
  }
};

runMain();