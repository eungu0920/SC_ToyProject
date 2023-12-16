// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title 현재 진행중인 챌린지 storage
contract OngoingChallengeStorage {
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