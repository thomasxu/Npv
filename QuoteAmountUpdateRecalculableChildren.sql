delimiter $$

drop procedure if exists bartender.QuoteAmountUpdateRecalculableChildren $$

create procedure bartender.QuoteAmountUpdateRecalculableChildren(
  pItemParentId int
)
begin
	  declare quoteAmountTypeCalculated tinyint(3) default 2; -- Calculated

	  drop temporary table if exists
		   QuoteAmountRecalculable
		 , QuoteAmountRecalculableTree
		 , QuoteAmountRecalculableParent
		 , QuoteAmountRecalculableBuffer
		 , QuoteAmountNonRecalculableGroup
		 , UpdatedQuoteAmountBuffer;

	  create temporary table QuoteAmountRecalculableTree ( QuoteAmountId    int not null primary key
														 , QuoteId          int not null
														 , ItemId           int not null
														 , ItemParentId     int
														 , ItemTotal        decimal(28, 16)
														 , IsFixed          boolean
														 , IsNoted          boolean not null
														 , IsHeading        boolean not null
														 , IsRecalculable   boolean not null
														 , FactoredQuantity decimal(28, 16)
														 , Total            decimal(28, 16)
														 ) engine=memory;

	  create temporary table QuoteAmountRecalculable ( QuoteAmountId    			int not null primary key
													 , QuoteId          			int not null
													 , ItemId           			int not null
													 , ItemParentId     			int
													 , ItemTotal        			decimal(28, 16)
													 , IsFixed          			boolean
													 , IsNoted          			boolean not null
													 , IsHeading        			boolean not null
													 , IsRecalculable   			boolean not null
													 , FactoredQuantity 			decimal(28, 16)
													 , Total            			decimal(28, 16)
													 ) engine=memory;

	  create temporary table QuoteAmountRecalculableParent ( ItemId        int not null
														   , QuoteId       int not null
														   , ItemParentId  int
														   , ItemTotal     decimal(28, 16)
														   , Total         decimal(28, 16)
														   , primary key (ItemId, QuoteId)
														   ) engine=memory;

	  create temporary table QuoteAmountNonRecalculableGroup ( QuoteId                 int not null
															 , ItemParentId            int not null
															 , NonRecalculableEstimate decimal(28, 16)
															 , NonRecalculableTotal    decimal(28, 16)
															 , primary key (QuoteId, ItemParentId)
															 ) engine=memory;

	  create temporary table QuoteAmountRecalculableBuffer ( QuoteAmountId        				int not null primary key
														   , QuoteId              				int not null
														   , ItemParentId                       int
														   , RecalculableSiblingCount          int
														   , ItemTotal            				decimal(28, 16)
														   , IsFixed              				boolean
														   , IsHeading            				boolean not null
														   , FactoredQuantity     				decimal(28, 16)
														   , RecalculableEstimate 				decimal(28, 16)
														   , RecalculableTotal    				decimal(28, 16)
														   , ProRataRatio         				decimal(28, 16)
														   , NewTotal             				decimal(28, 16)
														   ) engine=memory;

	  create temporary table UpdatedQuoteAmountBuffer ( QuoteAmountId int not null primary key
													  , QuoteId       int not null
													  , Type          tinyint(3) not null
													  , IsFixed       boolean
													  , Rate          decimal(28, 16)
													  , Total         decimal(28, 16)
													  , IsDeletePlug  boolean not null
													  , IsAddPlug     boolean not null
													  ) engine=memory;

	  -- Build tree to simplify recursion tasks
	  if not exists(select null from TradePackageItemTree)
	  then
		call QuoteAmountUpdateItemTree();
	  end if;

	  insert QuoteAmountRecalculableTree (QuoteAmountId, QuoteId, ItemId, ItemParentId, ItemTotal, FactoredQuantity, Total, IsNoted, IsFixed, IsHeading, IsRecalculable)
	  select qac.QuoteAmountId
		   , qac.QuoteId
		   , qac.ItemId
		   , qac.ItemParentId
		   , qac.ItemTotal
		   , qac.FactoredQuantity
		   , qac.Total
		   , qac.IsNoted
		   , qac.IsFixed
		   , qac.IsHeading
		   , if(qac.IsNoted = 0 and qac.IsIncluded, 1, 0)
		from TradePackageItemTree as tpit
		join QuoteAmountCache     as qac on qac.ItemId = tpit.Descendant
	   where tpit.Ancestor = pItemParentId;
	   
	  insert QuoteAmountRecalculableParent (ItemId, QuoteId, ItemParentId, ItemTotal, Total)
	  select qart.ItemId
		   , qart.QuoteId
		   , qart.ItemParentId
		   , qart.ItemTotal
		   , qart.Total
		from QuoteAmountRecalculableTree as qart
	   where qart.ItemId = pItemParentId;

	  while exists(select null from QuoteAmountRecalculableParent)
	  do
		insert QuoteAmountRecalculable (QuoteAmountId, QuoteId, ItemId, ItemParentId, ItemTotal, FactoredQuantity, Total, IsNoted, IsFixed, IsHeading, IsRecalculable)
		select qart.QuoteAmountId
			 , qart.QuoteId
			 , qart.ItemId
			 , qart.ItemParentId
			 , qart.ItemTotal
			 , qart.FactoredQuantity
			 , qart.Total
			 , qart.IsNoted
			 , qart.IsFixed
			 , qart.IsHeading
			 , qart.IsRecalculable
		  from QuoteAmountRecalculableTree as qart
		  join QuoteAmountRecalculableParent as qarp on qarp.ItemId = qart.ItemParentId and qarp.QuoteId = qart.QuoteId
		 where qart.IsRecalculable = 1;
		 
		insert QuoteAmountNonRecalculableGroup (QuoteId, ItemParentId, NonRecalculableEstimate, NonRecalculableTotal)
		select qart.QuoteId
			 , qart.ItemParentId
			 , sum(qart.ItemTotal) as NonRecalculableEstimate
			 , sum(qart.Total)     as NonRecalculableTotal
		  from QuoteAmountRecalculableTree as qart
		  join QuoteAmountRecalculableParent as qarp on qarp.ItemId = qart.ItemParentId and qarp.QuoteId = qart.QuoteId
		 where qart.IsRecalculable = 0
		   and qart.ItemParentId is not null
	  group by qart.QuoteId
			 , qart.ItemParentId;

	

		
		insert QuoteAmountRecalculableBuffer (QuoteAmountId, QuoteId, ItemParentId, RecalculableSiblingCount, ItemTotal, IsFixed, IsHeading, FactoredQuantity, RecalculableTotal, RecalculableEstimate, ProRataRatio, NewTotal)
		select qar.QuoteAmountId
			 , qar.QuoteId
			 , qar.ItemParentId
			 , null /*default set to null, it gets update after insert */
			 , qar.ItemTotal
			 , qar.IsFixed
			 , qar.IsHeading
			 , qar.FactoredQuantity
			 , ifnull(qarp.Total, 0)     - ifnull(qanrg.NonRecalculableTotal,    0) as RecalculableTotal
			 , ifnull(qarp.ItemTotal, 0) - ifnull(qanrg.NonRecalculableEstimate, 0) as RecalculableEstimate
			 , null as ProRataRatio
			 , null as NewTotal
		  from QuoteAmountRecalculable         as qar
		  join QuoteAmountRecalculableParent   as qarp  on qarp.ItemId        = qar.ItemParentId and qarp.QuoteId  = qar.QuoteId
	 left join QuoteAmountNonRecalculableGroup as qanrg on qanrg.ItemParentId = qar.ItemParentId and qanrg.QuoteId = qar.QuoteId
		 where qar.IsNoted = 0;
		 
		 
		   -- Update recalculable sibling count
		 UPDATE QuoteAmountRecalculableBuffer as qarb 
		 JOIN (
			SELECT qar.QuoteId, qar.ItemParentId, count(*) as RecalculableCount
			FROM QuoteAmountRecalculable as qar
		  GROUP BY qar.QuoteId, qar.ItemParentId
		 ) as Recalculable
		 ON Recalculable.QuoteId = qarb.QuoteId
		 AND Recalculable.ItemParentId = qarb.ItemParentId
		 SET qarb.RecalculableSiblingCount = Recalculable.RecalculableCount;
		 
		-- Calculate ratio
		update QuoteAmountRecalculableBuffer
		   set ProRataRatio = if(RecalculableEstimate <> 0, ifnull(ItemTotal, 0) / RecalculableEstimate, null);

		-- Calculate total
		update QuoteAmountRecalculableBuffer
		   set NewTotal = if(ProRataRatio is not null, RecalculableTotal * ProRataRatio, RecalculableTotal / RecalculableSiblingCount);

		-- Put changes into buffer  
		insert UpdatedQuoteAmountBuffer (QuoteAmountId, QuoteId, Type, IsFixed, Rate, Total, IsDeletePlug, IsAddPlug)
		select qarb.QuoteAmountId
			 , qarb.QuoteId
			 , quoteAmountTypeCalculated
			 , qarb.IsFixed
			 , if(ifnull(qarb.FactoredQuantity, 0) <> 0, qarb.NewTotal / qarb.FactoredQuantity, if(qarb.IsHeading = 1, null, 0)) as NewRate
			 , qarb.NewTotal
			 , 0
			 , 0
		  from QuoteAmountRecalculableBuffer as qarb;

		insert UpdatedQuoteAmount (QuoteAmountId, QuoteId, Type, IsFixed, Rate, Total, IsDeletePlug, IsAddPlug)
		select uqab.QuoteAmountId
			 , uqab.QuoteId
			 , uqab.Type
			 , uqab.IsFixed
			 , uqab.Rate
			 , uqab.Total
			 , uqab.IsDeletePlug
			 , uqab.IsAddPlug
		  from UpdatedQuoteAmountBuffer as uqab
			on duplicate key
		update Type  = uqab.Type
			 , Total = uqab.Total
			 , Rate  = uqab.Rate;

		truncate table QuoteAmountRecalculableParent;

		-- Skip manual totals
		insert QuoteAmountRecalculableParent (ItemId, QuoteId, ItemParentId, ItemTotal, Total)
		select qar.ItemId
			 , qar.QuoteId
			 , qar.ItemParentId
			 , qar.ItemTotal
			 , uqab.Total -- new total
		  from QuoteAmountRecalculable as qar
		  join UpdatedQuoteAmountBuffer as uqab on uqab.QuoteAmountId = qar.QuoteAmountId
		 where qar.IsHeading = 1
		   and (qar.IsFixed is null or qar.IsFixed = 0);
		

		truncate table QuoteAmountRecalculable;
		truncate table UpdatedQuoteAmountBuffer;
		truncate table QuoteAmountRecalculableBuffer;
		truncate table QuoteAmountNonRecalculableGroup;
		  
	  end while;

	  -- Update cache
	  call QuoteAmountUpdateCache();

end $$

delimiter ;