// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TimestampConversion.sol";

/* 
    TODO List:
    1. 참가신청기간 설정 / 언제 create되던, 다음날 오후9시 신청 마감 [V]
    2. 참가신청기간 끝나면 모인 돈 USDT로 swap 후 staking OR ETH 그대로 높은 이자율 주는 곳에다 staking?
    3. 챌린지를 어떤식으로 인증해야할지 -> 일단 아침 기상 챌린지로 -> 6AM ~ 6:05AM 안에 기상 인증 체크
    4. 챌린지가 끝난 후 상금 분배 방식을 정해야함 -> 리워드 분배 함수
    5. 챌린지는 신청기간이 끝나면 무조건 진행(1명이여도) -> 만약 최소 인원까지 구현한다면 신청기간 내 참가자가 안모였을 때,
        지갑으로 돌려주는 방식이 아닌 따로 신청자가 claim해서 가스비를 참가자가 지불하고 되가져가는 방식.
    6. 
*/

contract ChallengeContract {
    using TimestampConversion for uint;
    // 챌린지: creator, name, entry, totalAmount, creation time, application deadline(24hours), duration, isCompleted, winners, numOfParticipant
    struct Challenge {
        address creator;
        string challengeName;
        uint entryAmount;
        uint totalAmount;
        uint creationTime;
        uint applicationDeadline; // and start time
        uint duration;
        bool completed;

        uint numOfWakeUpCheckToWin;

        // 마지막 check 때 numOfWinners도 같이 갱신해서 이 변수로 total reward를 나눠주려고함.
        uint numOfWinners;

        // 아침에 일어나는 챌린지라면 아침에 체크하는식으로?
        mapping(address => uint) check;
        mapping(address => uint) lastCheck;
        mapping(address => bool) participate;
        mapping(address => bool) claimed;
    }

    // 현재 진행중인 챌린지를 보여주기 위해서 따로 구조체를 만들었음, Challenge 구조체안에 mapping 때문에 Challenge 구조체를 반환할 수 없어서 따로 만들었음.
    // Challenge id, name, entry amount, total amount, application deadline date, due date, number of participants
    struct OngoingChallenge {
        uint id;
        string challengeName;
        uint entryAmount;
        uint currentTotalAmount;
        uint[4] appDeadline; // year, month, day, hour
        uint[4] dueDate; // same as above
    }

    Challenge[] public challenges;

    event ChallengeCreated(uint challengeId, string challengeName, uint entryAmount, address creator);
    event ChallengeJoined(uint challengeId, address participant);
    event ChallengeCompleted(uint challengeId);
    event ChallengeClosureScheduled(uint challengeId, uint closureDate);
    event ChallengeRewardClaimed(uint challengeId, address participant);

    modifier validChallengeIdWithCompleted(uint _challengeId) {
        require(_challengeId < challenges.length, "Invalid challenge ID");
        require(!challenges[_challengeId].completed, "Challenge already completed");    
        _;
    }

    modifier validChallengeId(uint _challengeId) {
        require(_challengeId < challenges.length, "Invalid challenge ID");
        _;
    }

    function createChallenge(string memory _challengeName, uint _duration, uint _entryAmount) public payable {
        require(_entryAmount > 0, "Entry amount should be greater than 0");
        require(msg.value == _entryAmount, "entry amount should be sent as value with the transaction");

        challenges.push();
        Challenge storage newChallenge = challenges[challenges.length - 1];
        newChallenge.creator = msg.sender;
        newChallenge.challengeName = _challengeName;
        newChallenge.entryAmount = _entryAmount;
        newChallenge.totalAmount += _entryAmount;
        newChallenge.creationTime = block.timestamp;
        newChallenge.applicationDeadline = block.timestamp + 1 days; // 참가기간은 다음날 오후 9시 전까지
        newChallenge.duration = _duration;
        newChallenge.completed = false;
        newChallenge.numOfWakeUpCheckToWin = _duration / 86400; // 예(1일 : 86400초 진행 => winner list에 들기 위한 횟수 : 1번)
        newChallenge.participate[msg.sender] = true;

        uint challengeId = challenges.length - 1;
        emit ChallengeCreated(challengeId, _challengeName, _entryAmount, msg.sender);
        emit ChallengeClosureScheduled(challengeId, newChallenge.applicationDeadline + _duration);
    }    

    // 챌린지가 끝나면 자동으로 끝나게 만들라 하는데 나중에 다시 수정해야 할 것 같음...
    function automaticallyCloseChallenge(uint _challengeId) public {
        require(block.timestamp >= challenges[_challengeId].applicationDeadline + challenges[_challengeId].duration, "Challenge duration not over yet");
        _closeChallenge(_challengeId);
    }

    // join 할 때, 참가신청기간이 지났는지 확인해야함, 참가신청기간은 다음날 오후 9시 전까지만
    function joinChallenge(uint _challengeId) public payable validChallengeIdWithCompleted(_challengeId) {
        (uint appYear, uint appMonth, uint appDay,,) = challenges[_challengeId].applicationDeadline.timestampToDate();
        (uint crrYear, uint crrMonth, uint crrDay, uint crrHour,) = block.timestamp.timestampToDate();

        require(crrYear < appYear || crrMonth < appMonth || crrDay < appDay || crrHour < 21, "The application period has expired."); // 오후 21시 전 이면 신청 가능
        require(!challenges[_challengeId].participate[msg.sender], "You've already joined.");
        require(msg.value == challenges[_challengeId].entryAmount, "Incorrect entry amount");

        emit ChallengeJoined(_challengeId, msg.sender);
        challenges[_challengeId].participate[msg.sender] = true;
        challenges[_challengeId].totalAmount += challenges[_challengeId].entryAmount;

    }

    // 챌린지 종료, 굳이 creator가 종료 하는 것이아니라 자동으로 되게 할 방법을 생각해봐야함.
    function _closeChallenge(uint _challengeId) internal validChallengeIdWithCompleted(_challengeId) {
        require(challenges[_challengeId].creator == msg.sender, "Only the challenge creator can close it");        

        uint closeTime = challenges[_challengeId].applicationDeadline + challenges[_challengeId].duration;

        (uint crrYear, uint crrMonth, uint crrDay, uint crrHour,) = block.timestamp.timestampToDate();        
        (uint closeYear, uint closeMonth, uint closeDay,,) = closeTime.timestampToDate();

        // 챌린지가 안끝났을 때.
        require(crrYear > closeYear || crrMonth > closeMonth || crrDay > closeDay || crrHour >= 21, "Challenge duration not over yet.");

        /*
        챌린지가 끝나고 winner를 뽑을 때,
        챌린지가 7일동안 진행된 경우 7일을 모두 체크한 사람이 winners list에 들어감.
        for문 두 번 반복할 필요 없이 한번만 사용하고 챌린지를 모두 참여 완료한 사람만 상금을 분배하는 방식으로 진행.
        즉 하루만 실패해도 상금이 날라감(아니면 리워드 분배방식을 달성 퍼센트별로 설정해야하는데 이거는 지금하기 어려울 것이라고 생각됨)
        => close 될 때, winners를 뽑는게 아닌 매번 체크해서 
        */

        challenges[_challengeId].completed = true;
        emit ChallengeCompleted(_challengeId);
    }

    // 현재 진행중인 챌린지를 반환하는 함수가 있어서 삭제해도 될 듯?
    function getChallengeCount() public view returns (uint) {
        return challenges.length;
    }

    // TODO: 현재 진행중인 챌린지만 반환, challengeName, entry amount, deadlines, number of current participants(?), total amount(?), etc
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

    // 아침 6시에서 6시 5분 안에 함수를 실행시켜야함.
    // lastCheck를 통해서 하루에 한번만 체크를 할 수 있음.
    function wakeUpCheck(uint _challengeId) public validChallengeIdWithCompleted(_challengeId) {
        require(challenges[_challengeId].participate[msg.sender], "You're not a participant of this challenge.");
        (uint lastYear, uint lastMonth, uint lastDay,,) = challenges[_challengeId].lastCheck[msg.sender].timestampToDate();
        (uint currentYear, uint currentMonth, uint currentDay, uint currentHour, uint currentMinute) = block.timestamp.timestampToDate();

        require(currentYear > lastYear || currentMonth > lastMonth || currentDay > lastDay, "You've already checked today.");
        require(currentHour == 6 && currentMinute <= 5, "You've failed today's mission.");

        challenges[_challengeId].check[msg.sender]++;
        challenges[_challengeId].lastCheck[msg.sender] = block.timestamp;

        if(challenges[_challengeId].check[msg.sender] == challenges[_challengeId].numOfWakeUpCheckToWin) {
            challenges[_challengeId].numOfWinners++;
        }
    }

    // 상금 클레임
    function claimRewards(uint _challengeId) public validChallengeId(_challengeId) {
        require(challenges[_challengeId].completed, "Challenge isn't completed yet.");
        require(!challenges[_challengeId].claimed[msg.sender], "Already claimed");
        require(challenges[_challengeId].check[msg.sender] == challenges[_challengeId].numOfWakeUpCheckToWin, "You didn't win this challenge.");

        uint distributeRewards = challenges[_challengeId].totalAmount / challenges[_challengeId].numOfWinners;

        challenges[_challengeId].claimed[msg.sender] = true;
        payable(msg.sender).transfer(distributeRewards);

        emit ChallengeRewardClaimed(_challengeId, msg.sender);
    }

}
