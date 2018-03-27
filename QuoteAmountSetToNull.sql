DELIMITER $$

DROP PROCEDURE IF EXISTS bartender.QuoteAmountSetToNull $$

CREATE PROCEDURE bartender.QuoteAmountSetToNull(IN pQuoteId INT, IN pModifiedBy INT)
BEGIN
  DECLARE tradePackageId INT;
  DECLARE pickedCount INT;
  DECLARE pickedItemsEstimate DECIMAL(28, 16);

  SELECT TradePackageId into tradePackageId FROM Quote WHERE Id = pQuoteId;

  START TRANSACTION;

      -- update quote amount
   UPDATE QuoteAmount SET
    Rate = NULL, 
    Total = NULL, 
    IsFixed = 0, 
    IsPicked = 0, 
    ModifiedBy = pModifiedBy,
    ModifiedOn = NOW()
   WHERE QuoteId = pQuoteId;

   -- delete relation between plug and quote amount
   DELETE pqa
    FROM PlugQuoteAmount AS pqa
    JOIN QuoteAmount AS qa ON qa.Id = pqa.QuoteAmountId
   WHERE qa.QuoteId = pQuoteId;

   -- Update quote
   UPDATE Quote AS q
    SET q.Total                       = NULL
    , q.IsPicked                      = 0
    , q.PickedTotal                   = NULL
    , q.PickedCount                   = 0
    , q.PickedPlugsTotal              = NULL
    , q.PickedEstimateAdjustmentTotal = NULL
    , q.PlugsTotal                    = NULL
    , q.CompletedCount                = 0
   WHERE q.Id = pQuoteId;

   -- update tradepackageitem
   UPDATE TradePackageItem AS tpi
    SET tpi.IsPicked = CASE 
    WHEN EXISTS (SELECT NULL 
        FROM QuoteAmount AS qa 
        WHERE qa.TradePackageItemId = tpi.Id
        AND qa.IsPicked = 1)
    THEN 1
    ELSE 0
    END
   WHERE tpi.TradePackageId = tradePackageId;

  SELECT COUNT(*) AS Count
       , SUM(Total) AS Estimate 
    INTO pickedCount, pickedItemsEstimate
    FROM TradePackageItem 
   WHERE IsPicked = 1 AND IsHeading = 0 
   AND TradePackageId = tradePackageId;

   -- update tradepackage
  UPDATE TradePackage
    SET	PickedCount = pickedCount,
     PickedItemsEstimate = pickedItemsEstimate
      WHERE Id = tradePackageId;

  COMMIT;

   -- return updated quote amounts
  SELECT 
     qa.Id AS QuoteAmountId, 
     qa.TradePackageItemId, 
     qa.QuoteId, 
     qa.Type, 
     qa.Rate, 
     qa.Total, 
     qa.IsFixed, 
     qa.IsPicked, 
     qa.MergeStatus,
     NULL AS PlugType
    FROM QuoteAmount AS qa
      WHERE QuoteId = pQuoteId;
END $$

DELIMITER ;