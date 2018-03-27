delimiter $$

drop procedure if exists bartender.QuoteAmountUpdateItemTree $$

create procedure bartender.QuoteAmountUpdateItemTree()
begin
  drop temporary table if exists TradePackageItemCache, TradePackageItemGroup, TradePackageItemParentBuffer, TradePackageItemChildrenBuffer, TradePackageItemTreeBuffer;

  create temporary table TradePackageItemCache (Id int not null primary key, ParentId int, Level int not null) engine=memory;
  create temporary table TradePackageItemGroup (ParentId int not null primary key, RowCount int not null) engine=memory;
  create temporary table TradePackageItemParentBuffer (Id int not null primary key, ParentId int, Level int not null) engine=memory;
  create temporary table TradePackageItemChildrenBuffer (Id int not null primary key, ParentId int, Level int not null) engine=memory;
  create temporary table TradePackageItemTreeBuffer (Ancestor int not null, Descendant int not null, Level int not null, DescendantRowCount int not null, DescendantRatio decimal(28, 16) not null, primary key (Ancestor, Descendant)) engine=memory;

  -- Item cache
  insert TradePackageItemCache (Id, ParentId, Level)
  select distinct
         qac.ItemId
       , qac.ItemParentId
       , qac.ItemParentLevel + 1
    from QuoteAmountCache as qac
   where qac.IsNoted = 0;

  -- Headings
  insert TradePackageItemGroup (ParentId, RowCount)
  select tpic.ParentId
       , count(*) as RowCount
    from TradePackageItemCache as tpic
   where tpic.ParentId is not null
group by tpic.ParentId;

  -- Root element
  insert TradePackageItemParentBuffer (Id, ParentId, Level)
  select tpic.Id
       , tpic.ParentId
       , tpic.Level
    from TradePackageItemCache as tpic
   where tpic.ParentId is null;

  -- Root children
  insert TradePackageItemChildrenBuffer (Id, ParentId, Level)
  select tpic.Id
       , tpic.ParentId
       , tpic.Level
    from TradePackageItemCache as tpic
    join TradePackageItemParentBuffer as tpipb on tpipb.Id = tpic.ParentId;

  -- Root element
  insert TradePackageItemTree (Ancestor, Descendant, Level, DescendantRowCount, DescendantRatio)
  select tpic.Id
       , tpic.Id
       , tpic.Level
       , 1
       , 1
    from TradePackageItemCache as tpic
   where tpic.ParentId is null;

  truncate table TradePackageItemParentBuffer;

  -- Build item tree to simplify recursion tasks
   while exists(select null from TradePackageItemChildrenBuffer)
   do
    -- Existing
    insert TradePackageItemTreeBuffer (Ancestor, Descendant, Level, DescendantRowCount, DescendantRatio)
    select tpit.Ancestor
         , tpic.Id
         , tpit.Level + 1
         , tpig.RowCount
         , tpit.DescendantRatio / tpig.RowCount
      from TradePackageItemTree           as tpit
      join TradePackageItemChildrenBuffer as tpic on tpic.ParentId = tpit.Descendant
      join TradePackageItemGroup          as tpig on tpig.ParentId = tpic.ParentId;
    
    -- Self
    insert TradePackageItemTreeBuffer (Ancestor, Descendant, Level, DescendantRowCount, DescendantRatio)
    select tpicb.Id
         , tpicb.Id
         , 0
         , 1
         , 1
      from TradePackageItemChildrenBuffer as tpicb;

    -- Tree
    insert TradePackageItemTree (Ancestor, Descendant, Level, DescendantRowCount, DescendantRatio)
    select tpitb.Ancestor
         , tpitb.Descendant
         , tpitb.Level
         , tpitb.DescendantRowCount
         , tpitb.DescendantRatio
      from TradePackageItemTreeBuffer as tpitb;

    truncate table TradePackageItemTreeBuffer;

    insert TradePackageItemParentBuffer (Id, ParentId, Level)
    select tpicb.Id
         , tpicb.ParentId
         , tpicb.Level
      from TradePackageItemChildrenBuffer as tpicb;

    truncate table TradePackageItemChildrenBuffer;

    insert TradePackageItemChildrenBuffer (Id, ParentId, Level)
    select tpic.Id
         , tpic.ParentId
         , tpic.Level
      from TradePackageItemCache as tpic
      join TradePackageItemParentBuffer as tpipb on tpipb.Id = tpic.ParentId;

    truncate table TradePackageItemParentBuffer;

  end while;

  drop temporary table if exists TradePackageItemCache, TradePackageItemGroup, TradePackageItemParentBuffer, TradePackageItemChildrenBuffer, TradePackageItemTreeBuffer;
end $$

delimiter ;