// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../CollectiveCoreUnitTest.t.sol";

/**
 * @notice Contract For Depositing USDT Unit Tests
 */
contract DepositUSDTUnitTest is CollectiveCoreUnitTest {
    function testDepositUSDTRevertsIfAmountIsZero() public {
        vm.startPrank(COSMIC_PROVIDER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__AmountMustBeGreaterThanZero.selector);
        collectiveCoreAvalanche.depositUSDT(ZERO_AMOUNT);
        vm.stopPrank();
    }

    function testDepositUSDTRevertsIfUserBalanceIsLessThanAmountSpecified() public {
        vm.startPrank(COSMIC_PROVIDER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__InsufficientUsdtBalance.selector);
        collectiveCoreAvalanche.depositUSDT(DEPOSIT_USDT_AMOUNT);
        vm.stopPrank();
    }

    function testDepositUSDTUpdatesCosmicProviderAndContractUsdtBalanceDetails()
        public
        depositUSDTToAvalanche(COSMIC_PROVIDER_ONE)
    {
        ICollectiveCore.CosmicProvider memory cosmicProviderDetails =
            collectiveCoreAvalanche.getCosmicProviderDetails(COSMIC_PROVIDER_ONE);
        uint256 unlockPeriod = collectiveCoreAvalanche.getUnlockPeriod(COSMIC_PROVIDER_ONE);

        ICollectiveCore.UsdtBalances memory usdtBalances = collectiveCoreAvalanche.getUsdtBalances();
        assertEq(usdtBalances.Avalanche, DEPOSIT_USDT_AMOUNT);
        assertEq(usdtBalances.Optimism, 0);
        assertEq(usdtBalances.Polygon, 0);

        assertEq(cosmicProviderDetails.aUSDT, DEPOSIT_USDT_AMOUNT);
        assertEq(cosmicProviderDetails.oUSDT, 0);
        assertEq(cosmicProviderDetails.pUSDT, 0);
        assertEq(cosmicProviderDetails.IOU_USDT, DEPOSIT_USDT_AMOUNT);
        assertEq(cosmicProviderDetails.totalUSDT, DEPOSIT_USDT_AMOUNT);
        assertEq(cosmicProviderDetails.unlockPeriod, unlockPeriod);
    }

    function testDepositUSDTUpdatesTheNecessaryCrossChainInformationOnOptimsim()
        public
        depositUSDTToAvalanche(COSMIC_PROVIDER_ONE)
    {
        ICollectiveCore.CosmicProvider memory cosmicProviderDetailsOptimism =
            collectiveCoreOptimism.getCosmicProviderDetails(COSMIC_PROVIDER_ONE);
        uint256 unlockPeriod = collectiveCoreOptimism.getUnlockPeriod(COSMIC_PROVIDER_ONE);

        ICollectiveCore.UsdtBalances memory usdtBalances = collectiveCoreOptimism.getUsdtBalances();
        assertEq(usdtBalances.Avalanche, DEPOSIT_USDT_AMOUNT);
        assertEq(usdtBalances.Optimism, 0);
        assertEq(usdtBalances.Polygon, 0);

        assertEq(cosmicProviderDetailsOptimism.aUSDT, DEPOSIT_USDT_AMOUNT);
        assertEq(cosmicProviderDetailsOptimism.oUSDT, 0);
        assertEq(cosmicProviderDetailsOptimism.pUSDT, 0);
        assertEq(cosmicProviderDetailsOptimism.IOU_USDT, DEPOSIT_USDT_AMOUNT);
        assertEq(cosmicProviderDetailsOptimism.totalUSDT, DEPOSIT_USDT_AMOUNT);
        assertEq(cosmicProviderDetailsOptimism.unlockPeriod, unlockPeriod);
    }

    function testDepositUSDTUpdatesTheNecessaryCrossChainInformationOnPolygon()
        public
        depositUSDTToAvalanche(COSMIC_PROVIDER_ONE)
    {
        ICollectiveCore.CosmicProvider memory cosmicProviderDetailsOptimism =
            collectiveCorePolygon.getCosmicProviderDetails(COSMIC_PROVIDER_ONE);
        uint256 unlockPeriod = collectiveCorePolygon.getUnlockPeriod(COSMIC_PROVIDER_ONE);

        ICollectiveCore.UsdtBalances memory usdtBalances = collectiveCorePolygon.getUsdtBalances();
        assertEq(usdtBalances.Avalanche, DEPOSIT_USDT_AMOUNT);
        assertEq(usdtBalances.Optimism, 0);
        assertEq(usdtBalances.Polygon, 0);

        assertEq(cosmicProviderDetailsOptimism.aUSDT, DEPOSIT_USDT_AMOUNT);
        assertEq(cosmicProviderDetailsOptimism.oUSDT, 0);
        assertEq(cosmicProviderDetailsOptimism.pUSDT, 0);
        assertEq(cosmicProviderDetailsOptimism.IOU_USDT, DEPOSIT_USDT_AMOUNT);
        assertEq(cosmicProviderDetailsOptimism.totalUSDT, DEPOSIT_USDT_AMOUNT);
        assertEq(cosmicProviderDetailsOptimism.unlockPeriod, unlockPeriod);
    }
}
