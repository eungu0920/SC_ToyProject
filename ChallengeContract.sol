// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ChallengeContract {
    // 챌린지
    struct Challenge {
        address creator;
        string challengeName;
        uint entryAmount;
        uint creationTime;
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
        uint year;
        uint month;
        uint day;
        uint hour;
    }

    Challenge[] public challenges;

    event ChallengeCreated(uint challengeId, string challengeName, uint betAmount, address creator);
    event ChallengeJoined(uint challengeId, address participant);
    event ChallengeCompleted(uint challengeId, address[] winners);

    function createChallenge(string memory _challengeName, uint _duration, uint _betAmount) public payable {
        require(_betAmount > 0, "Bet amount should be greater than 0");
        require(msg.value == _betAmount, "Bet amount should be sent as value with the transaction");

        challenges.push();
        Challenge storage newChallenge = challenges[challenges.length - 1];
        newChallenge.creator = msg.sender;
        newChallenge.challengeName = _challengeName;
        newChallenge.entryAmount = _betAmount;
        newChallenge.creationTime = block.timestamp;
        newChallenge.duration = _duration;
        newChallenge.completed = false;
        newChallenge.winners = new address[](0);

        uint challengeId = challenges.length - 1;
        emit ChallengeCreated(challengeId, _challengeName, _betAmount, msg.sender);

        // 챌린지가 끝날 때
        emit ChallengeClosureScheduled(challengeId, block.timestamp + _duration);
    }

    event ChallengeClosureScheduled(uint challengeId, uint closureTime);

    // 챌린지가 끝나면 자동으로 끝나게 만들라 하는데 나중에 다시 수정해야 할 것 같음...
    function automaticallyCloseChallenge(uint _challengeId) public {
        require(block.timestamp >= challenges[_challengeId].creationTime + challenges[_challengeId].duration, "Challenge duration not over yet");
        closeChallenge(_challengeId);
    }

    function joinChallenge(uint _challengeId) public payable {
        require(_challengeId < challenges.length, "Invalid challenge ID");
        require(!challenges[_challengeId].completed, "Challenge is already completed");
        require(msg.value == challenges[_challengeId].entryAmount, "Incorrect bet amount");
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
                (uint year, uint month, uint day, uint hour) = timestampToDate(challenges[i].creationTime + challenges[i].duration);
                ongoingChallenges[index] = OngoingChallenge({
                    id: i,
                    challengeName: challenges[i].challengeName,
                    entryAmount: challenges[i].entryAmount,
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

    // 날짜, 시간 계산 함수
    function timestampToDate(uint timestamp) internal pure returns (uint year, uint month, uint day, uint hour) {
        uint256 KST = 9 * 3600; // UTC+9 변환

        uint256 _timestamp = timestamp + KST; // 한국 시간으로 변환

        uint256 secondsInDay = 86400;
        uint256 secondsInYear = 31536000;
        uint256 secondsInLeapYear = 31622400;

        uint256 epochYear = 1970;

        // 년 계산
        uint256 secondsAccountedFor = 0;
        uint256 numLeapYears = 0;
        while (secondsAccountedFor + secondsInYear <= _timestamp) {
            if ((epochYear % 4 == 0) && ((epochYear % 100 != 0) || (epochYear % 400 == 0))) {
                secondsAccountedFor += secondsInLeapYear;
                numLeapYears++;
            } else {
                secondsAccountedFor += secondsInYear;
            }
            epochYear++;
        }
        year = epochYear;

        // Day 계산
        uint8[12] memory daysPerMonth = [
            uint8(31), uint8(28), uint8(31),
            uint8(30), uint8(31), uint8(30),
            uint8(31), uint8(31), uint8(30),
            uint8(31), uint8(30), uint8(31)
        ];

        uint256 monthCounter = 0;
        while (true) {
            uint256 daysUntilMonth = 0;
            if (monthCounter == 12) {
                break;
            }

            daysUntilMonth += uint256(daysPerMonth[monthCounter]) * secondsInDay;
            if (_timestamp < secondsAccountedFor + daysUntilMonth) {
                break;
            }

            secondsAccountedFor += daysUntilMonth;
            monthCounter++;
        }
        month = monthCounter + 1;

        // day 계산
        day = (_timestamp - secondsAccountedFor) / secondsInDay + 1;

        // hour 계산
        uint256 remainingSeconds = _timestamp - secondsAccountedFor + secondsInDay;
        hour = (remainingSeconds % secondsInDay) / 3600;
    }


}
