delimiter $$

drop procedure if exists bartender.QuoteSetPicked $$

create procedure bartender.QuoteSetPicked (
  pUserId   int
, pQuoteId  int
, pIsPicked bool
)
begin
  declare tradePackageId int;
  declare pickedBy int;
  declare pickedOn datetime;

  if pIsPicked <> 0
  then
    set pickedBy = pUserId;
    set pickedOn = utc_timestamp();
  end if;

  select q.TradePackageId
    into tradePackageId
    from Quote as q
   where q.Id = pQuoteId;

  update QuoteAmount
     set IsPicked = pIsPicked
       , PickedBy = pickedBy
       , PickedOn = pickedOn
   where QuoteId = pQuoteId
     and Total is not null
     and IsPicked <> pIsPicked;

  update TradePackageItem as tpi
     set tpi.IsPicked = if(exists(select null from QuoteAmount as qa where qa.TradePackageItemId = tpi.Id and qa.IsPicked = 1), 1, 0)
   where tpi.TradePackageId = tradePackageId;
end $$

delimiter ;