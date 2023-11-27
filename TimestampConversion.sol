// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TimestampConversion {
    // 챌린지 종료 및 참가 신청기간의 날짜, 시간 계산 함수
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