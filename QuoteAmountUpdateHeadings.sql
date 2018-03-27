delimiter $$

drop procedure if exists bartender.QuoteAmountUpdateHeadings $$

create procedure bartender.QuoteAmountUpdateHeadings()
begin
  declare quoteAmountTypeManual     tinyint(3) default 1; -- Manual
  declare quoteAmountTypeCalculated tinyint(3) default 2; -- Calculated

  -- Drop temp tables
  drop temporary table if exists
       QuoteAmountProRata
     , QuoteAmountProRataItemGroup
     , QuoteAmountProRataParentGroup
     , EmptyQuoteAmountTree
     , EmptyQuoteAmount
     , EmptyQuoteAmountGroup;

  create temporary table QuoteAmountProRata ( QuoteAmountId int not null primary key
                                            , QuoteId       int not null
                                            , ItemId        int not null
                                            , ItemParentId  int
                                            , Type          tinyint(3) not null
                                            , IsFixed       boolean
                                            , IsIncluded    boolean not null
                                            , IsExcluded    boolean not null
                                            , TotalProcess  decimal(28, 16)
                                            , Total         decimal(28, 16)
                                            , Rate          decimal(28, 16)
                                            ) engine=memory;

  create temporary table QuoteAmountProRataItemGroup (QuoteId int not null, ItemParentId int not null, RowCount int not null, ExcludedCount int not null, primary key (QuoteId, ItemParentId)) engine=memory;

  create temporary table QuoteAmountProRataParentGroup (QuoteId int not null, ItemId int, IncludedCount int not null, primary key (QuoteId, ItemId)) engine=memory;

  create temporary table EmptyQuoteAmountTree ( QuoteAmountId          int not null primary key
                                              , AncestorQuoteAmountId  int not null
                                              , QuoteId                int not null
                                              , ItemId                 int not null
                                              , ItemParentId           int
                                              , ItemParentLevel        int
                                              , IsFixed                boolean
                                              , IsEmpty                boolean not null
                                              , ItemTotal              decimal(28, 16)
                                              , FactoredQuantity       decimal(28, 16)
                                              , ProRataByEstimateTotal decimal(28, 16)
                                              ) engine=memory;

  create temporary table EmptyQuoteAmount ( QuoteAmountId          int not null primary key
                                          , AncestorQuoteAmountId  int not null
                                          , QuoteId                int not null
                                          , ItemId                 int not null
                                          , ItemParentId           int
                                          , ItemParentLevel        int
                                          , IsFixed                boolean
                                          , ItemTotal              decimal(28, 16)
                                          , FactoredQuantity       decimal(28, 16)
                                          , ProRataByEstimateTotal decimal(28, 16)
                                          ) engine=memory;

  create temporary table EmptyQuoteAmountGroup (QuoteId int not null primary key, Total decimal(28, 16), RowCount int not null) engine=memory;

  -- Build tree to simplify recursion tasks
  if not exists(select null from TradePackageItemTree)
  then
    call QuoteAmountUpdateItemTree();
  end if;

  -- Delete operation on heading level
  if exists(select null from QuoteAmountProcess as qap where qap.IsHeading = 1 and qap.Total is null)
  then
    insert UpdatedQuoteAmount (QuoteAmountId, QuoteId, Type, IsFixed, Rate, Total, IsDeletePlug, IsAddPlug)
    select qac.QuoteAmountId
         , qac.QuoteId
         , quoteAmountTypeCalculated
         , if (qac.IsHeading = 1, null, qac.IsFixed)
         , null
         , null
         , 1
         , 0
      from QuoteAmountProcess   as qap
      join TradePackageItemTree as tpit on tpit.Ancestor = qap.ItemId
      join QuoteAmountCache     as qac  on qac.ItemId    = tpit.Descendant and qac.QuoteId = qap.QuoteId
     where qap.IsHeading = 1
       and qap.IsNoted   = 0
       and qap.Total is null
        on duplicate key
    update Type         = quoteAmountTypeCalculated
         , IsFixed      = if (qap.IsHeading = 1, null, qap.IsFixed)
         , Rate         = null
         , Total        = null
         , IsDeletePlug = 1
         , IsAddPlug    = 0;

  -- Pro Rata by itself or estimate total
  elseif exists(select null from QuoteAmountProcess as qap where qap.IsHeading = 1 and qap.IsNoneOption = 1)
  then
    -- Pro Rata by itself if the heading and all children have total
    if not exists(select * 
                    from QuoteAmountProcess   as qap
                    join TradePackageItemTree as tpit on tpit.Ancestor = qap.ItemId
                    join QuoteAmountCache     as qac  on qac.ItemId    = tpit.Descendant and qac.QuoteId = qap.QuoteId
                   where qap.IsHeading    = 1
                     and qap.IsNoneOption = 1
                     and qac.IsNoted      = 0
                     and qac.Total is null)
    then
      insert QuoteAmountProRata (QuoteAmountId, QuoteId, ItemId, ItemParentId, Type, IsFixed, IsIncluded, IsExcluded, TotalProcess, Total, Rate)
      select qac.QuoteAmountId
           , qac.QuoteId
           , qac.ItemId
           , qac.ItemParentId
           , quoteAmountTypeCalculated
           , if (qac.IsHeading = 1, null, qac.IsFixed)
           , qac.IsIncluded
           , qac.IsExcluded
           , qap.Total as TotalProcess
           ,                               if(qap.ProRataByItselfRatio is not null, ifnull(qac.TotalOriginal, 0) * qap.ProRataByItselfRatio, qap.Total * tpit.DescendantRatio) as Total
           , if(qac.FactoredQuantity <> 0, if(qap.ProRataByItselfRatio is not null, ifnull(qac.TotalOriginal, 0) * qap.ProRataByItselfRatio, qap.Total * tpit.DescendantRatio) / qac.FactoredQuantity, null) as Rate
        from QuoteAmountProcess   as qap
        join TradePackageItemTree as tpit on tpit.Ancestor = qap.ItemId
        join QuoteAmountCache     as qac  on qac.ItemId    = tpit.Descendant and qac.QuoteId = qap.QuoteId
       where qap.IsHeading    = 1
         and qap.IsNoneOption = 1
         and qac.IsNoted      = 0
         and qac.Total is not null;

       -- Item group
      insert QuoteAmountProRataItemGroup (QuoteId, ItemParentId, RowCount, ExcludedCount)
      select qapr.QuoteId
           , qapr.ItemParentId
           , count(*) as RowCount
           , sum(if(qapr.IsExcluded, 1, 0)) as ExcludedCount
        from QuoteAmountProRata as qapr
       where qapr.ItemParentId is not null
    group by qapr.QuoteId
           , qapr.ItemParentId;

      -- Parent group
      insert QuoteAmountProRataParentGroup (QuoteId, ItemId, IncludedCount)
      select qapr.QuoteId
           , qapr.ItemParentId
           , sum(if(qapr.IsIncluded, 1, 0)) as IncludedCount
        from QuoteAmountProRata as qapr
       where qapr.ItemParentId is not null
    group by qapr.QuoteId
           , qapr.ItemParentId;

      insert UpdatedQuoteAmount (QuoteAmountId, QuoteId, Type, IsFixed, Rate, Total, IsDeletePlug, IsAddPlug)
      select qapr.QuoteAmountId
           , qapr.QuoteId
           , if(qap.QuoteAmountId is not null, if(ifnull(qaprpg.IncludedCount, 0) > 0, quoteAmountTypeManual, quoteAmountTypeCalculated), qapr.Type)
           , if(qap.QuoteAmountId is not null, if(ifnull(qaprpg.IncludedCount, 0) > 0, !isnull(qapr.TotalProcess), 0), qapr.IsFixed)
           , if(qap.QuoteAmountId is not null, qap.Rate, qapr.Rate)
           , if(qap.QuoteAmountId is not null, qap.Total, qapr.Total)
           , if(qap.QuoteAmountId is not null, 1, if(isnull(qapr.TotalProcess) or qaprig.RowCount = qaprig.ExcludedCount, 1, 0))
           , 0
        from QuoteAmountProRata            as qapr
        join QuoteAmountProRataItemGroup   as qaprig on qaprig.QuoteId    = qapr.QuoteId and qaprig.ItemParentId = qapr.ItemParentId
   left join QuoteAmountProcess            as qap    on qap.QuoteAmountId = qapr.QuoteAmountId
   left join QuoteAmountProRataParentGroup as qaprpg on qaprpg.QuoteId    = qap.QuoteId  and qaprpg.ItemId = qap.ItemId
          on duplicate key
      update Type         = if(qap.QuoteAmountId is not null, if(ifnull(qaprpg.IncludedCount, 0) > 0, quoteAmountTypeManual, quoteAmountTypeCalculated), qapr.Type)
           , IsFixed      = if(qap.QuoteAmountId is not null, if(ifnull(qaprpg.IncludedCount, 0) > 0, !isnull(qapr.TotalProcess), 0), qapr.IsFixed)
           , Rate         = if(qap.QuoteAmountId is not null, qap.Rate, qapr.Rate)
           , Total        = if(qap.QuoteAmountId is not null, qap.Total, qapr.Total)
           , IsDeletePlug = if(qap.QuoteAmountId is not null, 1, if(isnull(qapr.TotalProcess) or qaprig.RowCount = qaprig.ExcludedCount, 1, 0))
           , IsAddPlug    = 0;

    -- Pro Rata by estimate total if at least one child doesn't have total
    else
      -- Empty quote amounts with headings
      insert EmptyQuoteAmountTree (QuoteAmountId, AncestorQuoteAmountId, QuoteId, ItemId, ItemParentId, ItemParentLevel, IsFixed, IsEmpty, ItemTotal, FactoredQuantity, ProRataByEstimateTotal)
      select qac.QuoteAmountId
           , qap.QuoteAmountId
           , qac.QuoteId
           , qac.ItemId
           , qac.ItemParentId
           , qac.ItemParentLevel
           , qac.IsFixed
           , qac.IsEmpty
           , qac.ItemTotal
           , qac.FactoredQuantity
           , ifnull(qap.Total, 0) - ifnull(qap.TotalOriginal, 0)
        from QuoteAmountProcess   as qap
        join TradePackageItemTree as tpit on tpit.Ancestor = qap.ItemId
        join QuoteAmountCache     as qac  on qac.ItemId    = tpit.Descendant and qac.QuoteId = qap.QuoteId and qac.IsNoted = 0 and qac.Total is null
       where qap.IsHeading    = 1
         and qap.IsNoneOption = 1;

      -- Empty quote amounts without headings
      insert EmptyQuoteAmount (QuoteAmountId, AncestorQuoteAmountId, QuoteId, ItemId, ItemParentId, ItemParentLevel, IsFixed, ItemTotal, FactoredQuantity, ProRataByEstimateTotal)
      select eqat.QuoteAmountId
           , eqat.AncestorQuoteAmountId
           , eqat.QuoteId
           , eqat.ItemId
           , eqat.ItemParentId
           , eqat.ItemParentLevel
           , eqat.IsFixed
           , eqat.ItemTotal
           , eqat.FactoredQuantity
           , eqat.ProRataByEstimateTotal
        from EmptyQuoteAmountTree as eqat
       where eqat.IsEmpty = 1;

      insert EmptyQuoteAmountGroup (QuoteId, Total, RowCount)
      select eqa.QuoteId 
           , sum(abs(ifnull(eqa.ItemTotal, 0))) as EstimateTotal
           , count(*) as RowCount
        from EmptyQuoteAmount as eqa
    group by eqa.QuoteId;

      insert UpdatedQuoteAmount (QuoteAmountId, QuoteId, Type, IsFixed, Rate, Total, IsDeletePlug, IsAddPlug)
      select eqa.QuoteAmountId
           , eqa.QuoteId
           , quoteAmountTypeCalculated
           , eqa.IsFixed
           , if(ifnull(eqa.FactoredQuantity, 0) = 0, 0, if(eqag.Total <> 0, abs(ifnull(eqa.ItemTotal, 0)) / eqag.Total, 1 / eqag.RowCount) * eqa.ProRataByEstimateTotal / abs(eqa.FactoredQuantity)) as Rate
           , if(eqag.Total <> 0, abs(ifnull(eqa.ItemTotal, 0)) / eqag.Total, 1 / eqag.RowCount) * eqa.ProRataByEstimateTotal as Total
           , 0
           , 1
        from EmptyQuoteAmount      as eqa
        join EmptyQuoteAmountGroup as eqag on eqag.QuoteId = eqa.QuoteId
          on duplicate key
      update Type         = quoteAmountTypeCalculated
           , IsFixed      = eqa.IsFixed
           , Rate         = if(ifnull(eqa.FactoredQuantity, 0) = 0, 0, if(eqag.Total <> 0, abs(ifnull(eqa.ItemTotal, 0)) / eqag.Total, 1 / eqag.RowCount) * eqa.ProRataByEstimateTotal / abs(eqa.FactoredQuantity))
           , Total        = if(eqag.Total <> 0, abs(eqa.ItemTotal) / eqag.Total, 1 / eqag.RowCount) * eqa.ProRataByEstimateTotal
           , IsDeletePlug = 0
           , IsAddPlug    = 1;

      -- Add headers that need to be updated
      insert ParentTradePackageItem (ItemId, QuoteId, Level, IsProRataByEstimateTotal)
      select distinct
             eqat.ItemParentId
           , eqat.QuoteId
           , eqat.ItemParentLevel
           , 1
        from EmptyQuoteAmountTree as eqat
          on duplicate key
      update IsProRataByEstimateTotal = 1;

      -- Update 'Type' and 'IsFixed'
      update UpdatedQuoteAmount as uqa
        join (select distinct
                     eqa.AncestorQuoteAmountId
                   , eqa.QuoteId
                   , !isnull(qac.Total) as IsFixed
                   , quoteAmountTypeManual as Type
                from EmptyQuoteAmount as eqa
                join QuoteAmountCache as qac on qac.QuoteAmountId = eqa.AncestorQuoteAmountId) as x on x.AncestorQuoteAmountId = uqa.QuoteAmountId
         set uqa.Type    = x.Type
           , uqa.IsFixed = x.IsFixed;

    end if;
    
  -- Include
  elseif exists(select null from QuoteAmountProcess as qap where qap.IsHeading = 1 and qap.IsIncludeOption = 1)
  then
    signal sqlstate '45000' set message_text = 'Include is not supported.';
  -- Pro Rata from estimate or supplier
  elseif exists(select null from QuoteAmountProcess as qap where qap.IsHeading = 1 and qap.IsProRataOption = 1)
  then
    signal sqlstate '45000' set message_text = 'Pro Rata from estimate or supplier is not supported.';
  end if;

  -- Update cache
  call QuoteAmountUpdateCache();
end $$

delimiter ;