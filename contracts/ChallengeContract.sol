// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ChallengeStorage.sol";
import "./TimestampConversion.sol";
import "./StakingLibrary.sol";

/**
 * @title A Challenge Dapp for people
 * @author Gray Choi (eungu0920@korea.ac.kr)
 * @notice Implement functionality for registering challenges, verifying participants, and distributing rewards.
 * @dev This contract is not exactly complete yet. don't use this
 */
contract ChallengeContract is ChallengeStorage {
    using StakingLibrary for uint256;
    using TimestampConversion for uint;

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
        admin = msg.sender;
    }

    mapping(uint => mapping(address => uint)) public check;
    mapping(uint => mapping(address => uint)) public lastCheck;
    mapping(uint => mapping(address => bool)) public participate;
    mapping(uint => mapping(address => bool)) public claimed;
    
    event ChallengeCreated(uint challengeId, uint32 duration, string challengeName, uint entryAmount, address creator);
    event ChallengeJoined(uint challengeId, address participant);
    event ChallengeCompleted(uint challengeId);
    event ChallengeClosureScheduled(uint challengeId, uint closureDate);
    event ChallengeRewardClaimed(uint challengeId, address participant);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can call this function.");
        _;
    }

    modifier validChallengeIdWithApplication(uint _challengeId) {
        require(_challengeId < challenges.length, "Invalid challenge ID");
        require(challenges[_challengeId].canApplication, "The application period has expired.");
        _;
    }

    modifier validChallengeIdWithCompleted(uint _challengeId) {
        require(_challengeId < challenges.length, "Invalid challenge ID");
        require(!challenges[_challengeId].completed, "Challenge already completed");    
        _;
    }

    modifier validChallengeId(uint _challengeId) {
        require(_challengeId < challenges.length, "Invalid challenge ID");
        _;
    }

    /**
     * @notice set a new admin
     * @param _newAdmin address of new admin
     */
    function setAdmin(address _newAdmin) external onlyAdmin {
        admin = _newAdmin;
    }

    /**
     * @notice 챌린지를 시작하는 함수
     */
    function runChallenge(uint _challengeId) external onlyAdmin {
        // 신청기간 마감 이후 실행
        require(block.timestamp > challenges[_challengeId].applicationDeadline, "The application period has expired.");

        challenges[_challengeId].canApplication = false;
        challenges[_challengeId].totalAmount.stakingChallengeAmount();
    }

    /**
     * @notice 챌린지를 종료하는 함수
     */
    function closeChallenge(uint _challengeId) external onlyAdmin {
        require(block.timestamp >= challenges[_challengeId].applicationDeadline + challenges[_challengeId].duration, "Challenge duration not over yet");
        _closeChallenge(_challengeId);
    }

    /**
     * @notice 챌린지가 끝날 때, unstaking 신청을 한 후, 기간이 지난 후에 unstaking 신청한 물량을 받아옴.
     */
    function withdrawalReward(uint _challengeId) external {
        require(challenges[_challengeId].completed, "challenge isn't completed");

        challenges[_challengeId].totalAmount.withdrawal();
    }

    /**
     * @notice 챌린지 이름과 챌린지 기간, 참가비용을 매개변수로 받음
     */
    function createChallenge(string memory _challengeName, uint32 _duration, uint _entryAmount) external {
        require(_entryAmount > 0, "Entry amount should be greater than 0");
        require(_duration >= 86400, "The duration must be at least 1 day.");
        require(token.allowance(msg.sender, address(this)) >= _entryAmount, "Not enough token allowance");
        require(token.transferFrom(msg.sender, address(this), _entryAmount), "Failed to transfer tokens");

        uint todaySecond = block.timestamp % 86400;
        uint remainToday = 86400 - todaySecond;
        uint tomorrowNineth = 75600;

        Challenge memory newChallenge = Challenge({
            creator : msg.sender,
            challengeName : _challengeName,
            entryAmount : _entryAmount,
            totalAmount : _entryAmount,
            creationTime : block.timestamp,
            applicationDeadline : block.timestamp + remainToday + tomorrowNineth,
            duration : _duration,
            canApplication : true,
            completed : false,
            numOfWakeUpCheckToWin : _duration / uint32(86400),
            numOfWinners : 0
        });

        uint challengeId = challenges.length;
        challenges.push(newChallenge);

        participate[challengeId][msg.sender] = true;

        emit ChallengeCreated(challengeId, _duration, _challengeName, _entryAmount, msg.sender);
        emit ChallengeClosureScheduled(challengeId, newChallenge.applicationDeadline + _duration);
    }

    /**
     * @notice 참가신청기간은 만들어진 다음날 오후 9시까지.
     */
    function joinChallenge(uint _challengeId) public validChallengeIdWithCompleted(_challengeId) {
        (uint appYear, uint appMonth, uint appDay,,) = challenges[_challengeId].applicationDeadline.timestampToDate();
        (uint crrYear, uint crrMonth, uint crrDay, uint crrHour,) = block.timestamp.timestampToDate();

        // 오후 21시 전 이면 신청 가능
        require(crrYear < appYear || crrMonth < appMonth || crrDay < appDay || crrHour < 21, "The application period has expired.");
        require(!participate[_challengeId][msg.sender], "You've already joined.");
        require(token.balanceOf(msg.sender) >= challenges[_challengeId].entryAmount, "Insufficient entry amount");

        require(token.allowance(msg.sender, address(this)) >= challenges[_challengeId].entryAmount, "Not enough token allowance");
        require(token.transferFrom(msg.sender, address(this), challenges[_challengeId].entryAmount), "Failed to transfer tokens");

        emit ChallengeJoined(_challengeId, msg.sender);
        participate[_challengeId][msg.sender] = true;
        challenges[_challengeId].totalAmount += challenges[_challengeId].entryAmount;
    }

    /**
     * @notice 현재 진행중인 챌린지만 반환하는 함수이며, 참가 신청이 가능한 챌린지만 반환하는 방식으로 수정할 예정
     * @return 현재 진행중인 챌린지배열 반환
     */
    function getCurrentChallenges() public view returns (OngoingChallenge[] memory) {
        uint ongoingCount = 0;
        // 현재 진행 중인 챌린지 수 계산
        for (uint i = 0; i < challenges.length; i++) {
            if (!challenges[i].completed) {
                ongoingCount++;
            }
        }

        // 현재 진행 중인 챌린지 정보 저장할 배열 선언
        OngoingChallenge[] memory ongoingChallenges = new OngoingChallenge[](ongoingCount);
        uint index = 0;

        // 현재 진행 중인 챌린지 정보를 배열에 저장
        for (uint i = 0; i < challenges.length; i++) {
            if (!challenges[i].completed) {
                (uint year, uint month, uint day,,) = (challenges[i].applicationDeadline + challenges[i].duration).timestampToDate();
                (uint appYear, uint appMonth, uint appDay,,) = challenges[i].applicationDeadline.timestampToDate();
                ongoingChallenges[index] = OngoingChallenge({
                    id: i,
                    challengeName: challenges[i].challengeName,
                    entryAmount: challenges[i].entryAmount,
                    currentTotalAmount: challenges[i].totalAmount,
                    appDeadline: [appYear, appMonth, appDay, 21],
                    dueDate: [year, month, day, 21]
                });
                index++;
            }
        }

        return ongoingChallenges;
    }

    /**
     * @notice 기상 체크하는 함수 (6AM ~ 6:05AM)
     * @custom:todo 자동으로 실행 시킬 수 있기 때문에 오프체인에서 처리하는 다른 방식으로 변경해야함
     */
    function wakeUpCheck(uint _challengeId) public validChallengeIdWithCompleted(_challengeId) {
        require(participate[_challengeId][msg.sender], "You're not a participant of this challenge.");
        (uint lastYear, uint lastMonth, uint lastDay,,) = lastCheck[_challengeId][msg.sender].timestampToDate();
        (uint currentYear, uint currentMonth, uint currentDay, uint currentHour, uint currentMinute) = block.timestamp.timestampToDate();

        require(currentYear > lastYear || currentMonth > lastMonth || currentDay > lastDay, "You've already checked today.");
        require(currentHour == 6 && currentMinute <= 5, "You've failed today's mission.");

        check[_challengeId][msg.sender]++;
        lastCheck[_challengeId][msg.sender] = block.timestamp;

        if(check[_challengeId][msg.sender] == challenges[_challengeId].numOfWakeUpCheckToWin) {
            challenges[_challengeId].numOfWinners++;
        }
    }

    /**
     * @notice 상금을 클레임하는 함수
     */
    function claimRewards(uint _challengeId) public validChallengeId(_challengeId) {
        require(challenges[_challengeId].completed, "Challenge isn't completed yet.");
        require(participate[_challengeId][msg.sender], "You're not a participant of this challenge.");
        require(!claimed[_challengeId][msg.sender], "Already claimed");
        require(check[_challengeId][msg.sender] == challenges[_challengeId].numOfWakeUpCheckToWin, "You didn't win this challenge.");

        uint distributeRewards = challenges[_challengeId].totalAmount / challenges[_challengeId].numOfWinners;

        require(token.transfer(msg.sender, distributeRewards), "Reward claim failed.");
        claimed[_challengeId][msg.sender] = true;

        emit ChallengeRewardClaimed(_challengeId, msg.sender);
    }

    /**
     * @notice 챌린지에 쓰이는 토큰 주소를 변경하는 함수
     */
    function setTokenAddress(address _newTokenAddress) public onlyAdmin {
        require(_newTokenAddress != address(0), "Invalid address.");
        token = IERC20(_newTokenAddress);
    }

    /**
     * @notice 챌린지는 오후 9시에 마감
     */
    function _closeChallenge(uint _challengeId) internal validChallengeIdWithCompleted(_challengeId) {
        uint closeTime = challenges[_challengeId].applicationDeadline + challenges[_challengeId].duration;

        (uint crrYear, uint crrMonth, uint crrDay, uint crrHour,) = block.timestamp.timestampToDate();        
        (uint closeYear, uint closeMonth, uint closeDay,,) = closeTime.timestampToDate();

        // 챌린지가 안끝났을 때.
        require(crrYear > closeYear || crrMonth > closeMonth || crrDay > closeDay || crrHour >= 21, "Challenge duration not over yet.");

        // 톤 언스테이킹
        (challenges[_challengeId].totalAmount * 1000000000).unstakingChallengeAmount();

        challenges[_challengeId].completed = true;
        emit ChallengeCompleted(_challengeId);
    }
}