// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../CollectiveCoreUnitTest.t.sol";

/**
 * @notice Contract For Reedeming USDT Unit Tests
 */
contract ReedemUSDTUnitTest is CollectiveCoreUnitTest {
    uint256 EXCESS_REEDEM_AMOUNT = 300e18;

    function testReedemUSDTRevertsWhenAmountIsZero() public depositUSDTToAvalanche(COSMIC_PROVIDER_ONE) {
        vm.startPrank(COSMIC_PROVIDER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__AmountMustBeGreaterThanZero.selector);
        collectiveCoreAvalanche.reedemUSDT(ZERO_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        vm.stopPrank();
    }

    function testReedemUSDTRevertsWhenTotalUSDTBalanceIsLessThanAmountToReedem()
        public
        depositUSDTToAvalanche(COSMIC_PROVIDER_ONE)
    {
        vm.startPrank(COSMIC_PROVIDER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__InsufficientIouUsdtBalance.selector);
        collectiveCoreAvalanche.reedemUSDT(EXCESS_REEDEM_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        vm.stopPrank();
    }

    function testReedemUSDTRevertsWhenTheUnlockPeriodHasntBeenMet()
        public
        depositUSDTToAvalanche(COSMIC_PROVIDER_ONE)
    {
        vm.startPrank(COSMIC_PROVIDER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__UnlockPeriodHasntArrived.selector);
        collectiveCoreAvalanche.reedemUSDT(REEDEM_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        vm.stopPrank();
    }

    function testReedemUsdtRevertsIfContractHasInsuffuentUsdtToExchangeForIOU_USDT()
        public
        depositUSDTToAvalanche(COSMIC_PROVIDER_ONE)
        depositUSDToOptimsim(COSMIC_PROVIDER_ONE)
    {
        uint256 amountThatsGreaterThanDepositAmountButLessThanTotalAmoun =
            DEPOSIT_USDT_AMOUNT + (DEPOSIT_USDT_AMOUNT / 2);

        vm.warp(block.timestamp + collectiveCoreAvalanche.getUnlockPeriod(COSMIC_PROVIDER_ONE) + 1);
        vm.startPrank(COSMIC_PROVIDER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__ContractDoesntHaveSufficientUsdtToReedemOnThisChain.selector);
        collectiveCoreAvalanche.reedemUSDT(
            amountThatsGreaterThanDepositAmountButLessThanTotalAmoun, AVALANCHE_CHAIN_SELECTOR
        );
        vm.stopPrank();
    }

    function testReedemUSDTUpdatesCosmicProviderAndContractUSDTBalances()
        public
        depositUSDTToAvalanche(COSMIC_PROVIDER_ONE)
    {
        vm.warp(block.timestamp + collectiveCoreAvalanche.getUnlockPeriod(COSMIC_PROVIDER_ONE) + 1);

        vm.startPrank(COSMIC_PROVIDER_ONE);
        collectiveCoreAvalanche.reedemUSDT(REEDEM_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        vm.stopPrank();

        ICollectiveCore.CosmicProvider memory cosmicProviderDetails =
            collectiveCoreAvalanche.getCosmicProviderDetails(COSMIC_PROVIDER_ONE);

        assertEq(cosmicProviderDetails.IOU_USDT, DEPOSIT_USDT_AMOUNT - REEDEM_AMOUNT);
        assertEq(cosmicProviderDetails.totalUSDT, DEPOSIT_USDT_AMOUNT - REEDEM_AMOUNT);

        assertEq(cosmicProviderDetails.aUSDT, DEPOSIT_USDT_AMOUNT - REEDEM_AMOUNT);
        assertEq(cosmicProviderDetails.oUSDT, 0);
        assertEq(cosmicProviderDetails.pUSDT, 0);

        assertEq(collectiveCoreAvalanche.getUsdtBalances().Avalanche, DEPOSIT_USDT_AMOUNT - REEDEM_AMOUNT);
        assertEq(collectiveCoreAvalanche.getUsdtBalances().Optimism, 0);
        assertEq(collectiveCoreAvalanche.getUsdtBalances().Polygon, 0);
    }

    function testReedemUSDTRevertsWhenTheUserSpecifiesAChainBalanceToBeDeductedWithoutHavingEnoughBalance()
        public
        depositUSDTToAvalanche(COSMIC_PROVIDER_ONE)
    {
        vm.warp(block.timestamp + collectiveCoreAvalanche.getUnlockPeriod(COSMIC_PROVIDER_ONE) + 1);

        vm.startPrank(COSMIC_PROVIDER_ONE);
        vm.expectRevert(ICollectiveCore.CollectiveCore__InsufficientIouUsdtBalanceForSelectedChain.selector);
        collectiveCoreAvalanche.reedemUSDT(DEPOSIT_USDT_AMOUNT, OPTIMISM_CHAIN_SELECTOR);
        vm.stopPrank();
    }

    function testReedemUSDTUpdatesTheCosmicProviderBalancesAndUsdtBalancesOnOptimism()
        public
        depositUSDTToAvalanche(COSMIC_PROVIDER_ONE)
        depositUSDToOptimsim(COSMIC_PROVIDER_ONE)
        depositUSDToPolygon(COSMIC_PROVIDER_ONE)
    {
        vm.warp(block.timestamp + collectiveCoreAvalanche.getUnlockPeriod(COSMIC_PROVIDER_ONE) + 1);

        vm.startPrank(COSMIC_PROVIDER_ONE);
        collectiveCoreAvalanche.reedemUSDT(DEPOSIT_USDT_AMOUNT, AVALANCHE_CHAIN_SELECTOR);
        vm.stopPrank();

        uint256 cltOptimismUsdtBalance =
            MockERC20(collectiveCoreOptimism.s_usdt()).balanceOf(address(collectiveCoreOptimism));
        uint256 cltAvalancheUsdtBalance =
            MockERC20(collectiveCoreAvalanche.s_usdt()).balanceOf(address(collectiveCoreAvalanche));
        uint256 cltPolygonUsdtBalance =
            MockERC20(collectiveCorePolygon.s_usdt()).balanceOf(address(collectiveCorePolygon));

        ICollectiveCore.CosmicProvider memory cosmicProviderDetails =
            collectiveCoreOptimism.getCosmicProviderDetails(COSMIC_PROVIDER_ONE);

        assertEq(cosmicProviderDetails.IOU_USDT, DEPOSIT_USDT_AMOUNT * 2);
        assertEq(cosmicProviderDetails.totalUSDT, DEPOSIT_USDT_AMOUNT * 2);

        assertEq(cosmicProviderDetails.aUSDT, 0);
        assertEq(cosmicProviderDetails.oUSDT, DEPOSIT_USDT_AMOUNT);
        assertEq(cosmicProviderDetails.pUSDT, DEPOSIT_USDT_AMOUNT);

        assertEq(collectiveCoreOptimism.getUsdtBalances().Avalanche, 0);
        assertEq(collectiveCoreOptimism.getUsdtBalances().Optimism, DEPOSIT_USDT_AMOUNT);
        assertEq(collectiveCoreOptimism.getUsdtBalances().Polygon, DEPOSIT_USDT_AMOUNT);

        assertEq(cltOptimismUsdtBalance, DEPOSIT_USDT_AMOUNT);
        assertEq(cltAvalancheUsdtBalance, 0);
        assertEq(cltPolygonUsdtBalance, DEPOSIT_USDT_AMOUNT);
    }

    function testReedemUSDTUpdatesTheCosmicProviderBalancesAndUsdtBalancesOnPolygon()
        public
        depositUSDTToAvalanche(COSMIC_PROVIDER_ONE)
        depositUSDToOptimsim(COSMIC_PROVIDER_ONE)
        depositUSDToPolygon(COSMIC_PROVIDER_ONE)
    {
        console.log("Cosmic Provider Details: ");
        console.log("Deposit Amount: ", DEPOSIT_USDT_AMOUNT * 2);

        vm.warp(block.timestamp + collectiveCoreAvalanche.getUnlockPeriod(COSMIC_PROVIDER_ONE) + 1);

        vm.startPrank(COSMIC_PROVIDER_ONE);
        collectiveCorePolygon.reedemUSDT(DEPOSIT_USDT_AMOUNT, OPTIMISM_CHAIN_SELECTOR);
        vm.stopPrank();

        console.log("Total usdt: ", collectiveCoreAvalanche.getCosmicProviderDetails(COSMIC_PROVIDER_ONE).totalUSDT);
        console.log("aUSDT:", collectiveCoreAvalanche.getCosmicProviderDetails(COSMIC_PROVIDER_ONE).aUSDT);
        console.log("oUSDT:", collectiveCoreAvalanche.getCosmicProviderDetails(COSMIC_PROVIDER_ONE).oUSDT);
        console.log("pUSDT:", collectiveCoreAvalanche.getCosmicProviderDetails(COSMIC_PROVIDER_ONE).pUSDT);
        console.log("IOU USDT:", collectiveCoreAvalanche.getCosmicProviderDetails(COSMIC_PROVIDER_ONE).IOU_USDT);

        uint256 cltOptimismUsdtBalance =
            MockERC20(collectiveCoreOptimism.s_usdt()).balanceOf(address(collectiveCoreOptimism));
        uint256 cltAvalancheUsdtBalance =
            MockERC20(collectiveCoreAvalanche.s_usdt()).balanceOf(address(collectiveCoreAvalanche));
        uint256 cltPolygonUsdtBalance =
            MockERC20(collectiveCorePolygon.s_usdt()).balanceOf(address(collectiveCorePolygon));

        ICollectiveCore.CosmicProvider memory cosmicProviderDetails =
            collectiveCoreOptimism.getCosmicProviderDetails(COSMIC_PROVIDER_ONE);

        assertEq(cosmicProviderDetails.IOU_USDT, DEPOSIT_USDT_AMOUNT * 2);
        assertEq(cosmicProviderDetails.totalUSDT, DEPOSIT_USDT_AMOUNT * 2);

        assertEq(cosmicProviderDetails.aUSDT, DEPOSIT_USDT_AMOUNT);
        assertEq(cosmicProviderDetails.oUSDT, 0);
        assertEq(cosmicProviderDetails.pUSDT, DEPOSIT_USDT_AMOUNT);

        assertEq(collectiveCoreOptimism.getUsdtBalances().Avalanche, DEPOSIT_USDT_AMOUNT);
        assertEq(collectiveCoreOptimism.getUsdtBalances().Optimism, DEPOSIT_USDT_AMOUNT);
        assertEq(collectiveCoreOptimism.getUsdtBalances().Polygon, 0);

        assertEq(cltOptimismUsdtBalance, DEPOSIT_USDT_AMOUNT);
        assertEq(cltAvalancheUsdtBalance, DEPOSIT_USDT_AMOUNT);
        assertEq(cltPolygonUsdtBalance, 0);
    }
}
