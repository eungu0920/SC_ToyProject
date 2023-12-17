const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ChallengeContract", function () {
  let ChallengeContract, challengeContract;
  let DummyToken, dummyToken;
  let owner, user1, user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
  
    // 더미 ERC20 토큰 배포 및 민팅
    DummyToken = await ethers.getContractFactory("DummyToken");
    dummyToken = await DummyToken.deploy();
    await dummyToken.deployed();
  
    // 사용자에게 토큰 민팅
    await dummyToken.mint(user1.address, ethers.utils.parseEther("1000"));
    await dummyToken.mint(user2.address, ethers.utils.parseEther("1000"));
  
    // ChallengeContract 배포
    ChallengeContract = await ethers.getContractFactory("ChallengeContract");
    challengeContract = await ChallengeContract.deploy(dummyToken.address);
    await challengeContract.deployed();
  
    // ChallengeContract에 토큰 이동 허가
    await dummyToken.connect(user1).approve(challengeContract.address, ethers.utils.parseEther("1000"));
    await dummyToken.connect(user2).approve(challengeContract.address, ethers.utils.parseEther("1000"));
  });

  it("should create a new challenge", async function () {
    // 허가량 확인
    const allowance = await dummyToken.allowance(user1.address, challengeContract.address);
    console.log("Allowance for user1: ", allowance.toString());
    
    await challengeContract.createChallenge("Fitness Challenge", 7, 100);

    const challengeData = await challengeContract.challenges(0);
    expect(challengeData.challengeName).to.equal("Fitness Challenge");
    expect(challengeData.entryAmount).to.equal(100);
  });

  it("should allow users to join a challenge", async function () {
    await challengeContract.createChallenge("Fitness Challenge", 7, 100);

    await challengeContract.connect(user1).joinChallenge(0);
    let isParticipating = await challengeContract.isParticipating(user1.address, 0);
    expect(isParticipating).to.be.true;

    await challengeContract.connect(user2).joinChallenge(0);
    isParticipating = await challengeContract.isParticipating(user2.address, 0);
    expect(isParticipating).to.be.true;
  });

});
