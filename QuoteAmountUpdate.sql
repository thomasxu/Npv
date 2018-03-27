delimiter $$

drop procedure if exists bartender.QuoteAmountUpdate $$

create procedure bartender.QuoteAmountUpdate (
  pQuoteAmounts text
, pIsManualTotalRemovalAllowed boolean
)
begin
  declare quoteId               int;
  declare parentQuoteAmountId   int;
  declare itemParentId          int;
  declare quoteIndex            int default 0;
  declare quoteAmountIndex      int default 0;
  declare quoteCount            int default 0;
  declare quoteAmountCount      int default 0;
  declare quoteQuoteAmountCount int default 0;
  declare percentageCount       int default 0;

  declare quotePath       varchar(255);
  declare quoteAmountPath varchar(255);

  declare total          decimal(28, 16);
  declare childrenTotal  decimal(28, 16);

  declare isFixed                  boolean default 0;
  declare isRecalculable           boolean default 0;
  declare isPercentageOperation    boolean default 0;
  declare isAddPlug                boolean default 0;
  declare isDeletePlug             boolean default 0;
  declare isProRataByEstimateTotal boolean default 0;
  declare isRecalculateChildren    boolean default 0;

  declare quoteTypeAdjustment       tinyint(3) default 2; -- Adjustment
  declare quoteAmountTypeManual     tinyint(3) default 1; -- Manual
  declare quoteAmountTypeCalculated tinyint(3) default 2; -- Calculated
  declare mergeStatusDone           tinyint(3) default 1; -- Done
  declare plugTypeInclude           tinyint(3) default 1; -- Include
  declare plugTypeExclude           tinyint(3) default 2; -- Exclude
  declare plugTypeTemp              tinyint(3) default 5; -- Temp
  declare plugTypeFill              tinyint(3) default 7; -- Fill
  declare noneOption                tinyint(3) default 0;
  declare proRataFromEstimation     tinyint(3) default 1;
  declare proRataFromSupplier       tinyint(3) default 2;
  declare includeTradeItems         tinyint(3) default 3;

  if pQuoteAmounts is null or pQuoteAmounts = ''
  then
    signal sqlstate '45000' set message_text = 'Quote amounts haven''t been provided.';
  end if;

  -- Drop temp tables
  drop temporary table if exists
       QuoteAmountXml
     , QuoteAmountCache
     , QuoteAmountPlugCache
     , QuoteAmountProcess
     , QuoteAmountProcessHeading
     , TradePackageItemTree
     , ParentTradePackageItem
     , UpdatedQuoteAmount
     , UpdatedQuoteAmountBuffer
     , UnpickedTradePackageItem
     , QuoteSummary
     , TradePackageSummary;

  create temporary table QuoteAmountXml ( QuoteAmountId     int not null primary key
                                        , QuoteId           int not null
                                        , Rate              decimal(28, 16)
                                        , Total             decimal(28, 16)
                                        , IsPercentage      boolean
                                        , HeaderOption      tinyint(3)
                                        , HeaderOptionValue int
                                        ) engine=memory;

  create temporary table QuoteAmountCache ( QuoteAmountId    int not null primary key
                                          , PackageId        int not null
                                          , QuoteId          int not null
                                          , Type             tinyint(3) not null
                                          , ItemId           int not null
                                          , ItemParentId     int
                                          , ItemParentLevel  int
                                          , ItemTotal        decimal(28, 16)
                                          , FactoredQuantity decimal(28, 16)
                                          , IsFixed          boolean
                                          , IsHeading        boolean not null
                                          , IsNoted          boolean not null
                                          , IsEmpty          boolean not null
                                          , IsIncluded       boolean not null
                                          , IsExcluded       boolean not null
                                          , IsTempOrFill     boolean not null
                                          , IsPicked         boolean not null
                                          , Rate             decimal(28, 16)
                                          , Total            decimal(28, 16)
                                          , TotalOriginal    decimal(28, 16)
                                          ) engine=memory;

  create temporary table QuoteAmountPlugCache ( QuoteAmountId int not null primary key
                                              , IsIncluded    boolean not null
                                              , IsExcluded    boolean not null
                                              , IsTempOrFill  boolean not null) engine=memory;

  create temporary table QuoteAmountProcess ( QuoteAmountId        int not null primary key
                                            , QuoteId              int not null
                                            , Type                 tinyint(3) not null
                                            , ItemId               int not null
                                            , ItemParentId         int
                                            , ItemParentLevel      int
                                            , FactoredQuantity     decimal(28, 16)
                                            , IsFixed              boolean
                                            , IsHeading            boolean not null
                                            , IsNoted              boolean not null
                                            , IsEmpty              boolean not null
                                            , IsIncluded           boolean not null
                                            , IsNoneOption         boolean not null
                                            , IsIncludeOption      boolean not null
                                            , IsProRataOption      boolean not null
                                            , Rate                 decimal(28, 16)
                                            , Total                decimal(28, 16)
                                            , TotalOriginal        decimal(28, 16)
                                            , ProRataByItselfRatio decimal(28, 16)
                                            ) engine=memory;

  create temporary table QuoteAmountProcessHeading (ItemId int not null primary key) engine=memory;

  create temporary table TradePackageItemTree (Ancestor int not null, Descendant int not null, Level int not null, DescendantRowCount int not null, DescendantRatio decimal(28, 16) not null, primary key (Ancestor, Descendant)) engine=memory;

  create temporary table ParentTradePackageItem (ItemId int not null, QuoteId int not null, Level int not null, IsProRataByEstimateTotal boolean not null, primary key (ItemId, QuoteId)) engine=memory;

  create temporary table UpdatedQuoteAmount ( QuoteAmountId int not null primary key
                                            , QuoteId       int not null
                                            , Type          tinyint(3) not null
                                            , IsFixed       boolean
                                            , Rate          decimal(28, 16)
                                            , Total         decimal(28, 16)
                                            , IsDeletePlug  boolean not null
                                            , IsAddPlug     boolean not null
                                            ) engine=memory;

  create temporary table UnpickedTradePackageItem (ItemId int not null primary key, PackageId int not null) engine=memory;

  create temporary table QuoteSummary ( QuoteId                       int not null primary key
                                      , ItemCount                     int not null
                                      , PickedCount                   int not null
                                      , CompletedCount                int not null
                                      , Total                         decimal(28, 16)
                                      , PickedTotal                   decimal(28, 16)
                                      , PickedPlugsTotal              decimal(28, 16)
                                      , PickedEstimateAdjustmentTotal decimal(28, 16)
                                      , PlugsTotal                    decimal(28, 16)
                                      , IsPicked                      boolean not null
                                      ) engine=memory;

  create temporary table TradePackageSummary (TradePackageId int not null primary key, PickedCount int not null, PickedItemsEstimate decimal(28, 16)) engine=memory;

  set quoteCount = extractvalue(pQuoteAmounts, 'count(/Quotes/Quote)');

  -- Read xml data into temp table
  while quoteIndex < quoteCount 
  do
    set quoteIndex = quoteIndex + 1;

    set quotePath = concat('/Quotes/Quote[', quoteIndex, ']')
      , quoteId   = nullif(extractvalue(pQuoteAmounts, concat(quotePath, '/attribute::Id')), '');

    set quoteAmountIndex      = 0
      , quoteQuoteAmountCount = extractvalue(pQuoteAmounts, concat('count(', quotePath, '/QA)'))
      , quoteAmountCount      = quoteAmountCount + quoteQuoteAmountCount;

    while quoteAmountIndex < quoteQuoteAmountCount 
    do
      set quoteAmountIndex = quoteAmountIndex + 1;

      set quoteAmountPath = concat(quotePath, '/QA[', quoteAmountIndex, ']');

      insert QuoteAmountXml (QuoteId, QuoteAmountId, Rate, Total, IsPercentage, HeaderOption, HeaderOptionValue)
      select quoteId
           , nullif(extractvalue(pQuoteAmounts, concat(quoteAmountPath, '/attribute::Id')), '')
           , nullif(extractvalue(pQuoteAmounts, concat(quoteAmountPath, '/attribute::Rate')), '')
           , nullif(extractvalue(pQuoteAmounts, concat(quoteAmountPath, '/attribute::Total')), '')
           , nullif(extractvalue(pQuoteAmounts, concat(quoteAmountPath, '/attribute::IsPercentage')), '')
           , nullif(extractvalue(pQuoteAmounts, concat(quoteAmountPath, '/attribute::HeaderOption')), '')
           , nullif(extractvalue(pQuoteAmounts, concat(quoteAmountPath, '/attribute::HeaderOptionValue')), '');
    end while;
  end while;

  if exists(select null from QuoteAmountXml as qax where qax.HeaderOption is not null and qax.HeaderOption = proRataFromSupplier and qax.HeaderOptionValue is null)
  then
    signal sqlstate '45000' set message_text = 'Quote id should be specified for pro rata by supplier.';
  end if;

  set isPercentageOperation = if(exists(select null from QuoteAmountXml as qax where qax.IsPercentage is not null and qax.IsPercentage = 1), 1, 0);

  -- Percentage can be applied to 1 quote amount only
  if isPercentageOperation = 1 and quoteAmountCount > 1
  then
    signal sqlstate '45000' set message_text = 'Only one value can be updated with percentage option.';
  end if;

  -- Quote amount cache
  insert QuoteAmountCache (QuoteAmountId, PackageId, QuoteId, Type, ItemId, ItemParentId, ItemParentLevel, ItemTotal, FactoredQuantity, IsFixed, IsHeading, IsNoted, IsEmpty, IsIncluded, IsExcluded, IsTempOrFill, IsPicked, Rate, Total, TotalOriginal)
  select qa.Id
       , tpi.TradePackageId
       , qa.QuoteId
       , qa.Type
       , tpi.Id
       , tpi.ParentId
       , tpi.Level - 1
       , tpi.Total
       , tpi.FactoredQuantity
       , qa.IsFixed
       , tpi.IsHeading
       , tpi.IsNoted
       , if(tpi.IsNoted = 0 and qa.Total is null and tpi.IsHeading = 0, 1, 0) as IsEmpty
       , 0 as IsIncluded   -- update later
       , 0 as IsExcluded   -- update later
       , 0 as IsTempOrFill -- update later
       , qa.IsPicked
       , qa.Rate
       , qa.Total
       , qa.Total
    from QuoteAmount as qa
    join TradePackageItem as tpi on tpi.Id = qa.TradePackageItemId
   where qa.QuoteId in (select qax.QuoteId from QuoteAmountXml as qax);

  -- Quote amount plug cache
  insert QuoteAmountPlugCache (QuoteAmountId, IsIncluded, IsExcluded, IsTempOrFill)
  select qac.QuoteAmountId
       , max(if(p.Type = plugTypeInclude, 1, 0))               as IsIncluded
       , max(if(p.Type = plugTypeExclude, 1, 0))               as IsExcluded
       , max(if(p.Type in (plugTypeTemp, plugTypeFill), 1, 0)) as IsTempOrFill
    from QuoteAmountCache as qac
    join PlugQuoteAmount  as pqa on pqa.QuoteAmountId = qac.QuoteAmountId
    join Plug             as p on p.Id = pqa.PlugId
   where p.Type in (plugTypeInclude, plugTypeExclude, plugTypeTemp, plugTypeFill)
group by qac.QuoteAmountId;

  -- Update plugs fields
  update QuoteAmountCache as qac
    join QuoteAmountPlugCache as qapc on qapc.QuoteAmountId = qac.QuoteAmountId
     set qac.IsIncluded   = qapc.IsIncluded
       , qac.IsExcluded   = qapc.IsExcluded
       , qac.IsTempOrFill = qapc.IsTempOrFill;

  -- Quote amounts should belong to the specified quotes
  if exists(select null 
              from QuoteAmountXml   as qax
         left join QuoteAmountCache as qac on qac.QuoteAmountId = qax.QuoteAmountId
             where qac.QuoteAmountId is null)
  then
    signal sqlstate '45000' set message_text = 'Quote amounts don''t belong to the specified quotes.';
  end if;

  -- Pro Rata is not applicable to noted heading
  if exists(select null 
              from QuoteAmountXml   as qax
              join QuoteAmountCache as qac on qac.QuoteAmountId = qax.QuoteAmountId
             where qac.IsHeading = 1 
               and qac.IsNoted   = 1)
  then
    signal sqlstate '45000' set message_text = 'Noted headings don''t support Pro Rata.';
  end if;

  -- Percentage can be applied to the Adjustment quote only
  if isPercentageOperation = 1
 and not exists(select null 
                  from QuoteAmountXml as qax
                  join Quote          as q on q.Id = qax.QuoteId
                 where q.Type = quoteTypeAdjustment)
  then
    signal sqlstate '45000' set message_text = 'Percentage operation can be applied to the Adjustment quote only.';
  end if;

  -- Prepare data for processing
  insert QuoteAmountProcess (QuoteAmountId, QuoteId, Type, ItemId, ItemParentId, ItemParentLevel, FactoredQuantity, IsFixed, IsHeading, IsNoted, IsEmpty, IsIncluded, IsNoneOption, IsIncludeOption, IsProRataOption, Rate, Total, TotalOriginal, ProRataByItselfRatio)
  select qac.QuoteAmountId
       , qac.QuoteId
       , qac.Type
       , qac.ItemId
       , qac.ItemParentId
       , qac.ItemParentLevel
       , qac.FactoredQuantity
       , qac.IsFixed
       , qac.IsHeading
       , qac.IsNoted
       , 0 as IsEmpty
       , qac.IsIncluded
       , if(x.HeaderOption is null or x.HeaderOption = noneOption, 1, 0) as IsNoneOption
       , if(x.HeaderOption is not null and x.HeaderOption = includeTradeItems, 1, 0) as IsIncludeOption
       , if(x.HeaderOption is not null and x.HeaderOption in (proRataFromEstimation, proRataFromSupplier), 1, 0) as IsProRataOption
       , ifnull(x.Rate,  if(qac.FactoredQuantity is not null and qac.FactoredQuantity <> 0, x.Total / qac.FactoredQuantity, null)) as Rate
       , ifnull(x.Total, if(x.Rate is not null, x.Rate * qac.FactoredQuantity, null)) as Total
       , qac.Total as TotalOriginal
       , null      as ProRataByItselfRatio
    from QuoteAmountXml   as x
    join QuoteAmountCache as qac on qac.QuoteAmountId = x.QuoteAmountId
   where qac.IsNoted = 0; -- noted items should not have values

  -- Headings of the quote amounts for processing
  insert QuoteAmountProcessHeading (ItemId)
  select distinct
         qap.ItemParentId
    from QuoteAmountProcess as qap
   where qap.ItemParentId is not null;

  -- Remove the headings from processing if they have children for processing
  -- Headings should have the sum of the values of its children
  delete qap
    from QuoteAmountProcess as qap
    join QuoteAmountProcessHeading as qaph on qaph.ItemId = qap.ItemId;

  -- Separate update to avoid complexity of the statements
  update QuoteAmountProcess as qap
     set qap.IsEmpty              = if(qap.Total is null and qap.IsNoted = 0 and qap.IsHeading = 0, 1, 0)
       , qap.ProRataByItselfRatio = if(qap.IsHeading = 1 and qap.IsNoted = 0 and qap.TotalOriginal is not null and qap.TotalOriginal > 0, qap.Total / qap.TotalOriginal, null);

  -- Separate update to avoid complexity of the statements.
  -- It is INCORRECT for Pro Rata by Estimate total and by itself with 0 totals!
  -- When needed 'Type' and 'IsFixed' will be recalculated later to avoid building item tree without necessity.
  update QuoteAmountProcess as qap
     set qap.Type    = if(qap.IsProRataOption = 1, quoteAmountTypeCalculated, quoteAmountTypeManual) 
       , qap.IsFixed = if(qap.IsProRataOption = 1, 0, if(qap.IsHeading = 1, !isnull(qap.Total), qap.IsFixed));

  -- Add changes
  insert UpdatedQuoteAmount (QuoteAmountId, QuoteId, Type, IsFixed, Rate, Total, IsDeletePlug, IsAddPlug)
  select qap.QuoteAmountId
       , qap.QuoteId
       , qap.Type
       , qap.IsFixed
       , qap.Rate
       , qap.Total
       , 1
       , 0
    from QuoteAmountProcess as qap;

  -- Add parents for further recalculation
  insert ParentTradePackageItem (ItemId, QuoteId, Level, IsProRataByEstimateTotal)
  select distinct
         qap.ItemParentId
       , qap.QuoteId
       , qap.ItemParentLevel
       , 0
    from QuoteAmountProcess as qap
   where qap.ItemParentId is not null;

  -- Update cache
  call QuoteAmountUpdateCache();

  -- Process headings
  if exists(select null from QuoteAmountProcess as qap where qap.IsHeading = 1)
  then

    call QuoteAmountUpdateHeadings();

  end if;

  -- Remove parents that were already processed
  delete ptpi
    from ParentTradePackageItem as ptpi
    join QuoteAmountProcess     as qap on qap.ItemId = ptpi.ItemId and qap.QuoteId = ptpi.QuoteId;

  -- Update parents
  while exists(select null from ParentTradePackageItem)
  do
    -- Process from the bottom to the top
    select ptpi.ItemId
         , ptpi.QuoteId
         , ptpi.IsProRataByEstimateTotal
      into itemParentId
         , quoteId
         , isProRataByEstimateTotal
      from ParentTradePackageItem as ptpi
  order by ptpi.Level desc
     limit 1;

    set isRecalculateChildren = 0;


     -- Parent quote amount
	select qac.QuoteAmountId
	   , qac.IsFixed
	   , qac.Total
	into parentQuoteAmountId
	   , isFixed
	   , total
	from QuoteAmountCache as qac
	where qac.ItemId = itemParentId
	 and qac.QuoteId = quoteId;

	-- Check whether parent has recalculable children
	set isRecalculable = if(exists(select null 
								   from QuoteAmountCache as qac 
								  where qac.ItemParentId = itemParentId 
									and qac.QuoteId      = quoteId
									and qac.IsNoted      = 0
									and qac.IsIncluded   = 1
								),
						  1, 0);

	-- Plugs
	set isDeletePlug = if(isRecalculable = 0 or isnull(total), 1, 0)
	, isAddPlug    = if(isProRataByEstimateTotal = 1 and isnull(total), 1, 0);

	-- Pro Rata by Estimate total: update only plug and total
	if isProRataByEstimateTotal = 1
	then
	-- Calculate the sum of the children
		select sum(qac.Total) as ChildrenTotal
		  into childrenTotal
		  from QuoteAmountCache as qac
		 where qac.ItemParentId = itemParentId
		   and qac.QuoteId = quoteId;

		-- Add/Update change
		insert UpdatedQuoteAmount (QuoteAmountId, QuoteId, Type, IsFixed, Rate, Total, IsDeletePlug, IsAddPlug)
		select parentQuoteAmountId
			 , quoteId
			 , quoteAmountTypeCalculated
			 , isFixed
			 , null
			 , childrenTotal
			 , isDeletePlug
			 , isAddPlug
			on duplicate key
		update IsFixed      = isFixed
			 , Total        = childrenTotal
			 , IsDeletePlug = isDeletePlug
			 , IsAddPlug    = isAddPlug;

		-- Update cache
		update QuoteAmountCache as qac
		   set qac.Total        = childrenTotal
			 , qac.IsPicked     = if(childrenTotal is null, 0, qac.IsPicked) -- unpick empty
			 , qac.IsIncluded   = if(isDeletePlug, 0, qac.IsIncluded)        -- remove 'Include' if necessary
			 , qac.IsExcluded   = if(isDeletePlug, 0, qac.IsExcluded)        -- remove 'Exclude' if necessary
			 , qac.IsTempOrFill = if(isDeletePlug, 0, qac.IsTempOrFill)      -- remove 'Temp' and 'Fill' if necessary
		 where qac.QuoteAmountId = parentQuoteAmountId;

	else

	-- Break manual total if parent does not have recalculable children
	if isRecalculable = 0
	then
		if isFixed = 1 and pIsManualTotalRemovalAllowed = 0
		then
			signal sqlstate '45000' set message_text = '1|Removal of the manual total is required.';
		end if;

		set isFixed = null;
	end if;

	-- If it is not a manual total
	if ifnull(isFixed, 0) = 0
	then
	  -- Calculate the sum of the children
	  select sum(qac.Total) as ChildrenTotal
		into childrenTotal
		from QuoteAmountCache as qac
	   where qac.ItemParentId = itemParentId
		 and qac.QuoteId = quoteId;

	  if childrenTotal is null
	  then
		set isFixed = null;
	  end if;

	  -- Add/Update change
	  insert UpdatedQuoteAmount (QuoteAmountId, QuoteId, Type, IsFixed, Rate, Total, IsDeletePlug, IsAddPlug)
	  select parentQuoteAmountId
		   , quoteId
		   , quoteAmountTypeCalculated
		   , isFixed
		   , null
		   , childrenTotal
		   , isDeletePlug
		   , isAddPlug
		  on duplicate key
	  update IsFixed      = isFixed
		   , Total        = childrenTotal
		   , IsDeletePlug = isDeletePlug
		   , IsAddPlug    = isAddPlug;

	  -- Update cache
	  update QuoteAmountCache as qac
		 set qac.Total        = childrenTotal
		   , qac.IsFixed      = isFixed
		   , qac.IsPicked     = if(childrenTotal is null, 0, qac.IsPicked) -- unpick empty
		   , qac.IsIncluded   = if(isDeletePlug, 0, qac.IsIncluded)        -- remove 'Include' if necessary
		   , qac.IsExcluded   = if(isDeletePlug, 0, qac.IsExcluded)        -- remove 'Exclude' if necessary
		   , qac.IsTempOrFill = if(isDeletePlug, 0, qac.IsTempOrFill)      -- remove 'Temp' and 'Fill' if necessary
		   , qac.IsEmpty      = if(childrenTotal is null and qac.IsNoted = 0 and qac.IsHeading = 0, 1, 0)
	   where qac.QuoteAmountId = parentQuoteAmountId;

	else
	  -- Dont visit parent if it is a manual total and it has recalculable children
	  set isRecalculateChildren = 1;
	end if;

  end if; -- if isProRataByEstimateTotal = 1

  -- Remove processed parent
	delete ptpi
	from ParentTradePackageItem as ptpi
	where ptpi.ItemId  = itemParentId
	and ptpi.QuoteId = quoteId;

		-- Recalculate children
	if isRecalculateChildren = 1
	then

		call QuoteAmountUpdateRecalculableChildren(itemParentId);
	else
		  -- Insert parent into parent table for next iteration
		INSERT Ignore ParentTradePackageItem (ItemId, QuoteId, Level, IsProRataByEstimateTotal)
        		 SELECT qac.ItemParentId, 
						quoteId,
						qac.ItemParentLevel,
						isProRataByEstimateTotal
				 FROM   QuoteAmountCache as qac	
				 WHERE  qac.ItemId  = itemParentId
				 AND    qac.QuoteId = quoteId
				 AND    qac.ItemParentId IS NOT NULL
				 LIMIT 1; 
        
	end if;
  end while; -- while exists(select null from ParentTradePackageItem)

  -- Trade package items that have unpicked quote amounts
  insert UnpickedTradePackageItem (ItemId, PackageId)
  select qac.ItemId
       , qac.PackageId
    from QuoteAmountXml   as qax
    join QuoteAmountCache as qac on qac.QuoteAmountId = qax.QuoteAmountId
   where qax.Total is null
     and qac.TotalOriginal is not null;

  -- Quote summary
  insert QuoteSummary (QuoteId, ItemCount, PickedCount, CompletedCount, Total, PickedTotal, PickedPlugsTotal, PickedEstimateAdjustmentTotal, PlugsTotal, IsPicked)
  select qac.QuoteId
       , count(1)                                                         as ItemCount
       , sum(if(qac.IsPicked = 1, 1, 0))                                  as PickedCount
       , sum(if(qac.Total is not null, 1, 0))                             as CompletedCount
       , sum(qac.Total)                                                   as Total
       , sum(if(qac.IsPicked = 1, qac.Total, 0))                          as PickedTotal
       , sum(if(qac.IsPicked = 1 and qac.IsTempOrFill = 1, qac.Total, 0)) as PickedPlugsTotal
       , sum(if(qac.IsPicked = 1, qac.Total - qac.ItemTotal, 0))          as PickedEstimateAdjustmentTotal
       , sum(if(qac.IsTempOrFill = 1, qac.Total, 0))                      as PlugsTotal
       , 0                                                                as IsPicked  -- update later
    from QuoteAmountCache as qac
   where qac.IsNoted   = 0
     and qac.IsHeading = 0
group by qac.QuoteId;

  -- Quote summary: update 'IsPicked'
  update QuoteSummary as qs
     set qs.IsPicked = if(qs.PickedCount > 0 and qs.PickedCount = qs.ItemCount, 1, 0);

  -- [ ------------------------------------------------------------------------------------------ ]
  -- [ -------------------------------------- SAVE SECTION -------------------------------------- ]
  -- [ ------------------------------------------------------------------------------------------ ]

  start transaction;

  -- Delete plugs
  delete pqa
    from PlugQuoteAmount as pqa
    join UpdatedQuoteAmount as uqa on uqa.QuoteAmountId = pqa.QuoteAmountId
   where uqa.IsDeletePlug = 1;

  -- Update quote amounts
  update QuoteAmount as qa
    join UpdatedQuoteAmount as uqa on uqa.QuoteAmountId = qa.Id
     set qa.Type        = uqa.Type
       , qa.Rate        = uqa.Rate
       , qa.Total       = uqa.Total
       , qa.IsFixed     = uqa.IsFixed
       , qa.IsPicked    = if(uqa.Total is null,    0, qa.IsPicked)
       , qa.PickedOn    = if(uqa.Total is null, null, qa.PickedOn)
       , qa.PickedBy    = if(uqa.Total is null, null, qa.PickedBy)
       , qa.MergeStatus = mergeStatusDone;

  -- Add plugs
  insert PlugQuoteAmount (QuoteAmountId, PlugId)
  select uqa.QuoteAmountId
       , p.Id
    from UpdatedQuoteAmount as uqa
    join Plug as p on p.Type = plugTypeInclude
   where uqa.IsAddPlug = 1;

  -- Update quote
  update Quote as q
    join QuoteSummary as qs on qs.QuoteId = q.Id
     set q.Total                         = qs.Total
       , q.IsPicked                      = qs.IsPicked
       , q.PickedTotal                   = qs.PickedTotal
       , q.PickedCount                   = qs.PickedCount
       , q.PickedPlugsTotal              = qs.PickedPlugsTotal
       , q.PickedEstimateAdjustmentTotal = qs.PickedEstimateAdjustmentTotal
       , q.PlugsTotal                    = qs.PlugsTotal
       , q.CompletedCount                = qs.CompletedCount;

  -- Update trade package and trade package item if smth was unpicked
  if exists(select null from UnpickedTradePackageItem)
  then
    -- Update trade package item
    update TradePackageItem as tpi
      join UnpickedTradePackageItem as utpi on utpi.ItemId = tpi.Id
       set tpi.IsPicked = if(exists(select null from QuoteAmountCache as qac where qac.ItemId = tpi.Id and qac.IsPicked = 1), 1, 0);

    -- Trade package summary
    insert TradePackageSummary (TradePackageId, PickedCount, PickedItemsEstimate)
    select tpi.TradePackageId
         , count(1)       as PickedCount
         , sum(tpi.Total) as PickedItemsEstimate
      from TradePackageItem as tpi
     where tpi.TradePackageId in (select distinct utpi.PackageId from UnpickedTradePackageItem as utpi)
       and tpi.IsHeading = 0
       and tpi.IsPicked  = 1
  group by tpi.TradePackageId;

    -- Update trade package
    update TradePackage as tp
      join TradePackageSummary as tps on tps.TradePackageId = tp.Id
       set tp.PickedCount         = tps.PickedCount
         , tp.PickedItemsEstimate = tps.PickedItemsEstimate;
  end if;

  -- Commit changes
  commit;

    select uqa.QuoteAmountId
         , qac.ItemId as TradePackageItemId
         , uqa.QuoteId
         , uqa.Type
         , uqa.Rate
         , uqa.Total
         , uqa.IsFixed
         , qac.IsPicked
         , mergeStatusDone as MergeStatus
         , p.Type          as PlugType
      from UpdatedQuoteAmount as uqa
      join QuoteAmountCache   as qac on qac.QuoteAmountId = uqa.QuoteAmountId
 left join PlugQuoteAmount    as pqa on pqa.QuoteAmountId = uqa.QuoteAmountId
 left join Plug               as   p on p.Id              = pqa.PlugId;

end $$

delimiter ;