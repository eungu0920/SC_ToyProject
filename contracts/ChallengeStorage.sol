// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IERC20.sol";

/// @title 챌린지 storage
contract ChallengeStorage {
    address public admin;
    IERC20 public token;

    Challenge[] public challenges;

    /**
     * @notice Challenge 구조체
     * @param totalAmount 참가자 수 * entryAmount          
     * @param completed Challenge가 끝났는지 확인하는 변수
     * @param applicationDeadline 참가 신청기간이며 Challenge가 생성되고 난 후, 다음날 오후 9시까지 신청이 가능함.
     * @param numOfWakeUpCheckToWin Challenge에서 이기기 위한 달성 횟수
     * @param numOfWinners Challenge의 전체 winner 수, Challenge의 마지막 날 numOfWakeUpCheckToWin와 비교하여 갱신
     * @param check 지갑주소 별 미션체크 변수
     * @param lastCheck 마지막으로 아침 미션을 달성한 시간
     * @param claimed 상금을 클레임 하였는지 확인하기 위한 변수
     */
    struct Challenge {
        address creator;
        string challengeName;
        uint256 entryAmount;
        uint256 totalAmount;
        uint256 creationTime;
        uint applicationDeadline;
        uint duration;
        bool canApplication;
        bool completed;
        uint numOfWakeUpCheckToWin;
        uint numOfWinners;
    }

    struct participant {
        uint check;
        uint lastCheck;
        bool participate;
        bool claimed;
    }

    /**
     * @notice 현재 진행중인 Challenge를 보여주기 위한 구조체
     * @param id 
     */
    struct OngoingChallenge {
        uint id;
        string challengeName;
        uint entryAmount;
        uint currentTotalAmount;
        // year, month, day, hour
        uint[4] appDeadline;
        // same as above
        uint[4] dueDate;
    }
}