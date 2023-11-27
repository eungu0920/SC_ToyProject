// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TimestampConversion.sol";

/* 
    TODO List:
    1. 참가신청기간 설정
    2. 참가신청기간 끝나면 모인 돈 USDT로 swap 후 staking OR ETH 그대로 높은 이자율 주는 곳에다 staking?
    3. 챌린지를 어떤식으로 인증해야할지
    4. 챌린지가 끝난 후 상금 분배 방식을 정해야함
    5. 챌린지는 신청기간이 끝나면 무조건 진행(1명이여도) -> 만약 최소 인원까지 구현한다면 신청기간 내 참가자가 안모였을 때,
        지갑으로 돌려주는 방식이 아닌 따로 신청자가 claim해서 가스비를 참가자가 지불하고 되가져가는 방식.
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
        uint applicationDeadline;
        uint duration;
        bool completed;
        address[] winners;

        // 아침에 일어나는 챌린지라면 아침에 체크하는식으로?
        mapping(address => uint) check;
    }

    // 현재 진행중인 챌린지를 보여주기 위해서 따로 구조체를 만들었음, Challenge 구조체안에 mapping 때문에 Challenge 구조체를 반환할 수 없어서 따로 만들었음.
    struct OngoingChallenge {
        uint id;
        string challengeName;
        uint entryAmount;
        uint currentTotalAmount;
        uint appYear;
        uint appMonth;
        uint appDay;
        uint appHour;
        uint year;
        uint month;
        uint day;
        uint hour;
    }

    Challenge[] public challenges;

    event ChallengeCreated(uint challengeId, string challengeName, uint entryAmount, address creator);
    event ChallengeJoined(uint challengeId, address participant);
    event ChallengeCompleted(uint challengeId, address[] winners);

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
        newChallenge.applicationDeadline = block.timestamp + 86400; // 참가기간은 24시간
        newChallenge.duration = _duration;
        newChallenge.completed = false;
        newChallenge.winners = new address[](0);

        uint challengeId = challenges.length - 1;
        emit ChallengeCreated(challengeId, _challengeName, _entryAmount, msg.sender);

        // 챌린지가 끝날 때
        emit ChallengeClosureScheduled(challengeId, block.timestamp + _duration);
    }

    event ChallengeClosureScheduled(uint challengeId, uint closureTime);

    // 챌린지가 끝나면 자동으로 끝나게 만들라 하는데 나중에 다시 수정해야 할 것 같음...
    function automaticallyCloseChallenge(uint _challengeId) public {
        require(block.timestamp >= challenges[_challengeId].creationTime + challenges[_challengeId].duration, "Challenge duration not over yet");
        closeChallenge(_challengeId);
    }

    // join 할 때, 참가신청기간이 지났는지 확인해야함
    function joinChallenge(uint _challengeId) public payable {
        require(_challengeId < challenges.length, "Invalid challenge ID");
        require(block.timestamp < challenges[_challengeId].applicationDeadline, "The application period has passed.");
        require(msg.value == challenges[_challengeId].entryAmount, "Incorrect entry amount");

        challenges[_challengeId].totalAmount += challenges[_challengeId].entryAmount;

        // -----> 여기 변경해야함 <-----
        challenges[_challengeId].check[msg.sender] = msg.value;

        emit ChallengeJoined(_challengeId, msg.sender);
    }

    // 챌린지 종료, 굳이 creator가 종료 하는 것이아니라 자동으로 되게 할 방법을 생각해봐야함.
    function closeChallenge(uint _challengeId) public {
        require(_challengeId < challenges.length, "Invalid challenge ID");
        require(challenges[_challengeId].creator == msg.sender, "Only the challenge creator can close it");
        require(!challenges[_challengeId].completed, "Challenge already completed");

        // 챌린지가 안끝났을 때.
        require(block.timestamp >= challenges[_challengeId].creationTime + challenges[_challengeId].duration, "Challenge duration not over yet");

        // 챌린지가 끝나고 winner를 뽑음.
        uint highestCheck = 0;
        for (uint i = 0; i < challenges[_challengeId].winners.length; i++) {
            address participant = challenges[_challengeId].winners[i];
            if (challenges[_challengeId].check[participant] > highestCheck) {
                highestCheck = challenges[_challengeId].check[participant];
            }
        }

        // winner가 여러명일 경우
        for (uint i = 0; i < challenges[_challengeId].winners.length; i++) {
            address participant = challenges[_challengeId].winners[i];
            if (challenges[_challengeId].check[participant] == highestCheck) {
                challenges[_challengeId].winners.push(participant);
            }
        }

        challenges[_challengeId].completed = true;
        emit ChallengeCompleted(_challengeId, challenges[_challengeId].winners);
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
                (uint year, uint month, uint day, uint hour) = challenges[i].creationTime + challenges[i].duration.timestampToDate();
                (uint appYear, uint appMonth, uint appDay, uint appHour) = challenges[i].applicationDeadline.timestampToDate();
                ongoingChallenges[index] = OngoingChallenge({
                    id: i,
                    challengeName: challenges[i].challengeName,
                    entryAmount: challenges[i].entryAmount,
                    currentTotalAmount: challenges[i].totalAmount,
                    appYear: appYear,
                    appMonth: appMonth,
                    appDay: appDay,
                    appHour: appHour,
                    year: year,
                    month: month,
                    day: day,
                    hour: hour
                });
                index++;
            }
        }

        return ongoingChallenges;
    }
}
