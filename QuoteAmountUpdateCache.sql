delimiter $$

drop procedure if exists bartender.QuoteAmountUpdateCache $$

create procedure bartender.QuoteAmountUpdateCache()
begin
  -- Update cache
  update QuoteAmountCache as qac
    join UpdatedQuoteAmount as uqa on uqa.QuoteAmountId = qac.QuoteAmountId
     set qac.Rate         = uqa.Rate
       , qac.Total        = uqa.Total
       , qac.IsFixed      = uqa.IsFixed
       , qac.IsPicked     = if(uqa.Total is null, 0, qac.IsPicked)    -- unpick empty
       , qac.IsIncluded   = if(uqa.IsDeletePlug, 0, qac.IsIncluded)   -- remove 'Include' if necessary
       , qac.IsExcluded   = if(uqa.IsDeletePlug, 0, qac.IsExcluded)   -- remove 'Exclude' if necessary
       , qac.IsTempOrFill = if(uqa.IsDeletePlug, 0, qac.IsTempOrFill) -- remove 'Temp' and 'Fill' if necessary
       , qac.IsEmpty      = if(uqa.Total is null and qac.IsNoted = 0 and qac.IsHeading = 0, 1, 0);

end $$

delimiter ;