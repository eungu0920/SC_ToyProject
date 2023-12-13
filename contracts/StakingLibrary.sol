// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TON 스테이킹과 관련된 함수를 사용하는 라이브러리 입니다.
 * @notice 클레임 하는 함수를 구현해야 합니다.
 */
library StakingLibrary {
    address constant CONTRACT_ADDRESS = 0x68c1F9620aeC7F2913430aD6daC1bb16D8444F00;
    address constant DEPOSIT_MANAGER = 0x0e1EF78939F9d3340e63A7a1077d50999CC6B64f;
    address constant LAYER2 = 0x1f4aEf3A04372cF9D738d5459F31950A53969cA3;
    
     /**
     * @notice 챌린지의 totalAmount를 _value로 받아서 스테이킹
     */
    function stakingChallengeAmount(uint256 _value) internal {
        address spender = 0xe86fCf5213C785AcF9a8BFfEeDEfA9a2199f7Da6; 

        bytes memory _data = abi.encode(DEPOSIT_MANAGER, LAYER2);

        (bool success,) = CONTRACT_ADDRESS.call(
            abi.encodeWithSignature("approveAndCall(address, uint256, bytes)", spender, _value, _data)
        );

        require(success, "External call failed");
    }

    /**
     * @notice 언스테이킹(기간7일?)
     * 1000000000000000000000000000(1) 10^27
     */
    function unstakingChallengeAmount(uint256 _value) internal {
        (bool success,) = DEPOSIT_MANAGER.call(
            abi.encodeWithSignature("requestWithdrawal(address, uint256)", LAYER2, _value)
        );

        require(success, "External call failed");
    }

    /**
     * @notice 스테이킹 withdrawal, _value 만큼 인출, true는 WTON말고 TON으로 받음
     */
    function withdrawal(uint _value) internal {
        (bool success,) = DEPOSIT_MANAGER.call(
            abi.encodeWithSignature("processRequests(address, uint256, bool)", LAYER2, _value, true)
        );

        require(success, "External call failed");
    }
}