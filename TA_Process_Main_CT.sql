USE Paradise_AADH_CT
GO
if object_id('[dbo].[TA_Process_Main]') is null
	EXEC ('CREATE PROCEDURE [dbo].[TA_Process_Main] as select 1')
GO

ALTER PROCEDURE [dbo].[TA_Process_Main]
(
  @LoginID int = null
  ,@FromDate datetime = null
  ,@ToDate datetime = null
  ,@EmployeeID varchar(20) = '-1'
)
AS
SET NOCOUNT ON;
SET ANSI_WARNINGS OFF

if(OBJECT_ID('TA_ProcessMain_1Description' )is null)
begin
exec('CREATE PROCEDURE TA_ProcessMain_1Description
as
begin
 -- Viet Ghi chu quan trong o day
 SET NOCOUNT ON;
end')
end

if [dbo].[CheckIsRunningProc]('TA_Process_Main') = 1
return

DECLARE @IsAuditAccount bit
SET @IsAuditAccount = dbo.fn_CheckAuditAccount(@LoginID)
DECLARE @StopUpdate bit = 0, @p_ShiftID int, @p_AttStart datetime, @p_AttEnd datetime,@MaternityStatusID tinyint
BEGIN
 declare @OT_ROUND_UNIT int

 set @OT_ROUND_UNIT = (select cast(value as int) from tblParameter where code = 'OT_ROUND_UNIT')
 set @OT_ROUND_UNIT = isnull(@OT_ROUND_UNIT,1)
 IF @OT_ROUND_UNIT <=0 SET @OT_ROUND_UNIT = 1
 --Khoa Luong hay chua
 --  get Fromdate, ToDate from Pendding data
if @FromDate is null or @ToDate is NULL
BEGIN
 SELECT @FromDate = MIN(Date),  @ToDate = MAX(Date) FROM dbo.tblPendingTaProcessMain
 IF DATEDIFF(DAY, @FromDate,@ToDate) > 45
 BEGIN
  SET @ToDate = NULL
 end
END
if @FromDate is null or @ToDate is null
begin
 select @FromDate= ISNULL(@FromDate,Fromdate), @ToDate = isnull(@ToDate,Todate) from dbo.fn_Get_SalaryPeriod_ByDate(getdate())
end
-- neu @loginID is null thì xử lý toàn bộ nhan vien trong pending
IF @LoginID is NULL
BEGIN
SET @LoginID = 6900
DELETE dbo.tmpEmployeeTree WHERE LoginID = @LoginID
INSERT INTO tmpEmployeeTree(EmployeeID, LoginID)
SELECT DISTINCT EmployeeID, @LoginID FROM tblPendingTaProcessMain  WHERE Date BETWEEN @FromDate AND @ToDate
END
 SET @FromDate = DBO.Truncate_Date(@FromDate)
 SET @ToDate = DBO.Truncate_Date(@ToDate)

if(OBJECT_ID('TA_ProcessMain_PreConfigTAData' )is null)
begin
exec('CREATE PROCEDURE TA_ProcessMain_PreConfigTAData
(
  @FromDate datetime
 ,@ToDate datetime
 ,@LoginID int
 ,@IsAuditAccount bit
 ,@StopUpdate bit output
)
as
begin
 SET NOCOUNT ON;
end')
end
SET @StopUpdate = 0
EXEC TA_ProcessMain_PreConfigTAData @FromDate=@FromDate, @ToDate=@ToDate, @LoginID=@LoginID, @IsAuditAccount=@IsAuditAccount, @StopUpdate=@StopUpdate output

 select EmployeeID,e.FullName,e.EmployeeTypeID,e.PositionID ,e.DivisionID,e.DepartmentID,e.SectionID,e.GroupID,e.HireDate,e.TerminateDate,e.EmployeeStatusID
  into #tblEmployeeList
  from dbo.fn_vtblEmployeeList_Bydate(@ToDate,@EmployeeID,@LoginID) e

  insert into #tblEmployeeList(EmployeeID,FullName,EmployeeTypeID,PositionID ,DivisionID,DepartmentID,SectionID,GroupID
  ,HireDate,TerminateDate,EmployeeStatusID)
  select EmployeeID,vTo.FullName,vTo.EmployeeTypeID,vTo.PositionID ,vTo.DivisionID,vTo.DepartmentID,vTo.SectionID,vTo.GroupID
  ,vTo.HireDate,vTo.TerminateDate,vTo.EmployeeStatusID
  from dbo.fn_vtblEmployeeList_Bydate(@ToDate,@EmployeeID,@LoginID) as vTo
  where not exists(select 1 from #tblEmployeeList as vFrom where vFrom.EmployeeID = vTo.EmployeeID)
 -- thêm cột này trong tblemployeeType để làm late_permit nha
 if(not exists(select 1 from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME = 'tblEmployeeType' and COLUMN_NAME = 'LATE_PERMIT'))
 begin
  alter table tblEmployeeType add LATE_PERMIT float
 end
 if(not exists(select 1 from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME = 'tblDivision' and COLUMN_NAME = 'LATE_PERMIT'))
 begin
  alter table tblDivision add LATE_PERMIT float
 end
 if(not exists(select 1 from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME = 'tblDepartment' and COLUMN_NAME = 'LATE_PERMIT'))
 begin
  alter table tblDepartment add LATE_PERMIT float
 end
 if(not exists(select 1 from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME = 'tblSection' and COLUMN_NAME = 'LATE_PERMIT'))
 begin
  alter table tblSection add LATE_PERMIT float
 end
 if(not exists(select 1 from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME = 'tblGroup' and COLUMN_NAME = 'LATE_PERMIT'))

 begin
  alter table tblGroup add LATE_PERMIT float
 end
 if(not exists(select 1 from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME = 'tblPosition' and COLUMN_NAME = 'LATE_PERMIT'))
 begin
  alter table tblPosition add LATE_PERMIT float
 end
 if(not exists(select 1 from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME = 'tblEmployee' and COLUMN_NAME = 'LATE_PERMIT'))
 begin
  alter table tblEmployee add LATE_PERMIT float
 end
--------------------------------Lay dk cua Employee--------------------------------------------------------------
CREATE TABLE #tmpEmployee(EmployeeID  varchar(20),FullName nvarchar(500),EmployeeTypeID int,LATE_PERMIT float, PositionID int primary key(EmployeeID),DivisionID int, DepartmentID int,SectionID int,GroupID int )

INSERT INTO #tmpEmployee(EmployeeID,FullName,EmployeeTypeID,LATE_PERMIT,PositionID ,DivisionID,DepartmentID,SectionID,GroupID )
SELECT EmployeeID,e.FullName,e.EmployeeTypeID,et.LATE_PERMIT,e.PositionID ,e.DivisionID,e.DepartmentID,e.SectionID,e.GroupID
FROM #tblEmployeeList e
left join tblEmployeeType et on e.EmployeeTypeID =  et.EmployeeTypeID
WHERE HireDate <= @ToDate and (TerminateDate is null or EmployeeStatusID <> 20 or TerminateDate > @FromDate)
and (EmployeeID = @EmployeeID or (@EmployeeID = '-1' and e.EmployeeID in (select EmployeeID from tmpEmployeeTree where LoginID = @LoginID)))

--update nguoc len
update te
set te.LATE_PERMIT = n.LATE_PERMIT
from #tmpEmployee as te
inner join tblDivision as n on n.DivisionID = te.DivisionID
where n.LATE_PERMIT is not null

update te
set te.LATE_PERMIT = n.LATE_PERMIT
from #tmpEmployee as te
inner join tblDepartment as n on n.DepartmentID = te.DepartmentID
where n.LATE_PERMIT is not null

update te
set te.LATE_PERMIT = n.LATE_PERMIT
from #tmpEmployee as te
inner join tblSection as n on n.SectionID = te.SectionID
where n.LATE_PERMIT is not null

update te
set te.LATE_PERMIT = n.LATE_PERMIT
from #tmpEmployee as te
inner join tblGroup as n on n.GroupID = te.GroupID
where n.LATE_PERMIT is not null

update te
set te.LATE_PERMIT = n.LATE_PERMIT
from #tmpEmployee as te
inner join tblPosition as n on n.PositionID = te.PositionID
where n.LATE_PERMIT is not null

update te
set te.LATE_PERMIT = n.LATE_PERMIT
from #tmpEmployee as te
inner join tblEmployee as n on n.EmployeeID = te.EmployeeID
where n.LATE_PERMIT is not null

select distinct EmployeeID, [Date]
into #tblPendingTaProcessMain
from tblPendingTaProcessMain where Date between @FromDate and @ToDate
and EmployeeID in (select EmployeeID from #tmpEmployee)

if ROWCOUNT_BIG() <=0
return

create nonclustered index  ix_tmpEmployee_tapro on  #tmpEmployee(EmployeeID)

select distinct EmployeeID, [Date] as LockDate
into #DateLocked from vAttLockDateStatus al where al.AttDate between @FromDate and @ToDate
 and al.EmployeeID in (select EmployeeID from #tmpEmployee) and al.Locked = 1

if @IsAuditAccount = 1
begin
 truncate table #DateLocked
end
insert into tblProcessErrorMessage(ErrorType,ErrorDetail,LoginID)
select e.FullName +  N'-Dữ liệu chấm công đã bị khóa',N'Từ :'+CONVERT(VARCHAR(10),MIN(LockDate),103)+N' đến '+CONVERT(VARCHAR(10),MAX(LockDate),103) ,@LoginID
from #DateLocked al
inner join #tmpEmployee e on al.EmployeeID = e.EmployeeID
group by al.EmployeeID , e.FullName

delete #tblPendingTaProcessMain from #tblPendingTaProcessMain t inner join #DateLocked l on t.EmployeeID = l.EmployeeID and t.[Date] = l.LockDate

delete #tmpEmployee where EmployeeID not in (select distinct EmployeeID from #tblPendingTaProcessMain)
delete #tblEmployeeList where EmployeeID not in (select distinct EmployeeID from #tblPendingTaProcessMain)


declare @Month int, @Year int
select @Month = Month, @Year = Year from dbo.fn_Get_Sal_Month_Year(dateadd(day,datediff(day,@FromDate, @ToDate)/2,@FromDate))
select bz.EmployeeId, bz.FromDate, bz.ToDate, pr.ProjectName, bz.Month, bz.Year, bz.ProjectID, BusinessTripType ,IsModified
into #tblBusinessTrip
from dbo.fn_tblBusinessTrip_ByMonthYear(@month,@Year) bz left join tblBusinessTripProject pr on bz.ProjectID = pr.ProjectID
where exists (select 1 from #tmpEmployee te where bz.employeeID = te.EmployeeID)
and (bz.BusinessTripType in(1,2) or bz.StayInConstruction = 1)
-- xoa nhung record bi trung
delete b from #tblBusinessTrip b where exists (select 1 from #tblBusinessTrip bz where b.EmployeeId = bz.EmployeeId and b.FromDate = bz.FromDate and b.Month + b.Year * 12 < bz.Month + bz.Year * 12)



create clustered index indextblPendingTaProcessMain on #tblPendingTaProcessMain (EmployeeID,[Date])

exec ('Disable trigger ALL on tblWSchedule')
exec ('Disable trigger ALL on tblHasTA')
exec ('Disable trigger ALL on tblLvhistory')
------------------------------------------------------------------------------------------------------------------
 CREATE TABLE #tmpHasTA
    (
     EmployeeID  nvarchar(20),
     AttDate  datetime,
Period  int,
     ShiftID  int,
     DayType  int,
     LeaveStatus int,
  LvAmount float,
     AttStart datetime, -- Gio bat dau lam viec
     AttEnd  datetime, -- Gio ket thuc lam viec
  WorkingTime float,
     WorkStart datetime, -- Gio bat dau cua ca
     WorkEnd  datetime, -- Gio ket thuc cua ca,
 BreakStart datetime, -- Gio bat dau nghi giua ca(ket thuc lam nua ngay dau)
     BreakEnd datetime, -- Gio ket thu nghi giua ca(bat dau lam viec nua ngay cuoi)

 MiAttStart int,  -- Doi gio bat dau lam viec ra phut so voi AttDate
     MiAttEnd int,  -- Doi gio ket thuc lam viec ra phut so voi AttDate
     MinAttStartMi int,
     MaxAttEndMi int,
     MiWorkStart int,  -- Doi gio bat dau cua ca ra phut so voi AttDate
     MiWorkEnd int,  -- Doi gio ket thuc cua ca ra phut so voi AttDate
     MiBreakStart int,
     MiBreakEnd  int,

     SiAttStart float,  -- Doi gio bat dau lam viec ra giay so voi AttDate de tinh In late, out early
     SiAttEnd float,  -- Doi gio ket thuc lam viec ra giay so voi AttDate de tinh In late, out early
     SiWorkStart float,  -- Doi gio bat dau cua ca ra giay so voi AttDate de tinh In late, out early
     SiWorkEnd float,   -- Doi gio ket thuc cua ca ra giay so voi AttDate de tinh In late, out early
  IsMaternity bit,
  DateStatus int
  ,Holidaystatus int
   )

   CREATE TABLE #ShiftInfo(
  ShiftID INT,
  OTBeforeStart DATETIME,
  OTBeforeEnd DATETIME,
  WorkStart DATETIME,
  WorkEnd DATETIME,
  BreakStart DATETIME,
  BreakEnd DATETIME,
  OTAfterStart DATETIME,
  OTAfterEnd DATETIME,
  MiDeductBearkTime INT,
  Std_hours float,
  IsNightShift bit,
 MIWorkStart int,
 MIWorkEnd int,
 MIOTAfterStart int,
 MIOTBeforeEnd int
 )
-- Maternity Process - Xu ly nhan vien sau ho san
 declare @MATERNITY_MUNITE int
 SET @MATERNITY_MUNITE = (select cast([value] as int) from tblParameter where code = 'MATERNITY_MUNITE')
 SET @MATERNITY_MUNITE = isnull(@MATERNITY_MUNITE,60)

 create table #Maternity(
  EmployeeID varchar(20),
  BornDate datetime,
  EndDate datetime,
  MinusMin int
 )
 declare @countTotal int
 insert into #Maternity (EmployeeID, BornDate)
 select EmployeeID, Max(ChangedDate) ChangedDate from dbo.fn_EmployeeStatus_ByDate(@ToDate)
  where EmployeeStatusID in (10,11) and EmployeeID in (select distinct EmployeeID from #tmpEmployee)
  group  by EmployeeID
  SET @countTotal = @@ROWCOUNT
 insert into #Maternity (EmployeeID, BornDate)
 select EmployeeID, Max(ChangedDate) ChangedDate from dbo.fn_LastEmployeeStatus_ByDate(@ToDate) l
  where EmployeeStatusID in (10,11)
  and EmployeeID in (select distinct EmployeeID from #tmpEmployee)
  and not exists(select 1 from #Maternity m where l.EmployeeID = m.EmployeeID)
  group  by EmployeeID
 SET @countTotal += @@ROWCOUNT

 if @countTotal > 0
 begin
  update #Maternity SET EndDate = StatusEndDate from #Maternity mt
  inner join tblEmployeeStatusHistory sh
  on mt.EmployeeID = sh.EmployeeID and sh.EmployeeStatusID in (10,11) and sh.ChangedDate = BornDate and StatusEndDate is not null
update #Maternity SET EndDate = dateadd(year, 1, BornDate) where EndDate IS NULL
  update #Maternity SET MinusMin = @MATERNITY_MUNITE

  update #Maternity SET EndDate = DATEADD(day,-1,t.ChangedDate)
   from #Maternity m
   inner join
  (select sh.EmployeeID, sh.ChangedDate from tblEmployeeStatusHistory sh
   inner join #tmpEmployee te on sh.EmployeeID = te.EmployeeID
   inner join #tblEmployeeList t on te.EmployeeID = t.EmployeeID and sh.EmployeeStatusID = t.EmployeeStatusID
   inner join #Maternity m on sh.EmployeeID = m.EmployeeID and sh.ChangedDate > m.BornDate
   ) t on m.EmployeeID = t.EmployeeID
  delete #Maternity where EndDate < @FromDate
 end

------------------------------------------Do du lieu vao bang #tmpHasTA------------------------------------------------
 select ShiftId,datepart(hh,WorkStart)  as HHWorkStart
 ,isnull(datepart(mi,WorkStart),0) as MiWorkStart
 ,isnull( datepart(hh,WorkEnd),0) as HHWorkEnd
 ,isnull( datepart(mi,WorkEnd),0) as MiWorkEnd
 ,isnull(datepart(hh,BreakStart),0) as HHBreakStart
 ,isnull(datepart(MI,BreakStart),0) as MIBreakStart
 ,isnull( datepart(hh,BreakEnd),0)  as HHBreakEnd
 ,isnull( datepart(mi,BreakEnd),0)  as MIBreakEnd
 ,S.WorkStart, S.WorkEnd, S.BreakStart, S.BreakEnd
 into #MiniShiftSetting from
 tblShiftSetting s

 select ta.EmployeeID, ta.AttDate,ta.AttStart,ta.AttEnd,ta.WorkingTime,ta.[Period], TAStatus, CAST(NULL as int) minAttStart,CAST(NULL as int) maxAttEnd
 into #tblHasTA_Org from tblHasTA ta
 inner join #tblPendingTaProcessMain p on ta.EmployeeID = p.EmployeeID and ta.AttDate = p.[Date]
 where @IsAuditAccount = 0

 if @IsAuditAccount = 1
 begin
  insert into #tblHasTA_Org(EmployeeID,AttDate,AttStart,AttEnd,WorkingTime,[Period],TAStatus)
  select ta.EmployeeID, ta.AttDate,ta.AttStart,ta.AttEnd,ta.WorkingTime,ta.[Period],ta.TAStatus
  from tblHasTA_CT ta inner join #tblPendingTaProcessMain p on ta.EmployeeID = p.EmployeeID and ta.AttDate = p.[Date]
 end

 UPDATE #tblHasTA_Org SET minAttStart = DATEPART(hh,AttStart)+DATEPART(mi,AttStart), maxAttEnd = DATEPART(hh,AttEnd)+DATEPART(mi,AttEnd)

 select lv.* into #tblLvHistoryP from tblLvHistory lv inner join #tblPendingTaProcessMain p on lv.EmployeeID = p.EmployeeID and lv.LeaveDate = p.[Date]

 select w.EmployeeID, w.ScheduleDate, w.ShiftID,w.HolidayStatus, w.DateStatus
 into #tblWSchedule from tblWSchedule w inner join #tblPendingTaProcessMain p on w.EmployeeID = p.EmployeeID and w.ScheduleDate = p.[Date]

 INSERT INTO #tmpHasTA (EmployeeID, AttDate, Period, ShiftID, DayType, AttStart, AttEnd, WorkStart, WorkEnd, BreakStart, BreakEnd,LeaveStatus,LvAmount,WorkingTime,IsMaternity
  ,MiAttStart,MiAttEnd,MiWorkStart,MiWorkEnd,MiBreakStart,MiBreakEnd,MinAttStartMi,MaxAttEndMi,DateStatus,Holidaystatus
 )
 SELECT H.EmployeeID, H.AttDate, H.Period, W.ShiftID, W.HolidayStatus, H.AttStart, H.AttEnd, S.WorkStart, S.WorkEnd, S.BreakStart, S.BreakEnd,case when h.Period <> 3 then ISNULL(tlh.LeaveStatus,0) else 0 end,tlh.LvAmount,h.WorkingTime
 ,case when m.EmployeeID is not null then 1 else 0 end
 , DATEDIFF(mi,h.AttDate,AttStart) as  MiAttStart
 , DATEDIFF(mi,h.AttDate,AttEnd) as MiAttEnd
 , case when  DATEDIFF(mi,h.AttDate,AttStart)  > tmp.minAttStart and Period = 1  then MiBreakEnd else( isnull( HHWorkStart*60,0) +MiWorkStart) end as MiWorkStart
 ,case when DATEDIFF(mi,h.AttDate,AttStart) = tmp.minAttStart and DATEDIFF(mi,h.AttDate,AttEnd) < tmp.maxAttEnd and Period = 0  then MiBreakStart else (HHWorkEnd*60 +MiWorkEnd
  +case when HHWorkEnd < HHWorkStart then 1440 else 0 end) end as MiWorkEnd
 , HHBreakStart*60+ MIBreakStart
 + case when  HHWorkStart > HHBreakStart then 1440 else 0 end as MiBreakStart
 , HHBreakEnd *60 +MIBreakEnd
 + case when HHWorkStart > HHBreakEnd then 1440 else 0 end as MiBreakEnd
 ,tmp.minAttStart  as MinAttStartMi
 ,tmp.maxAttEnd as MaxAttEndMi
 ,w.DateStatus
 ,w.HolidayStatus
 FROM #tblHasTA_Org H inner join #tblWSchedule W on H.EmployeeID = W.EmployeeID and H.AttDate = W.ScheduleDate
 left join #MiniShiftSetting S on W.ShiftID = S.ShiftID
 left join #Maternity as M on H.EmployeeID = M.EmployeeID and H.AttDate between M.BornDate and M.EndDate
 cross apply(select MAX(LeaveStatus) as LeaveStatus,sum(LvAmount) as LvAmount  from  #tblLvHistoryP tlh where h.EmployeeID = tlh.EmployeeID AND h.AttDate = tlh.LeaveDate  and tlh.LeaveCode in (select LeaveCode from  tblLeavetype lt where lt.LeaveCategory = 1 and tlh.LeaveCode not in ('FWC','BZ'))) tlh
 left join (select EmployeeID,AttDate,min(minAttStart) minAttStart,max(maxAttEnd) maxAttEnd from #tblHasTA_Org group by EmployeeID,AttDate) tmp
  on h.EmployeeID = tmp.EmployeeID and h.AttDate = tmp.AttDate
 WHERE (H.AttStart is not null or H.AttEnd is not null) -- Chi xu ly trong TH co day du gio vao va gio ra




 drop table #MiniShiftSetting

---------------------Chinh sua gio bat dau ca va ket thuc ca neu nghi nua ngay---------------------------------------------------

INSERT INTo #ShiftInfo(ShiftID,WorkStart,WorkEnd,BreakStart,BreakEnd,OTBeforeStart,OTBeforeEnd,OTAfterStart,OTAfterEnd, IsNightShift,MIWorkStart,MIWorkEnd,MIOTAfterStart,MIOTBeforeEnd)
SELECT ts.ShiftID,ts.WorkStart,ts.WorkEnd,ts.BreakStart,ts.BreakEnd,OTBeforeStart,OTBeforeEnd,OTAfterStart,OTAfterEnd, case when DATEPART(hh,WorkStart) > DATEPART(hh,WorkEnd) then 1 else 0 end
,datepart(Hour,WorkStart) *60 +datepart(MI,WorkStart)   as MIWorkStart
 ,datepart(Hour,WorkEnd) *60 +datepart(MI,WorkEnd)    as MIWorkEnd
 ,datepart(Hour,OTAfterStart) *60 +datepart(MI,OTAfterStart)   as MIOTAfterStart
 ,datepart(Hour,OTBeforeEnd) *60 +datepart(MI,OTBeforeEnd)   as MIOTBeforeEnd
FROM tblShiftSetting ts

------------------------------ Goi thu tuc tinh late early-------------------------------------------
 -- begin late early
if @IsAuditAccount = 0
BEGIN
 declare @IO_LE_ROUND_UNIT int,@DO_NOT_CARE_EARLY tinyint
 SET @IO_LE_ROUND_UNIT = (select cast(value as int) from tblParameter where code = 'IO_LE_ROUND_UNIT')
 SET @IO_LE_ROUND_UNIT = isnull(@IO_LE_ROUND_UNIT,6)
 IF @IO_LE_ROUND_UNIT <= 0 SET @IO_LE_ROUND_UNIT = 1
 -- 1: khong quan tam ve som
 -- 0: co thong ke so gio ve som
 SET @DO_NOT_CARE_EARLY = (select cast(value as int) from tblParameter where code = 'DO_NOT_CARE_EARLY')
 SET @DO_NOT_CARE_EARLY = isnull(@DO_NOT_CARE_EARLY,0)

 CREATE TABLE #ta_ptmpLateTmp
 (
  EmployeeID  nvarchar(20),
  AttDate  datetime,
  Period  int,
  ShiftID  int,

  AttStart datetime, -- Gio bat dau lam viec
  AttEnd  datetime, -- Gio ket thuc lam viec

  SiAttStart float,  -- Doi gio bat dau lam viec ra giay so voi AttDate de tinh In late, out early
  SiAttEnd float,  -- Doi gio ket thuc lam viec ra giay so voi AttDate de tinh In late, out early
  SiBreakStart float,
  SiBreakEnd float,
  SiWorkStart float,  -- Doi gio bat dau cua ca ra giay so voi AttDate de tinh In late, out early
  SiWorkEnd float,

  SiLeave1 float,
  SiLeave2 float,

  SiInLate float,
  SiOutEarly float,
  InLate  float,
  OutEarly float,
  -- đoạn này phục vụ cho việc xử lý trừ 60 phút thai sản chăm con
   AccGroupID int,
   TotalAccumulate float,
  MaternityMinus FLOAT,
  EmployeeTypeID INT,
  GoOut FLOAT,
  StatusID int,
  LATE_PERMIT float
 )

 UPDATE #tmpHasTA
 SET  SiAttStart = MiAttStart*60 + datepart(ss,AttStart),
   SiAttEnd =  MiAttEnd*60 + datepart(ss,AttEnd),
   SiWorkStart = MiWorkStart*60,  -- Gio vao cua ca la gio chan, ko can cong them phan le cua giay
   SiWorkEnd = MiWorkEnd*60   -- Gio vao cua ca la gio chan, ko can cong them phan le cua giay

 ------------------------------------Insert du lieu vao bang #ta_ptmpLateTmp----------------------------------
 SELECT distinct l.EmployeeID,l.IODate into #tblInLateOutEarly FROM tblInLateOutEarly l
 inner join #tblPendingTaProcessMain p on l.EmployeeID = p.EmployeeID and l.IODate = p.[Date]
 WHERE l.StatusID = 3 -- only cofirmed


 INSERT INTO #ta_ptmpLateTmp(EmployeeID,AttDate,Period ,ShiftID, AttStart, AttEnd, SiAttStart, SiAttEnd, SiWorkStart, SiWorkEnd,SiBreakStart,SiBreakEnd,LATE_PERMIT,MaternityMinus)
 SELECT distinct i.EmployeeID,AttDate,Period, ShiftID, AttStart, AttEnd, SiAttStart,
   case when @DO_NOT_CARE_EARLY= 1 then SiWorkEnd else SiAttEnd end, SiWorkStart, SiWorkEnd,MiBreakStart*60,MiBreakEnd*60,e.LATE_PERMIT,b.MinusMin
  FROM #tmpHasTA i
  inner join #tmpEmployee e on i.EmployeeID = e.EmployeeID
  left join #Maternity b on i.EmployeeID = b.EMployeeID and i.AttDate<= EndDate
  WHERE DayType = 0 -- Khong tinh di muon, ve som cho ngay nghi.
  and (SiAttStart > SiWorkStart or SiAttEnd < SiWorkEnd)
  and not exists(select 1 from #tblInLateOutEarly il where i.EmployeeID = il.EmployeeID and i.AttDate = il.IODate )
 and -- Loại bỏ những record không đi trễ về sớm
 ((SiAttStart >= SiWorkStart or SiAttEnd <= SiWorkEnd) and
 (SiAttStart >= SiWorkStart or SiAttEnd >= SiWorkStart) and
 (SiAttStart <= SiWorkEnd or SiAttEnd <= SiWorkEnd))
 and isnull(i.LeaveStatus,0) <> 3 --nghi ca ngay roi thi ko co di tre ve som gi het


 DROP TABLE #tblInLateOutEarly

 UPDATE #ta_ptmpLateTmp SET SiWorkStart = CASE WHEN SiWorkStart = SiBreakStart THEN SiBreakEnd ELSE SiWorkStart END
  ,SiWorkEnd = CASE WHEN SiWorkEnd = SiBreakEnd THEN SiBreakStart ELSE SiWorkEnd END

 UPDATE #ta_ptmpLateTmp SET SiLeave1 = HrsLeave1*60*60,SiLeave2 = HrsLeave2*60*60







 from #ta_ptmpLateTmp i inner join (
  select EmployeeID, LeaveDate, SUM(CASE WHEN lv.LeaveStatus in (1,4) THEN LvAmount ELSE 0 END) HrsLeave1,
   SUM(CASE WHEN lv.LeaveStatus in (1,4) THEN 0 ELSE LvAmount END) HrsLeave2
  from #tblLvHistoryP lv inner join tblLeavetype lt on lv.LeaveCode = lt.LeaveCode
  where lv.LeaveCode <> 'FWC' and (lt.LeaveCategory = 1 or lv.LeaveStatus <> 3)
group by EmployeeID, LeaveDate
 ) lv on i.EmployeeID = lv.EmployeeID and i.AttDate = lv.LeaveDate



 --lam dep du lieu truoc khi cong vo
 UPDATE #ta_ptmpLateTmp SET SiAttEnd = case when SiAttEnd   between SiBreakStart and SiBreakEnd then SiBreakEnd else SiAttEnd end --ve som va nghi buoi chieu
       ,SiAttStart = case when SiAttStart between SiBreakStart and SiBreakEnd then CASE WHEN SiLeave1 > 0 THEN SiBreakStart ELSE SiBreakEnd END else SiAttStart end --vo tre va nghi buoi sang

 --nghi trua
 UPDATE #ta_ptmpLateTmp SET SiAttStart =  CASE WHEN SiAttStart > SiBreakEnd and SiAttStart - SiLeave1 < SiBreakEnd THEN SiAttStart - (SiBreakEnd - SiBreakStart) ELSE SiAttStart END
  ,SiAttEnd =  CASE WHEN SiAttEnd < SiBreakStart and SiAttEnd + SiLeave2 > SiBreakStart THEN SiAttEnd + (SiBreakEnd - SiBreakStart) ELSE SiAttEnd END

 --LongKa: tam thoi chua xu ly duoc truong hop dang ky 2 loai nghi, sang 4h, chieu 2h nhung trong do 1h dau gio chieu va 1h truoc gio ve :(
 UPDATE #ta_ptmpLateTmp SET SiAttStart = SiAttStart - CASE WHEN SiAttStart - 1200 < SiWorkStart THEN 0 ELSE ISNULL(SiLeave1,0) END
  - CASE WHEN SiAttEnd + 1200 < SiWorkEnd THEN 0 ELSE ISNULL(SiLeave2,0) END
 , SiAttEnd = SiAttEnd + CASE WHEN SiAttStart - 1200 < SiWorkStart THEN ISNULL(SiLeave1,0) ELSE 0 END
  + CASE WHEN SiAttEnd + 1200 < SiWorkEnd THEN ISNULL(SiLeave2,0) ELSE 0 END
 from #ta_ptmpLateTmp i where not exists(select 1 from #ta_ptmpLateTmp o where i.EmployeeID = o.EmployeeID and i.AttDate = o.AttDate and o.Period > 0)

 --lam dep du lieu sau khi cong nghi, nghi trua ko bi tru di tre, ve som
 UPDATE #ta_ptmpLateTmp SET SiAttEnd = case when SiAttEnd   between SiBreakStart and SiBreakEnd then CASE WHEN SiLeave1 > 0 THEN SiBreakEnd ELSE SiBreakStart END else SiAttEnd end --ve som va nghi buoi chieu
           , SiAttStart = case when SiAttStart between SiBreakStart and SiBreakEnd then SiBreakEnd else SiAttStart end--vo tre va nghi buoi sang

 select *,cast(0 as float) as MissOut ,cast(0 as float) as MissIn
  into #tmpMultiPeriod from #ta_ptmpLateTmp i where exists(select 1 from #ta_ptmpLateTmp o where i.EmployeeID = o.EmployeeID and i.AttDate = o.AttDate and o.Period > 0)








 UPDATE #tmpMultiPeriod SET SiWorkEnd = case when  SiAttEnd <= SiBreakEnd then  SiBreakStart  else SiWorkEnd end
 ,SiWorkStart =  case when SiAttStart > SiBreakStart then  SiBreakEnd  else SiWorkStart end

 UPDATE #tmpMultiPeriod SET MissOut = FLOOR((SiBreakStart-SiAttEnd)/60.0)*60
 ,MissIn = FLOOR((SiAttStart - SiWorkStart)/60.0)*60

 DECLARE @CurPeriod int = 0, @MaxPeriod int
 SET @MaxPeriod = ISNULL((select MAX(Period) from #ta_ptmpLateTmp),0)

 while @CurPeriod <= @MaxPeriod
 begin
  UPDATE a SET MissOut = b.SiLeave1 from #tmpMultiPeriod a
    inner join #tmpMultiPeriod b on a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = @CurPeriod and b.Period = 0
    where b.SiLeave1 > 0 and a.MissOut >= 1200 and b.SiLeave1 < a.MissOut
    UPDATE #tmpMultiPeriod SET SiAttEnd = SiAttEnd+MissOut from #tmpMultiPeriod where Period = @CurPeriod and MissOut >= 1200 and SiLeave1 > 0
UPDATE b SET SiLeave1 = b.SiLeave1 - a.MissOut from #tmpMultiPeriod b inner join #tmpMultiPeriod a on a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = @CurPeriod and b.Period = 0
     where a.MissOut >= 1200 and b.SiLeave1 > 0
    UPDATE #tmpMultiPeriod SET MissOut = 0 from #tmpMultiPeriod where Period = @CurPeriod and MissOut >= 1200 and SiLeave1 > 0

    UPDATE a SET MissIn = b.SiLeave1 from #tmpMultiPeriod a
    inner join #tmpMultiPeriod b on a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = @CurPeriod and b.Period = 0
    where b.SiLeave1 > 0 and a.MissIn >= 1200 and b.SiLeave1 < a.MissIn
    UPDATE #tmpMultiPeriod SET SiAttStart = SiAttStart-MissIn from #tmpMultiPeriod where Period = @CurPeriod and MissIn >= 1200 and SiLeave1 > 0
    UPDATE b SET SiLeave1 = b.SiLeave1 - a.MissIn from #tmpMultiPeriod b inner join #tmpMultiPeriod a on a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = @CurPeriod and b.Period = 0
     where a.MissIn >= 1200 and b.SiLeave1 > 0
    UPDATE #tmpMultiPeriod SET MissIn = 0 from #tmpMultiPeriod where Period = @CurPeriod and MissIn >= 1200 and SiLeave1 > 0


    UPDATE a SET MissOut = b.SiLeave2 from #tmpMultiPeriod a
    inner join #tmpMultiPeriod b on a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = @CurPeriod and b.Period = 0
    where b.SiLeave2 > 0 and a.MissOut >= 1200 and b.SiLeave2 < a.MissOut

    UPDATE #tmpMultiPeriod SET SiAttEnd = SiAttEnd+MissOut from #tmpMultiPeriod where Period = @CurPeriod and MissOut >= 1200 and SiLeave2 > 0
    UPDATE b SET SiLeave2 = b.SiLeave2 - a.MissOut from #tmpMultiPeriod b inner join #tmpMultiPeriod a on a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = @CurPeriod and b.Period = 0
     where a.MissOut >= 1200 and b.SiLeave2 > 0
    UPDATE #tmpMultiPeriod SET MissOut = 0 from #tmpMultiPeriod where Period = @CurPeriod and MissOut >= 1200 and SiLeave2 > 0

    UPDATE a SET MissIn = b.SiLeave2 from #tmpMultiPeriod a
    inner join #tmpMultiPeriod b on a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = @CurPeriod and b.Period = 0
    where b.SiLeave2 > 0 and a.MissIn >= 1200 and b.SiLeave2 < a.MissIn
    UPDATE #tmpMultiPeriod SET SiAttStart = SiAttStart-MissIn from #tmpMultiPeriod where Period = @CurPeriod and MissIn >= 1200 and SiLeave2 > 0
    UPDATE b SET SiLeave2 = b.SiLeave2 - a.MissIn from #tmpMultiPeriod b inner join #tmpMultiPeriod a on a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = @CurPeriod and b.Period = 0
     where a.MissIn >= 1200 and b.SiLeave2 > 0
    UPDATE #tmpMultiPeriod SET MissIn = 0 from #tmpMultiPeriod where Period = @CurPeriod and MissIn >= 1200 and SiLeave2 > 0


    SET @CurPeriod = @CurPeriod + 1
 end
 UPDATE #ta_ptmpLateTmp SET SiAttStart = b.SiAttStart,SiAttEnd = b.SiAttEnd, SiWorkStart = b.SiWorkStart, SiWorkEnd = b.SiWorkEnd
  from #ta_ptmpLateTmp a inner join #tmpMultiPeriod b on a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = b.Period




 drop table #tmpMultiPeriod
-- Xoa nhung ban nghi ko can thiet phai tinh toan


 UPDATE #ta_ptmpLateTmp
   SET  SiInLate = case when SiAttStart <= SiWorkStart then 0 else SiAttStart - SiWorkStart end,
     SiOutEarly = case when SiAttEnd >= SiWorkEnd then 0 else SiWorkEnd - SiAttEnd end
     ,EmployeeTypeID = e.EmployeeTypeID
   FROM #ta_ptmpLateTmp i INNER JOIN #tmpEmployee e ON i.EmployeeID = e.EmployeeID

 DELETE FROM #ta_ptmpLateTmp WHERE SiInLate = 0 AND SiOutEarly = 0 -- Delete nhung ban ghi ko di muon, ve som

 --------------------------Doi giay thanh phut (thua tren 1s lam tron thanh 1 phut)-----------------------
 declare @LATE_EARLY_ROUND_UP bit = 1
 select @LATE_EARLY_ROUND_UP  = cast(value as bit) from tblparameter where code = 'LATE_EARLY_ROUND_UP'
 if(@LATE_EARLY_ROUND_UP is null)
  SET @LATE_EARLY_ROUND_UP = 1

 UPDATE #ta_ptmpLateTmp
 SET InLate = cast(SiInLate as int)/60 + case when cast(SiInLate as int)%60 > 0 and @LATE_EARLY_ROUND_UP = 1 then 1 else 0 end
 ,OutEarly = cast(SiOutEarly as int)/60 + case when cast(SiOutEarly as int)%60 > 0 and @LATE_EARLY_ROUND_UP = 1 then 1 else 0 end

 UPDATE #ta_ptmpLateTmp
 SET OutEarly = case when OutEarly <= LATE_PERMIT  then 0 else OutEarly end
 ,InLate = case when InLate <= LATE_PERMIT then 0 else InLate end


-- Xử lý thêm những nhân viên Sau Hộ Sản

 ------------------------Doi phut ve gio` theo ROUND_UNIT (lam tron len)-------------------------------------------
 declare @IO_UNIT int
 SET @IO_UNIT = (select cast (value as int) from tblParameter where code = 'IO_UNIT')
 if @IO_UNIT = 1
 begin
  UPDATE #ta_ptmpLateTmp
  SET InLate = ROUND((CAST(InLate as float)/@IO_LE_ROUND_UNIT + 0.4999999999),0)*(CAST(@IO_LE_ROUND_UNIT AS FLOAT)/60),
   OutEarly = ROUND((CAST(OutEarly as float)/@IO_LE_ROUND_UNIT + 0.4999999999),0)*(CAST(@IO_LE_ROUND_UNIT AS FLOAT)/60)
   , MaternityMinus = MaternityMinus /60.0

 end

 -- TỔNG LŨY TIẾN
 update i SET AccGroupID = tmp.STT
 from #ta_ptmpLateTmp i
 inner join(
 select EmployeeID,AttDate,Period, ROW_NUMBER() over (partition by employeeID,AttDate order by  EmployeeId, AttDate,isnull(Inlate,0) + isnull(OutEarly,0) desc) as STT
 from #ta_ptmpLateTmp
 ) tmp on i.EmployeeID = tmp.EmployeeID and i.AttDate = tmp.AttDate and i.Period = tmp.Period

 update i SET TotalAccumulate = tmp.TotalAccumulate
 ,MaternityMinus = case when MaternityMinus - ISNULL(tmp.TotalAccumulate,0) <0 then 0 else MaternityMinus - ISNULL(tmp.TotalAccumulate,0)  end
 from #ta_ptmpLateTmp i inner join (
 select i2.AccGroupID,i1.EmployeeID,i1.AttDate, sum(i1.InLate+ i1.OutEarly) TotalAccumulate
 from #ta_ptmpLateTmp i1
  inner join #ta_ptmpLateTmp i2 on i1.EmployeeID = i2.EmployeeID and i1.AttDate = i2.AttDate
 and i1.AccGroupID < i2.AccGroupID
 group by i2.AccGroupID,i1.EmployeeID,i1.AttDate
 ) tmp on i.EmployeeID = tmp.EmployeeID and i.AttDate = tmp.AttDate and i.AccGroupID = tmp.AccGroupID

 update #ta_ptmpLateTmp SET InLate = InLate - MaternityMinus
 where MaternityMinus is not null and (InLate >= 20 or OutEarly <= 30)

 update #ta_ptmpLateTmp SET MaternityMinus = case when InLate < 0 then  -1 * InLate  else 0 end
 ,InLate  = case when InLate < 0 then 0 else InLate end
 ,OutEarly = OutEarly - case when InLate < 0 then  -1 * InLate  else 0 end
 where MaternityMinus is not null and (InLate >= 20 or OutEarly <= 30)

 update #ta_ptmpLateTmp SET MaternityMinus = case when OutEarly <= 0 then  -1 * OutEarly else 0 end
 ,OutEarly = case when OutEarly < 0 then 0  else OutEarly end
  where  MaternityMinus is not null and (OutEarly >= 20 or InLate <= 30)

 DELETE FROM #ta_ptmpLateTmp WHERE InLate <= 0 AND OutEarly <= 0

 -- kiểm tra có mặt định trừ trễ sớm vào lương ko?
 declare @IsIO bit
 SET @IsIO = (select cast(value as bit) from tblParameter where code = 'IS_IO_DEDUCTION')
 SET @IsIO = isnull(@IsIO,1)
 -- những record đã duyệt rồi thì không cập nhật lại nữa

 -------------------------Insert vao bang tblInLateOutEarly---------------------------------------------------
 IF COL_LENGTH('tblInLateOutEarly','Period') is null ALTER TABLE tblInLateOutEarly ADD [Period] tinyint NULL
 -- Xoa du lieu truoc khi insert
 DELETE tblInLateOutEarly FROM tblInLateOutEarly l
 inner join #tblPendingTaProcessMain p on l.EmployeeID = p.EmployeeID and l.IODate = p.[Date]
 WHERE ISNULL(l.StatusID,1) <> 3

 --lam du cong roi thi khong bi tinh di tre, ve som nua
 delete l from #ta_ptmpLateTmp l
 where exists(select 1 from #tmpHasTA ta where l.EmployeeID = ta.EmployeeID and l.AttDate = ta.AttDate and ta.WorkingTime = 8)

 delete #ta_ptmpLateTmp where InLate = 0 and OutEarly = 0

 INSERT INTO tblInLateOutEarly(EmployeeID,Period,IODate,IOKind,IOStart,IOEnd,IOMinutes,IOMinutesDeduct,ApprovedDeduct,StatusID,Reason)
 select EmployeeID,Period,AttDate,1 as IOKind,dateadd(second,tmp.SiWorkStart,AttDate) as LateStart,AttStart as LateEnd,InLate,InLate,@IsIO as Approved_Deduct,1 as StatusID,N'' as Reason
 from #ta_ptmpLateTmp tmp  where isnull(InLate,0) >0
 union all
 select EmployeeID,Period,AttDate,2 as IOKind,AttEnd as EarlyStart,dateadd(second,tmp.SiWorkEnd,AttDate) as EarlyEnd,OutEarly,OutEarly,@IsIO as Approved_Deduct,1 as StatusID,N'' as Reason
 from #ta_ptmpLateTmp tmp where isnull(OutEarly,0) >0

 DROP TABLE #ta_ptmpLateTmp
END
-- end Late early


--begin OT


 begin
  DECLARE @OT_MIN_BEFORE  int,

    @OT_MIN_AFTER  int,
    @OT_MIN_HOLIDAY  int,
    @Value     T_Value
  BEGIN

  SET @OT_MIN_BEFORE = (select cast(value as float) from tblParameter where code = 'OT_MIN_BEFORE')
  SET @OT_MIN_BEFORE = isnull(@OT_MIN_BEFORE,30)

  SET @OT_MIN_AFTER = (select cast(value as float) from tblParameter where code = 'OT_MIN_AFTER')
  SET @OT_MIN_AFTER = isnull(@OT_MIN_AFTER,30)

  SET @OT_MIN_HOLIDAY = (select cast(value as float) from tblParameter where code = 'OT_MIN_HOLIDAY')
  SET @OT_MIN_HOLIDAY = isnull(@OT_MIN_HOLIDAY,30)

  SET @OT_ROUND_UNIT = (select cast(value as float) from tblParameter where code = 'OT_ROUND_UNIT')
  SET @OT_ROUND_UNIT = isnull(@OT_ROUND_UNIT,30)

  IF @OT_ROUND_UNIT <= 0 SET @OT_ROUND_UNIT = 1
  declare @OT_MIN_BREAKTEA float, @OT_BREAKTEA float
  SET @OT_BREAKTEA = (select cast(value as float) from tblParameter where code = 'OT_BREAKTEA')
  SET @OT_BREAKTEA = isnull(@OT_BREAKTEA,45)
  SET @OT_MIN_BREAKTEA = (select cast(value as float) from tblParameter where code = 'OT_MIN_BREAKTEA')
  SET @OT_MIN_BREAKTEA = isnull(@OT_MIN_BREAKTEA,3)

  CREATE TABLE #tmpOTTemp
  (
   EmployeeID  nvarchar(20),
   AttDate  datetime,
   Period  tinyint null,
   ShiftID  int,
   DayType  int,
   OTCategoryID int,

   AttStart datetime,
   AttEnd  datetime,

   MiOTStart int,
   MiOTEnd  INT ,
   MiOTStartR int,
   MiOTEndR INT ,
   MiWorkStart int,
   MiWorkEnd int,
   MiOTBeforeStart int,
   MiOTBeforeEnd int,
   MiOTAfterStart int,
   MiOTAfterEnd int,
   OutStart int,
   InStart  int
  )
  /*
  CREATE TABLE #OTNotOverwrite(EmployeeID varchar(20),OTDate datetime primary key(EmployeeID,OTDate))
  if @IsAuditAccount = 0
  begin
   insert into #OTNotOverwrite(EmployeeID,OTDate)
   select distinct ot.EmployeeID,ot.OTDate from tblOTList ot inner join #tblPendingTaProcessMain p on ot.EmployeeID = p.EmployeeID and ot.OTDate = p.[Date]
    where ot.StatusID = 3
  end
  else
  begin
   insert into #OTNotOverwrite(EmployeeID,OTDate)
   select distinct ot.EmployeeID,ot.OTDate from tblOTList_CT ot inner join #tblPendingTaProcessMain p on ot.EmployeeID = p.EmployeeID and ot.OTDate = p.[Date]
    where ot.StatusID = 3
  end
  */
 SELECT *, CAST(8 as int) STD_WD INTO #tmpHasTA_OT FROM #tmpHasTA ta where
 --not exists(select 1 from #OTNotOverwrite ot where ta.EmployeeID = ot.EmployeeID and ta.AttDate = ot.OTDate) and
 ta.AttStart is not null and ta.AttEnd is not null
 -- tuy chọn, đi làm ngày chủ nhật, tăng ca có tính theo ca làm việc không?
 declare @HolidayOTBaseOnShiftInfo bit = 0
 if not exists (select 1 from tblParameter where Code = 'HolidayOTBaseOnShiftInfo')
 insert into tblParameter(Code,Value,Type,Category,Description,Visible)
 values ('HolidayOTBaseOnShiftInfo','1','1','TIME ATTENDANCE',N'Đi làm ngày chủ nhật, tăng ca có tính theo ca làm việc không? 0: không theo ca, lấy giờ đầu trừ giờ cuối. 1: theo thiết lập của ca làm việc',1)

 if not exists (select 1 from tblParameter where Code = 'HolidayOTBaseOnShiftInfo' and Value = '0')
 set @HolidayOTBaseOnShiftInfo = 1
 -- 3 anh tài xế (tai xe) được tăng ca trước do đi đón sếp (AAF4617,AAF0076,AAF0121)
 update o set ShiftID = 67
  from #tmpHasTA_OT o
 where o.employeeID in ('AAF4617','AAF0076','AAF0121')
 and ShiftId in (select ShiftID from tblShiftSetting s where s.ShiftCode = 'HCM' )

 -- nghỉ nửa đầu hoặc nửa sau thì chỉ tính OT sau hoăc OT trước
 UPDATE #tmpHasTA_OT SET MiWorkStart = DATEPART(hh,OTBeforeEnd) * 60 + DATEPART(mi,OTBeforeEnd)
 FROM #tmpHasTA_OT ta
 INNER JOIN #ShiftInfo ts ON ta.ShiftID = ts.ShiftID AND ts.OTBeforeEnd IS NOT NULL AND ta.MiWorkStart < DATEPART(hh,OTBeforeEnd)* 60 + DATEPART(mi,OTBeforeEnd)
 where (ta.Holidaystatus = 0 )

 UPDATE #tmpHasTA_OT SET MiWorkEnd = DATEPART(hh,OTAfterStart) * 60 + DATEPART(mi,OTAfterStart)
  FROM #tmpHasTA_OT ta
  INNER JOIN #ShiftInfo ts ON ta.ShiftID = ts.ShiftID AND ts.OTAfterStart IS NOT NULL AND DATEPART(hh,ta.WorkStart) < DATEPART(hh,ta.WorkEnd) AND ta.MiWorkEnd < 1440
 where  (ta.Holidaystatus in (0))

 UPDATE #tmpHasTA_OT SET MiWorkEnd = 1440 + DATEPART(hh,OTAfterStart)* 60 + DATEPART(mi,OTAfterStart)
  FROM #tmpHasTA_OT ta
  INNER JOIN #ShiftInfo ts ON ta.ShiftID = ts.ShiftID AND ts.OTAfterStart IS NOT NULL AND ta.MiWorkEnd >1440+ DATEPART(hh,OTAfterStart)* 60 + DATEPART(mi,OTAfterStart) AND DATEPART(hh,ta.WorkStart) >DATEPART(hh,ta.WorkEnd) --  AND ta.MiWorkEnd >= DATEPART(hh,OTAfterStart)* 60 + DATEPART(mi,OTAfterStart)
 where  (ta.Holidaystatus in (0) )


 UPDATE  #tmpHasTA_OT SET MiAttStart = DATEPART(hh,OTBeforeStart)* 60 + DATEPART(mi,OTBeforeStart)
 FROM #tmpHasTA_OT ta
 INNER JOIN #ShiftInfo ts ON ta.ShiftID = ts.ShiftID AND ts.OTBeforeEnd IS NOT NULL AND ta.MiAttStart < DATEPART(hh,OTBeforeStart)* 60 + DATEPART(mi,OTBeforeStart)
 where  (ta.Holidaystatus = 0 or ( @HolidayOTBaseOnShiftInfo = 1 and ta.Holidaystatus <> 0))


 UPDATE #tmpHasTA_OT SET MiAttStart = MiWorkStart
 where MiWorkStart - MiAttStart < @OT_MIN_BEFORE AND MiWorkStart - MiAttStart > 0
 and  (Holidaystatus = 0 or ( @HolidayOTBaseOnShiftInfo = 1 and Holidaystatus <> 0))

 UPDATE #tmpHasTA_OT SET MiAttEnd = DATEPART(hh,OTAfterEnd)* 60 + DATEPART(mi,OTAfterEnd)
 FROM #tmpHasTA_OT ta
 INNER JOIN #ShiftInfo ts ON ta.ShiftID = ts.ShiftID AND ts.OTAfterEnd IS NOT NULL and isnull(ts.IsNightShift,0) = 0
 AND ta.MiAttEnd > (DATEPART(hh,OTAfterEnd)* 60 + DATEPART(mi,OTAfterEnd))
 AND ta.MiAttEnd <= 1440
 AND (DATEPART(hh,OTAfterEnd)* 60 + DATEPART(mi,OTAfterEnd)) >= (DATEPART(hh,OTAfterStart)* 60 + DATEPART(mi,OTAfterStart))
 where  (ta.Holidaystatus = 0 or ( @HolidayOTBaseOnShiftInfo = 1 and ta.Holidaystatus <> 0))



 UPDATE #tmpHasTA_OT SET MiAttEnd = 1440+DATEPART(hh,OTAfterEnd)* 60 + DATEPART(mi,OTAfterEnd)
 FROM #tmpHasTA_OT ta
 INNER JOIN #ShiftInfo ts ON ta.ShiftID = ts.ShiftID AND ts.OTAfterEnd IS NOT NULL AND ta.MiAttEnd > (1440 + DATEPART(hh,OTAfterEnd)* 60 + DATEPART(mi,OTAfterEnd))
 where  (ta.Holidaystatus = 0 or ( @HolidayOTBaseOnShiftInfo = 1 and ta.Holidaystatus <> 0))

 UPDATE #tmpHasTA_OT
 SET MiAttEnd = MiWorkEnd from #tmpHasTA_OT ot
 where MiAttEnd - MiWorkEnd > 0 and MiAttEnd - MiWorkEnd < @OT_MIN_AFTER
 and  (Holidaystatus = 0 or ( @HolidayOTBaseOnShiftInfo = 1 and Holidaystatus <> 0))
 and not exists(select 1 from #Maternity m where ot.EmployeeID = m.EmployeeID and ot.AttDate between BornDate and EndDate) --loai bo nhung nguoi huong che do truoc sau sinh


 -- xu ly truong hop ngay chu nhat, le, di lam nua buoi
 update o set MiAttStart = MiBreakEnd
 from #tmpHasTA_OT o
 where @HolidayOTBaseOnShiftInfo = 1 and o.Holidaystatus > 0 and MiAttStart between MiBreakStart and MiBreakEnd
 update o set MiAttEnd = MiBreakStart
 from #tmpHasTA_OT o
 where @HolidayOTBaseOnShiftInfo = 1 and o.Holidaystatus > 0 and MiAttEnd between MiBreakStart and MiBreakEnd


  --select miWorkStart - miAttStart,MiAttEnd - MiAttStart ,* from #tmpHasTA_OT ot
 -- loại bỏ những record không có OT
 delete #tmpHasTA_OT from #tmpHasTA_OT ot where DayType = 0
  and ((miWorkStart - miAttStart < @OT_MIN_BEFORE
  and MiAttEnd - MiWorkEnd < @OT_MIN_AFTER) or MiAttEnd - MiAttStart < @OT_MIN_AFTER)
     and not exists(select 1 from #Maternity m where ot.EmployeeID = m.EmployeeID and ot.AttDate between BornDate and EndDate) --loai bo nhung nguoi huong che do truoc sau sinh

 SELECT EmployeeID into #tblEmployeeWithoutOT
 From #tblEmployeeList
  where (PositionID in (select PositionID from tblPosition where OTCalculated = 0)
  or DepartmentID in (select DepartmentID from tblDepartment where OTCalculated = 0)
  )
  and EmployeeID in (select EmployeeID from #tmpEmployee)
if(OBJECT_ID('TA_ProcessMain_Begin_InsertOTTemp' )is null)
begin
exec('CREATE PROCEDURE TA_ProcessMain_Begin_InsertOTTemp
(
  @FromDate datetime
 ,@ToDate datetime
 ,@LoginID int
 ,@IsAuditAccount bit
 ,@StopUpdate bit output
)
as
begin
 SET NOCOUNT ON;
end')
end
SET @StopUpdate = 0
EXEC TA_ProcessMain_Begin_InsertOTTemp @FromDate=@FromDate, @ToDate=@ToDate, @LoginID=@LoginID, @IsAuditAccount=@IsAuditAccount, @StopUpdate=@StopUpdate output

 --------------------------- Insert cac ban ghi de tinh OT before(OTCategoryID = 1 )---------------------------


  INSERT INTO #tmpOTTemp(EmployeeID,Period, AttDate, ShiftID, DayType, OTCategoryID, AttStart, AttEnd, MiOTStart, MiOTEnd, MiOTStartR, MiOTEndR,MiWorkEnd,MiWorkStart)
   SELECT EmployeeID,Period, AttDate, ShiftID, DayType, 1, AttStart, AttEnd, MiAttStart, case when MiWorkStart>MiAttend then MiAttend else MiWorkStart end, MiAttStart, case when MiWorkStart>MiAttend then MiAttend else MiWorkStart end,MiWorkEnd,MiWorkStart
   FROM #tmpHasTA_OT
   WHERE case when MiWorkStart>MiAttend then MiAttend else MiWorkStart end - MiAttStart >= @OT_MIN_BEFORE
     AND isnull(MiBreakStart,MiWorkStart) - MiAttStart >= 0 -- Neu  nghi nua buoi sang, chieu di lam som thi` phai lam truoc BreakStart moi duoc tinh OT truoc
     --AND DayType = 0           -- Neu lam ca ngay hoac nua buoi sang thi` ko bi anh huong gi boi cau lenh nay vi khi do BreakStart luon > gio vao lam viec
     AND EmployeeID not in (select EmployeeID from #tblEmployeeWithoutOT)



 --------------------------- Insert cac ban ghi de tinh OT after(OTCategoryID = 2 )---------------------------
  INSERT INTO #tmpOTTemp(EmployeeID,Period, AttDate, ShiftID, DayType, OTCategoryID, AttStart, AttEnd, MiOTStart, MiOTEnd, MiOTStartR, MiOTEndR,MiWorkEnd,MiWorkStart)
   SELECT EmployeeID,Period, AttDate, ShiftID, DayType, 2, AttStart, AttEnd, case when MiAttstart > MiWorkEnd then MiAttStart else MiWorkEnd end, MiAttEnd, case when MiAttstart > MiWorkEnd then MiAttStart else MiWorkEnd end, MiAttEnd,MiWorkEnd,MiWorkStart
   FROM #tmpHasTA_OT
   WHERE MiAttEnd - case when MiAttstart > MiWorkEnd then MiAttStart else MiWorkEnd end >= (@OT_MIN_AFTER - 10)
     --AND DayType = 0
     AND EmployeeID not in (select EmployeeID from #tblEmployeeWithoutOT)
	
 --------------------------- Insert cac ban ghi de tinh OT IN HOLIDAY(OTCategoryID = 3 )---------------------------
  INSERT INTO #tmpOTTemp(EmployeeID,Period, AttDate, ShiftID, DayType, OTCategoryID, AttStart, AttEnd, MiOTStart, MiOTEnd, MiOTStartR, MiOTEndR,MiWorkEnd,MiWorkStart)
   SELECT EmployeeID,Period, AttDate, ShiftID, DayType, 3, AttStart, AttEnd, case when MiWorkStart>MiAttStart then MiWorkStart else MiAttStart end MiAttStart, case when MiWorkEnd > MiAttEnd then MiAttEnd else MiWorkEnd end MiAttEnd,MiAttStart, MiAttEnd,MiWorkEnd,MiWorkStart
   FROM #tmpHasTA_OT
   WHERE MiAttEnd - MiAttStart >= @OT_MIN_AFTER
     AND DayType != 0
     AND EmployeeID not in (select EmployeeID from #tblEmployeeWithoutOT)

	--chu nhat/ le, tang ca sau thi f lay theo gio bat dau tang ca
	update ot set MiOTStart = ss.MIOTAfterStart from #tmpOTTemp ot
	inner join #ShiftInfo ss on ot.ShiftID = ss.ShiftID and ot.MiOTStart < ss.MIOTAfterStart
	where ot.DayType in (1,2) and ot.OTCategoryID = 2 and ot.MiOTStart = ot.MiWorkEnd
	and  exists(select 1 from tblShiftSetting ss where ot.ShiftID = ss.ShiftID and ss.ShiftCode in ('CT SG-HN','CTMT+PQ'))
	

  UPDATE #ShiftInfo SET MiDeductBearkTime = datepart(hh,BreakEnd)*60 + DATEPART(Mi,BreakEnd) - (datepart(hh,BreakStart)*60 + DATEPART(Mi,BreakStart))
 -- Xu ly thong tin cho cac co nang sau ho san
 declare @MATERNITY_OT int
 SET @MATERNITY_OT = (select cast(value as int) from tblParameter where code = 'MATERNITY_OT')
 SET @MATERNITY_OT = isnull(@MATERNITY_OT,1)
 if @MATERNITY_OT = 1
 begin
  delete #tmpOTTemp from #tmpOTTemp a inner join #Maternity b on a.EmployeeID = b.EMployeeID and datediff(day,a.AttDate, EndDate) >= 0  and  DATEDIFF(day, a.AttDate, BornDate)<=0
  select a.*, a.MiAttStart - a.MiWorkStart InLate,a.MiWorkEnd - a.MiAttEnd OutEarly , b.MinusMin MaternityMinus, b.MinusMin
  into #tmpHasTAMaternity from #tmpHasTA_OT a inner join #Maternity b on a.EmployeeID = b.EMployeeID
   and a.AttDate between BornDate and EndDate and (a.LeaveStatus <> 3 or a.DayType <> 0)
   -- chỉnh lại thời gian bắt đầu tăng ca cho nhân viên thai sản, MiWorkEnd
    UPDATE #tmpHasTAMaternity SET MiWorkEnd = DATEPART(hh,ts.WorkEnd) * 60 + DATEPART(mi,ts.WorkEnd)
  FROM #tmpHasTAMaternity ta
  INNER JOIN #ShiftInfo ts ON ta.ShiftID = ts.ShiftID AND ts.OTAfterStart IS NOT NULL AND DATEPART(hh,ta.WorkStart) < DATEPART(hh,ta.WorkEnd) AND ta.MiWorkEnd < 1440
 where  (ta.Holidaystatus = 0 )

  UPDATE #tmpHasTAMaternity SET InLate = InLate - LvAmount*60 where LvAmount > 0 and LeaveStatus = 1
  UPDATE #tmpHasTAMaternity SET OutEarly = OutEarly - LvAmount*60 where LvAmount > 0 and LeaveStatus = 2

  DECLARE @MinusApproveLateEarlyBeign int = -10,@MinusApproveLateEarlyEnd int = 10
  delete #tmpHasTAMaternity where InLate + OutEarly - (MiBreakEnd - MiBreakStart) >= MaternityMinus and DayType = 0

  UPDATE #tmpHasTAMaternity SET InLate = 0 where InLate < @MinusApproveLateEarlyEnd
  UPDATE #tmpHasTAMaternity SET OutEarly = 0 where OutEarly < @MinusApproveLateEarlyEnd
  UPDATE #tmpHasTAMaternity SET InLate = MinusMin where (InLate - MinusMin) between @MinusApproveLateEarlyBeign and @MinusApproveLateEarlyEnd

  update #tmpHasTAMaternity set InLate = InLate - MaternityMinus where MaternityMinus > 0 AND DayType = 0
  update #tmpHasTAMaternity set MaternityMinus = -1 * InLate where InLate < 0 and MaternityMinus > 0 AND DayType = 0
  update #tmpHasTAMaternity set MaternityMinus = 0 where InLate >= 0 and MaternityMinus is not null AND DayType = 0
  update #tmpHasTAMaternity set InLate = 0 where InLate < 0 and MaternityMinus is not null AND DayType = 0

  update #tmpHasTAMaternity set OutEarly = OutEarly - MaternityMinus where MaternityMinus > 0 AND DayType = 0
  update #tmpHasTAMaternity set MaternityMinus = -1 * OutEarly where OutEarly <= 0 and MaternityMinus > 0 AND DayType = 0
  update #tmpHasTAMaternity set MaternityMinus = 0 where OutEarly >= 0 and MaternityMinus > 0 AND DayType = 0
  update #tmpHasTAMaternity set OutEarly = 0 where OutEarly < 0 and MaternityMinus > 0 AND DayType = 0

  update #tmpHasTAMaternity set MaternityMinus = 0 where MaternityMinus < 30
  update #tmpHasTAMaternity set MaternityMinus = MinusMin where MaternityMinus >  MinusMin





  update #tmpHasTAMaternity set MiWorkStart = CASE WHEN MiAttStart > MiWorkStart THEN MiWorkStart + MaternityMinus ELSE MiWorkStart END
  ,MiWorkEnd = CASE WHEN MiAttStart <= MiWorkStart THEN MiWorkEnd - MinusMin ELSE MiWorkEnd - MaternityMinus END
  from #tmpHasTAMaternity m


  INSERT INTO #tmpOTTemp(EmployeeID,Period, AttDate, ShiftID, DayType, OTCategoryID, AttStart, AttEnd, MiOTStart, MiOTEnd, MiOTStartR, MiOTEndR)
   SELECT EmployeeID,Period, AttDate, ShiftID, DayType, 1, AttStart, AttEnd, MiAttStart, MiWorkStart,  MiAttStart, MiWorkStart
   FROM #tmpHasTAMaternity
   WHERE MiWorkStart - MiAttStart >= @OT_MIN_BEFORE
     AND isnull(MiBreakStart,MiWorkStart) - MiAttStart >= 0 -- Neu  nghi nua buoi sang, chieu di lam som thi` phai lam truoc BreakStart moi duoc tinh OT truoc
     --AND DayType = 0           -- Neu lam ca ngay hoac nua buoi sang thi` ko bi anh huong gi boi cau lenh nay vi khi do BreakStart luon > gio vao lam viec
     AND EmployeeID not in (select EmployeeID from #tblEmployeeWithoutOT)

 --------------------------- Insert cac ban ghi de tinh OT after(OTCategoryID = 2 )---------------------------
  INSERT INTO #tmpOTTemp(EmployeeID,Period, AttDate, ShiftID, DayType, OTCategoryID, AttStart, AttEnd, MiOTStart, MiOTEnd, MiOTStartR, MiOTEndR)
   SELECT EmployeeID,Period, AttDate, ShiftID, DayType, 2, AttStart, AttEnd, MiWorkEnd, MiAttEnd, MiWorkEnd, MiAttEnd
   FROM #tmpHasTAMaternity
   WHERE MiAttEnd - MiWorkEnd >= @OT_MIN_AFTER
     --AND DayType = 0
     AND EmployeeID not in (select EmployeeID from #tblEmployeeWithoutOT)

 --------------------------- Insert cac ban ghi de tinh OT IN HOLIDAY(OTCategoryID = 3 )---------------------------
  INSERT INTO #tmpOTTemp(EmployeeID,Period, AttDate, ShiftID, DayType, OTCategoryID, AttStart, AttEnd, MiOTStart, MiOTEnd, MiOTStartR, MiOTEndR)
   SELECT EmployeeID,Period, AttDate, ShiftID, DayType, 3, AttStart, AttEnd, MiAttStart, MiAttEnd, MiAttStart, MiAttEnd
   FROM #tmpHasTAMaternity
   WHERE MiAttEnd - MiAttStart >= @OT_MIN_HOLIDAY AND DayType != 0
     AND EmployeeID not in (select EmployeeID from #tblEmployeeWithoutOT)

  -- Ket Thuc Xu ly thong tin cho cac co nang sau ho san

 end


if(OBJECT_ID('TA_ProcessMain_Finish_InsertOTTemp' )is null)
begin
exec('CREATE PROCEDURE TA_ProcessMain_Finish_InsertOTTemp
(
  @FromDate datetime
 ,@ToDate datetime
 ,@LoginID int
 ,@IsAuditAccount bit
 ,@StopUpdate bit output
)
as
begin
 SET NOCOUNT ON;
end')
end
SET @StopUpdate = 0
EXEC TA_ProcessMain_Finish_InsertOTTemp @FromDate=@FromDate, @ToDate=@ToDate, @LoginID=@LoginID, @IsAuditAccount=@IsAuditAccount, @StopUpdate=@StopUpdate OUTPUT

UPDATE #ShiftInfo SET WorkEnd = DATEADD(DAY,1,WorkEnd) WHERE WorkStart > WorkEnd
UPDATE #ShiftInfo SET BreakStart = DATEADD(DAY,1,BreakStart) WHERE WorkStart > BreakStart
UPDATE #ShiftInfo SET BreakEnd = DATEADD(DAY,1,BreakEnd) WHERE BreakStart > BreakEnd
UPDATE #ShiftInfo SET OTAfterStart = DATEADD(DAY,1,OTAfterStart) WHERE WorkEnd > OTAfterStart
UPDATE #ShiftInfo SET OTAfterEnd = DATEADD(DAY,1,OTAfterEnd) WHERE OTAfterStart > OTAfterEnd

--SELECT 999, DATEDIFF(mi,t.AttDate, DATEADD(DAY,DATEDIFF(DAY,s.WorkStart,t.AttDate),s.OTAfterStart)),  DATEDIFF(mi,t.AttDate,DATEADD(DAY,DATEDIFF(DAY,s.WorkStart,t.AttDate),s.OTAfterEnd))
UPDATE t SET t.MiOTAfterStart = DATEDIFF(mi,t.AttDate, DATEADD(DAY,DATEDIFF(DAY,s.WorkStart,t.AttDate),s.OTAfterStart))
,t.MiOTAfterEnd = DATEDIFF(mi,t.AttDate,DATEADD(DAY,DATEDIFF(DAY,s.WorkStart,t.AttDate),s.OTAfterEnd))
,t.MiOTBeforeStart = DATEDIFF(mi,t.AttDate,DATEADD(DAY,DATEDIFF(DAY,s.WorkStart,t.AttDate),s.OTBeforeStart))



,t.MiOTBeforeEnd = DATEDIFF(mi,t.AttDate,DATEADD(DAY,DATEDIFF(DAY,s.WorkStart,t.AttDate),s.OTBeforeEnd))
FROM #tmpOTTemp t INNER JOIN #ShiftInfo s ON t.ShiftID = s.ShiftID

  ----------------------------------------Kiem tra du lieu overwrite hay ko-------------------------------------------
  ---------------------------Them cac point, cac KindOT de tinh OT, dua vao cac DayType-------------------------------
   CREATE TABLE #tmpOT
      (
       EmployeeID  nvarchar(20),
       AttDate  datetime,
       Period  tinyint,
       ShiftID  int,
       DayType  int,
       OTCategoryID int,

       AttStart datetime,
       AttEnd  datetime,
       MiBreakStart INT,
       MiBreakEnd INT,
       DeductBreakTime INT,
       DeductBreakTimeAfter INT,
    MIOTAfterStart int,

       MiOTStart int,
       MiOTEnd  int,
       MiOTStartR int,
       MiOTEndR  int,

       MiOTStartTmp int,
       MiOTEndTmp int,

       Point1  int,

    Point2  int,
       Point3  int,
       Point4  int,
       Point5  int,
       Point6  int,
       AdjustTime int,
       V12   float, -- gia tri OT tinh duoc trong khoang point1 den point2
       V34   float, -- gia tri OT tinh duoc trong khoang point3 den point4
       V56   float,
       OTValue  float,
       OTKind  int,

       OTFrom12 datetime, -- Thoi gian bat dau OT trong khoang tu point1 den point2
       OTTo12  datetime, -- Thoi gian ket thuc OT trong khoang tu point1 den point2
       OTFrom34 datetime,
       OTTo34  datetime,
       OTFrom56 datetime,
       OTTo56  datetime

       ,MealDeductHours float -- bi tru tien nghi an trua
       ,V12Real float
       ,Approved bit default(0)
      )
	

   if @HolidayOTBaseOnShiftInfo = 1
   begin
   update #tmpOTTemp set MiOTEnd = MiWorkEnd where DayType > 0 and MiOTEnd - MiWorkEnd between 1 and 29
   update t set MiOTStart = MiWorkStart from #tmpOTTemp t  where DayType > 0 and MiWorkStart - MiOTStart between 1 and 29
   and not exists (select 1 from #tmpEmployee te where t.EmployeeID = te.EmployeeID and te.GroupID in (464))
   -- AAF pha mau dc tinh tang ca truoc ngay CN
   end
   INSERT INTO #tmpOT(EmployeeID, AttDate,Period, ShiftID, DayType, OTCategoryID,
        AttStart, AttEnd, MiOTStart, MiOTEnd, MiOTStartR, MiOTEndR,
        Point1, Point2, Point3,Point4,Point5,Point6, OTKind--,DeductBreakTime -- AAF bỏ đoạn này
        )
    SELECT EmployeeID, AttDate,Period, ShiftID, t.DayType, OTCategoryID,
        AttStart, AttEnd, MiOTStart, MiOTEnd, MiOTStartR, MiOTEndR,
        Point1, Point2, Point3,Point4,Point5,Point6, OTKind--,CASE WHEN t.DayType > 0 AND t.MiOTAfterStart > t.MiWorkEnd AND t.MiOTEnd > t.MiOTAfterStart THEN t.MiOTAfterStart - t.MiWorkEnd WHEN t.DayType > 0 AND t.MiOTEnd > t.MiWorkEnd THEN t.MiOTEnd - t.MiWorkEnd ELSE 0 end
    FROM #tmpOTTemp t
	INNER JOIN tblOvertimeRange r ON r.DayType = t.DayType
 where t.ShiftID not in (select ShiftID from tblShiftSetting ss where ss.ShiftCode in ('C1','C2','C3')) -- AAF custome cho Lo say



 select OTKind,DayType,Point1,Point2,Point3,Point4,Point5,Point6
 into #tblOvertimeRange
 from tblOvertimeRange

 update #tblOvertimeRange set Point2 = 1320 where Point2 = 1240



 -- AAF custome cho Lo say
 INSERT INTO #tmpOT(EmployeeID, AttDate,Period, ShiftID, DayType, OTCategoryID,
        AttStart, AttEnd, MiOTStart, MiOTEnd, MiOTStartR, MiOTEndR,
        Point1, Point2, Point3,Point4,Point5,Point6, OTKind--,DeductBreakTime
        )
    SELECT EmployeeID, AttDate,Period, ShiftID, t.DayType, OTCategoryID,
        AttStart, AttEnd, MiOTStart, MiOTEnd, MiOTStartR, MiOTEndR,
        Point1, Point2, Point3,Point4,Point5,Point6, OTKind--,CASE WHEN t.DayType > 0 AND t.MiOTAfterStart > t.MiWorkEnd AND t.MiOTEnd > t.MiOTAfterStart THEN t.MiOTAfterStart - t.MiWorkEnd WHEN t.DayType > 0 AND t.MiOTEnd > t.MiWorkEnd THEN t.MiOTEnd - t.MiWorkEnd ELSE 0 end

    FROM #tmpOTTemp t INNER JOIN #tblOvertimeRange r ON r.DayType = t.DayType
 where t.ShiftID in (select ShiftID from tblShiftSetting ss where ss.ShiftCode in ('C1','C2','C3'))


 -- xe nang tach OT truoc ngay chu nhat
 update o set Point1 = 440
 from #tmpOT o
  where o.DayType > 0 and o.OTKind = 23 and exists (select 1 from #tmpEmployee te where o.EmployeeID = te.EmployeeID and te.GroupID in (10))

 INSERT INTO #tmpOT(EmployeeID, AttDate,Period, ShiftID, DayType, OTCategoryID,
        AttStart, AttEnd, MiOTStart, MiOTEnd, MiOTStartR, MiOTEndR,
        Point1, Point2, OTKind,DeductBreakTime
        )
 select o.EmployeeID, o.AttDate,o.Period,o.ShiftID,o.DayType,1,o.AttStart,o.AttEnd,o.MiOTStart, MiOTEnd, MiOTStartR, MiOTEndR
 ,360,440,23,0
 from #tmpOTTemp o
  where o.DayType > 0 and exists (select 1 from #tmpEmployee te where o.EmployeeID = te.EmployeeID and te.GroupID in (10))

  update #tmpOT SET MiOTStartR = MiOTStart where MiOTStartR is null
  update #tmpOT SET MiOTEndR = MiOTEnd where MiOTEndR is null
  -- 3 bác tài xế tăng ca tính 150% hoặc 200%
    delete o from #tmpOT o where o.employeeID in ('AAF4617','AAF0076','AAF0121') and OTKind not in (11) and o.OTCategoryID = 1
    update o set Point1 = 0 from #tmpOT o where o.employeeID in ('AAF4617','AAF0076','AAF0121') and OTKind in (11) and o.OTCategoryID = 1
	
  drop table #tblOvertimeRange
if(OBJECT_ID('TA_ProcessMain_Finish_SetPointOT' )is null)
begin
exec('CREATE PROCEDURE TA_ProcessMain_Finish_SetPointOT
(
  @FromDate datetime
 ,@ToDate datetime
 ,@LoginID int
 ,@IsAuditAccount bit
 ,@StopUpdate bit output
)
as
begin
 SET NOCOUNT ON;
end')
end
SET @StopUpdate = 0
EXEC TA_ProcessMain_Finish_SetPointOT @FromDate=@FromDate, @ToDate=@ToDate, @LoginID=@LoginID, @IsAuditAccount=@IsAuditAccount, @StopUpdate=@StopUpdate output

  DROP TABLE #tmpOTTemp
 -----------------------------Dieu chinh gia tri cua cac Point theo cac shift theo gia tri AdjustTime trong bang tblShiftSetting
  UPDATE #tmpOT
  SET AdjustTime = ISNULL(tblShiftSetting.AdjustTime,0)
  FROM tblShiftSetting
  WHERE tblShiftSetting.ShiftID = #tmpOT.ShiftID

  UPDATE #tmpOT
  SET AdjustTime = 0
  WHERE  AdjustTime IS NULL

  UPDATE #tmpOT
  SET Point1 = Point1 + AdjustTime,
   Point2 = Point2 + AdjustTime,
   Point3 = Point3 + AdjustTime,
   Point4 = Point4 + AdjustTime,
   Point5 = Point5 + AdjustTime,
   Point6 = Point6 + AdjustTime


   --tinh luong t.c doan sua vao chu nhat
   --update #tmpOT set  DeductBreakTime = 0 where daytype = 1

  UPDATE #tmpOT SET DeductBreakTime = ISNULL(DeductBreakTime,0)+ s.MiDeductBearkTime,
   MiBreakStart = datepart(hh,s.BreakStart)*60 + DATEPART(mi,s.BreakStart) + case when DATEPART(hh,s.BreakStart) < DATEPART(hh,s.WorkStart) then 1440 else 0 end,
   MiBreakEnd = datepart(hh,s.BreakEnd)*60 + DATEPART(mi,s.BreakEnd) + case when DATEPART(hh,s.BreakEnd) < DATEPART(hh,s.WorkStart) then 1440 else 0 end
   FROM #tmpOT t, #ShiftInfo s
   WHERE t.ShiftID = s.ShiftID
   -- chinh lai BreakStart, BreakEnd cho ca đêm

  UPDATE #tmpOT SET DeductBreakTime = 0 WHERE MiOTEnd <= MiBreakStart OR MiOTStart >= MiBreakEnd


  UPDATE #tmpOT SET DeductBreakTime = ISNULL(DeductBreakTime,0)+ MiOTEnd - MiBreakStart WHERE MiOTEnd < MiBreakEnd AND MiOTEnd > MiBreakStart


  UPDATE #tmpOT SET DeductBreakTime = ISNULL(DeductBreakTime,0)+ MiBreakEnd  - MiOTStart WHERE MiOTStart < MiBreakEnd AND MiOTStart > MiBreakStart

 -- ngay nghi tru gio tang ca giao lao khi het ca

 update o
 set DeductBreakTimeAfter = s.MIOTAfterStart - s.MIWorkEnd
 , MIOTAfterStart = s.MIOTAfterStart
 from #tmpOT o inner join #ShiftInfo s on o.ShiftID = s.ShiftID and o.DayType > 0
  where o.MiOTEnd >  s.MIOTAfterStart and s.MIOTAfterStart > s.MIWorkEnd

--chi lai point cua cac ca cong trinh
update #tmpOT set Point2 = 1290 from  #tmpOT ot
where exists(select 1 from tblShiftSetting ss where ot.ShiftID = ss.ShiftID and ss.ShiftCode in ('CT SG-HN','CTMT+PQ')) and ot.OTKind = 11

update #tmpOT set Point1 = 1290, Point2 = 1320 from #tmpOT ot
where exists(select 1 from tblShiftSetting ss where ot.ShiftID = ss.ShiftID and ss.ShiftCode in ('CT SG-HN','CTMT+PQ')) and ot.OTKind = 33

  update #tmpOT set Point2 = 1320 from #tmpOT ot
where exists(select 1 from tblShiftSetting ss where ot.ShiftID = ss.ShiftID and ss.ShiftCode in ('CT SG-HN','CTMT+PQ')) and ot.OTKind = 23 and DayType = 1 and OTCategoryID = 2

-------------------------------Tinh OT-------------------------------------------------------
 -------1:OT trong doan tu Point5 den Point6--------------------------
  UPDATE #tmpOT
  SET MiOTStartTmp = MiOTStart
  WHERE MiOTStart >= Point5

  UPDATE #tmpOT
  SET MiOTStartTmp = Point5
  WHERE MiOTStart < Point5

  UPDATE #tmpOT
  SET MiOTEndTmp = Point6
  WHERE MiOTEnd >= Point6

  UPDATE #tmpOT
  SET MiOTEndTmp = MiOTEnd
  WHERE MiOTEnd < Point6

  UPDATE #tmpOT
  SET V56 = MiOTEndTmp - MiOTStartTmp
  if(exists(select 1 from tblOTDeductedTime))
UPDATE #tmpOT -- Kiem tra OT co thuoc thoi gian bi tru ko
  SET V56 = V56 - (SELECT isnull(SUM(DeductedValue),0)
       FROM tblOTDeductedTime
       WHERE tblOTDeductedTime.ShiftID = #tmpOT.ShiftID
 AND MiOTStartTmp <= MiDeductedStart
        AND MiOTEndTmp >= MiDeductedEnd)

  update #tmpOT SET V56 = V56 - DeductBreakTime where V56 >= DeductBreakTime and MiBreakStart > MiOTStartTmp and MiBreakEnd < MiOTEndTmp
  update #tmpOT SET V56 = V56 - DeductBreakTimeAfter where V56 >= DeductBreakTimeAfter and MIOTAfterStart < MiOTEndTmp and MIOTAfterStart > Point6


  UPDATE #tmpOT
  --SET V56 = (CAST(V56  +@OT_ROUND_UNIT AS INT)/@OT_ROUND_UNIT)*(CAST(@OT_ROUND_UNIT AS FLOAT)/60)
  SET V56 = (CAST(V56 AS INT)/@OT_ROUND_UNIT)*(CAST(@OT_ROUND_UNIT AS FLOAT)/60) -- lam tron xuong
  UPDATE #tmpOT
  SET V56 = 0
  WHERE isnull(V56,0) <= 0
  -- Tinh OTFrom56, OTTo56
  UPDATE #tmpOT
  SET OTFrom56 = dateadd(hh,cast(MiOTStartTmp as int)/60,AttDate),
   OTTo56 = dateadd(hh,cast(MiOTEndTmp as int)/60,AttDate)
  WHERE V56 > 0

  UPDATE #tmpOT
  SET OTFrom56 = dateadd(mi,cast(MiOTStartTmp as int)%60,OTFrom56),
   OTTo56 = dateadd(mi,cast(MiOTEndTmp as int)%60,OTTo56)
  WHERE V56 > 0


 -------2:OT trong doan tu Point3 den Point4--------------------------

  UPDATE #tmpOT
  SET MiOTStartTmp = MiOTStart
  WHERE MiOTStart >= Point3

  UPDATE #tmpOT
  SET MiOTStartTmp = Point3
  WHERE MiOTStart < Point3

  UPDATE #tmpOT
  SET MiOTEndTmp = Point4
  WHERE MiOTEnd >= Point4

  UPDATE #tmpOT
  SET MiOTEndTmp = MiOTEnd
  WHERE MiOTEnd < Point4

  UPDATE #tmpOT
  SET V34 = MiOTEndTmp - MiOTStartTmp


  if(exists(select 1 from tblOTDeductedTime))
  UPDATE #tmpOT -- Kiem tra OT co thuoc thoi gian bi tru ko
  SET V34 = V34 - (SELECT isnull(SUM(DeductedValue),0)
       FROM tblOTDeductedTime
       WHERE tblOTDeductedTime.ShiftID = #tmpOT.ShiftID
        AND MiOTStartTmp <= MiDeductedStart
        AND MiOTEndTmp >= MiDeductedEnd)
  update #tmpOT SET V34 = V34 - DeductBreakTime where V34 >= DeductBreakTime and MiBreakStart > MiOTStartTmp and MiBreakEnd < MiOTEndTmp
  update #tmpOT SET V34 = V34 - DeductBreakTimeAfter where V34 >= DeductBreakTimeAfter and MIOTAfterStart < MiOTEndTmp and MIOTAfterStart > Point4

  UPDATE #tmpOT
  --SET V34 = (CAST(V34  +@OT_ROUND_UNIT AS INT)/@OT_ROUND_UNIT)*(CAST(@OT_ROUND_UNIT AS FLOAT)/60)
  SET V34 = (CAST(V34 AS INT)/@OT_ROUND_UNIT)*(CAST(@OT_ROUND_UNIT AS FLOAT)/60) -- lam tron xuong
  UPDATE #tmpOT
  SET V34 = 0
  WHERE isnull(V34,0) <= 0

  -- Tinh OTFrom, OTTo
  UPDATE #tmpOT
  SET OTFrom34 = dateadd(hh,cast(MiOTStartTmp as int)/60,AttDate),
   OTTo34 = dateadd(hh,cast(MiOTEndTmp as int)/60,AttDate)
  WHERE V34 > 0

  UPDATE #tmpOT
  SET OTFrom34 = dateadd(mi,cast(MiOTStartTmp as int)%60,OTFrom34),
   OTTo34 = dateadd(mi,cast(MiOTEndTmp as int)%60,OTTo34)
  WHERE V34 > 0

 -------3:OT trong doan tu Point1 den Point2--------------------------

  UPDATE #tmpOT
  SET MiOTStartTmp = MiOTStart
  WHERE MiOTStart >= Point1


  UPDATE #tmpOT
  SET MiOTStartTmp = Point1
  WHERE MiOTStart < Point1
  UPDATE #tmpOT
  SET MiOTEndTmp = Point2
  WHERE MiOTEnd >= Point2
  UPDATE #tmpOT
  SET MiOTEndTmp = MiOTEnd
  WHERE MiOTEnd < Point2

  UPDATE #tmpOT
  SET V12 = MiOTEndTmp - MiOTStartTmp
	


  if(exists(select 1 from tblOTDeductedTime))
  UPDATE #tmpOT -- Kiem tra OT co thuoc thoi gian bi tru ko
  SET V12 = V12 - (SELECT ISNULL(SUM(DeductedValue),0)
       FROM tblOTDeductedTime
       WHERE tblOTDeductedTime.ShiftID = #tmpOT.ShiftID
  AND MiOTStartTmp <= MiDeductedStart
        AND MiOTEndTmp >= MiDeductedEnd)

  update #tmpOT SET V12 = V12 - DeductBreakTime where V12 >= DeductBreakTime and MiBreakStart > MiOTStartTmp and MiBreakEnd < MiOTEndTmp
  --update #tmpOT SET V12 = V12 - DeductBreakTimeAfter where V12 >= DeductBreakTimeAfter and MIOTAfterStart < MiOTEndTmp and MIOTAfterStart > Point2
  --AAF Chủ nhật @HolidayOTBaseOnShiftInfo : trừ luôn đoạn nghỉ trước giờ bắt đâu tăng ca : 16:10 -> 16h:40

  update #tmpOT SET V12 = V12 - DeductBreakTimeAfter where V12 >= DeductBreakTimeAfter and MIOTAfterStart < MiOTEndTmp and MIOTAfterStart > Point2  and (daytype = 0 or @HolidayOTBaseOnShiftInfo =0)
  update #tmpOT SET V12 = V12 - DeductBreakTimeAfter where V12 >= DeductBreakTimeAfter and MIOTAfterStart > MiOTStartTmp and MIOTAfterStart < MiOTEndTmp and daytype > 0 and @HolidayOTBaseOnShiftInfo = 1
  -- AAF lam 3.75h thi dc tinh 4h 4 tieng
  update #tmpOT set V12 = 240 where Point2 = 1200 and V12 between 220 and 240
  update #tmpOT set V12 = 480 where Point2 = 1200 and V12 between 445 and 480
  UPDATE #tmpOT
  --SET V12 = (CAST(V12   +@OT_ROUND_UNIT AS INT)/@OT_ROUND_UNIT)*(CAST(@OT_ROUND_UNIT AS FLOAT)/60.0) -- lam tron len
  SET V12 = (CAST(V12 AS INT)/@OT_ROUND_UNIT)*(CAST(@OT_ROUND_UNIT AS FLOAT)/60) -- lam tron xuong
  UPDATE #tmpOT
  SET V12 = 0
  WHERE isnull(V12,0) <= 0


  -- Tinh OTFrom, OTTo
  UPDATE #tmpOT
  SET OTFrom12 = dateadd(hh,cast(MiOTStartTmp as int)/60,AttDate),
   OTTo12 = dateadd(hh,cast(MiOTEndTmp as int)/60,AttDate)
  WHERE V12 > 0

  UPDATE #tmpOT
  SET OTFrom12 = dateadd(mi,cast(MiOTStartTmp as int)%60,OTFrom12),
   OTTo12 = dateadd(mi,cast(MiOTEndTmp as int)%60,OTTo12)
  WHERE V12 > 0

  --update #tmpOT SET V12 = V12 - DeductBreakTime/60.0 where V12 >= DeductBreakTime/60.0
  --update #tmpOT SET V34 = V34 - DeductBreakTime/60.0 where V34 >= DeductBreakTime/60.0
  --update #tmpOT SET V56 = V56 - DeductBreakTime/60.0 where V56 >= DeductBreakTime/60.0
     ------------------------------OT tong cong--------------------------------
  UPDATE #tmpOT
  SET OTValue = V12 + V34 + V56

  DELETE FROM #tmpOT WHERE OTValue <= 0 -- Xoa cac ban ghi ko phai OT

   -----------------------------Ket thuc tinh OT, gio trong bang #tmpOT chi bao gom nhung ngay, nhung nguoi co OT.
   --aaF xử ly tăng ca đêm chủ Nhật nhưng ngày khòng đi làm
  update t set OTKind = 37
   from #tmpOT t where DayType = 1 and V34 > 5
  and not exists (select 1 from #tmpOT tmp where t.employeeId = tmp.employeeId and t.AttDate = tmp.AttDate and t.DayType = tmp.DayType and tmp.OTValue > 3 and V34 = 0)
  and t.ShiftID not in (select ShiftID from tblShiftSetting ss where ss.ShiftCode in ('C1','C2','C3'))
  -- AAF lo say tang ca tren 1h moi nhan
 delete t FROM #tmpOT t
 where t.OTValue < 1.5 and t.ShiftID in (select ShiftID from tblShiftSetting ss where ss.ShiftCode in ('C1','C2','C3'))

  -- tang ca dem cung chi dc tinh 1.5
 update t set OTKind = 11, OTValue = case when OTValue between 7.4 and 8.2 then 8 else OTValue end
 , V12 = case when V12 between 5.9 and 8.2 then 8 else V12 end
 , V34 = case when V34 between 5.9 and 8.2 then 8 else V34 end
 , V56 = case when V56 between 5.9 and 8.2 then 8 else V56 end
 FROM #tmpOT t
 where t.OTKind = 22 and t.ShiftID in (select ShiftID from tblShiftSetting ss where ss.ShiftCode in ('C1','C2','C3'))

 -- Lo say tang ca chu nhat dem chuyen ve tang ca ngay CN thuong
 update t set OTKind = 23, OTValue = case when OTValue between 7.4 and 8.2 then 8 else OTValue end
 , V12 = case when V12 between 5.9 and 8.2 then 8 else V12 end
 , V34 = case when V34 between 5.9 and 8.2 then 8 else V34 end
 , V56 = case when V56 between 5.9 and 8.2 then 8 else V56 end
 FROM #tmpOT t
 where t.DayType in(1) --and t.ShiftID in (select ShiftID from tblShiftSetting ss where ss.ShiftCode in ('C1','C2','C3'))
 and t.EmployeeID in ( select EmployeeID from #tblEmployeeList te where te.employeeID in ('AAF0147','AAF0148','AAF2470','AAF3446','AAF5103','AAF6211') or te.SectionID in (select SectionID from tblSection where SectionCode = 'LS'))

 -- Lo say tang ca Lễ dem chuyen ve tang ca ngay Lễ thuong
 update t set  OTKind = 21,  OTValue = case when OTValue between 7.4 and 8.2 then 8 else OTValue end
 , V12 = case when V12 between 5.9 and 8.2 then 8 else V12 end
 , V34 = case when V34 between 5.9 and 8.2 then 8 else V34 end
 , V56 = case when V56 between 5.9 and 8.2 then 8 else V56 end
 FROM #tmpOT t
 where t.DayType in(2) --and t.ShiftID in (select ShiftID from tblShiftSetting ss where ss.ShiftCode in ('C1','C2','C3'))
 and t.EmployeeID in ( select EmployeeID from #tblEmployeeList te where te.employeeID in ('AAF0147','AAF0148','AAF2470','AAF3446','AAF5103','AAF6211') or te.SectionID in (select SectionID from tblSection where SectionCode = 'LS'))

 --chi mai bảo bỏ đi
 --update t set
 --OTValue = case when OTValue between 7.4 and 8.2 then 8 else OTValue end
 --, V12 = case when V12 between 6.4 and 8.2 then 8 else V12 end
 --, V34 = case when V34 between 6.4 and 8.2 then 8 else V34 end
 --, V56 = case when V56 between 6.4 and 8.2 then 8 else V56 end
 --FROM #tmpOT t
 --where t.DayType > 0


  update #tmpOT SET V12=0 where V12 < 0.2
  update #tmpOT SET V34=0 where V34 < 0.2
  update #tmpOT SET V56=0 where V56 < 0.2

 IF COL_LENGTH('tblOTList','Period') is null ALTER TABLE tblOTList ADD [Period] tinyint NULL
 DECLARE @Approved int = 1
 if exists(select 1 from tblParameter where Code ='OT_AUTO_Approved' and value = '0')
  SET @Approved = 0
 UPDATE #tmpOT SET Approved = @Approved
 UPDATE #tmpOT SET Approved = 0 where OTCategoryID = 2 and Point1 = 945

 --OTKIND 33 khong duoc duyet.Khi nào tính mới Check vào mặc dinh là nghi giải lao kg tính e
 alter table #tmpOT add  remark nvarchar(250)
  UPDATE #tmpOT SET Approved = 0,remark = N'giờ giải lao' where OTKind = 33
if(OBJECT_ID('TA_ProcessMain_Begin_InsertOTList' )is null)
begin
exec('CREATE PROCEDURE TA_ProcessMain_Begin_InsertOTList
(
  @FromDate datetime
 ,@ToDate datetime
 ,@LoginID int
 ,@IsAuditAccount bit
 ,@StopUpdate bit output
)
as
begin
 SET NOCOUNT ON;
end')
end


SET @StopUpdate = 0
EXEC TA_ProcessMain_Begin_InsertOTList @FromDate=@FromDate, @ToDate=@ToDate, @LoginID=@LoginID, @IsAuditAccount=@IsAuditAccount, @StopUpdate=@StopUpdate output


 delete ot from tblOTList ot inner join #tblPendingTaProcessMain p on ot.EmployeeID = p.EmployeeID and ot.OTDate = p.[Date] where
 exists (select 1 from #tblEmployeeList te where ot.EmployeeID = te.employeeID)
 and ot.StatusID <> 3
delete ot
FROM tblOTList ot
inner join (
select ta.EmployeeID, ta.AttDate, ta.AttStart, ta.AttEnd, ta.MIAttEnd,ta.MIAttStart--, isnull(ss.MIOTAfterStart,ss.MIWorkEnd) MIOTAfterStart, isnull(ss.MIOTBeforeEnd,ss.MiWorkStart) MIOTBeforeEnd
,ta.MIAttEnd - isnull(ss.MIOTAfterStart,ss.MIWorkEnd)  MIOTAfter
,ta.MIAttStart - isnull(ss.MIOTBeforeEnd,ss.MiWorkStart) MIOTBefore
from #tmpHasTA_OT ta inner join #tblWSchedule ws on ta.EmployeeID = ws.EmployeeID and ta.AttDate = ws.ScheduleDate
inner join #ShiftInfo ss on ws.ShiftID = ss.ShiftID
) tmp on ot.EmployeeID = tmp.EmployeeID and ot.OTdate = tmp.AttDate
where ot.OTDate between @FromDate and @ToDate and
exists (select 1 EmployeeID from #tmpEmployee otl where ot.EmployeeID = otl.EmployeeID)
and isnull(ot.StatusID,0) = 3 and isnull(Approved,0) = 0
and not exists(select 1 from tblatt_lock al where ot.EmployeeId = al.EmployeeId and ot.OtDate = al.Date)
and (ot.OTHour > MIOTAfter/60.0 or ot.OTHour > MIOTBefore/60.0)
and not exists (select 1 from #tmpOT t where ot.EmployeeID = t.EmployeeID and  ot.OtDate = t.AttDate and t.OTKind = ot.OTKind and abs(t.OTValue - ot.OTHour) < 2)
-- AAF lái xe nang tang ca truoc tính 100%
  update o set V12 = V12*2/3,Approved = 0,OTKind = 11,remark = N'Tăng ca xe nâng'
  from #tmpOT o
  where OTCategoryID = 1 and V12 < 3
  and exists (select 1 from #tmpEmployee te where o.EmployeeID = te.EmployeeID and te.GroupID in (10))

 if @IsAuditAccount = 0
 begin
 --select * from #tmpOT
 -- delete tblOTList from tblOTList ot inner join #tblPendingTaProcessMain p on ot.EmployeeID = p.EmployeeID and ot.OTDate = p.[Date]
 --where not exists(select 1 from #tmpOT ov where ot.EmployeeID = ov.EmployeeID and ot.OTDate = ov.AttDate and ot.OTkind = ov.OTkind)
 -- and isnull(StatusID,0) <>3
 delete o from #tmpOT o
 inner join tblOTList ot on o.EmployeeID = ot.EmployeeID and o.AttDate = ot.OTDate and o.OTKind = ot.OTKind and ot.OTCategoryID = o.OTCategoryID
 and (datepart(hh,ot.OTFrom) *60 + datepart(mi, ot.OTfrom) = o.MiOTStartTmp or  datepart(hh,ot.OTFrom) *60 + datepart(mi, ot.OTfrom) = o.MiOTStartTmp - 1440)
 where ot.OTDate between @FromDate and @ToDate and ot.StatusID = 3

 delete o from #tmpOT o
 inner join tblOTList ot on o.EmployeeID = ot.EmployeeID and o.AttDate = ot.OTDate and o.OTKind = ot.OTKind and ot.OTCategoryID = o.OTCategoryID
 and (datepart(hh,ot.OTFrom) *60 + datepart(mi, ot.OTfrom) = o.Point3 or  datepart(hh,ot.OTFrom) *60 + datepart(mi, ot.OTfrom) = o.Point3 - 1440)
 where ot.OTDate between @FromDate and @ToDate and ot.StatusID = 3


 delete ot from #tmpOT o
 inner join tblOTList ot on o.EmployeeID = ot.EmployeeID and o.AttDate = ot.OTDate and o.OTKind = ot.OTKind and ot.OTCategoryID = o.OTCategoryID-- and datepart(hh,ot.OTFrom) *60 + datepart(mi, ot.OTfrom) = o.MiOTStartTmp
 where ot.OTDate between @FromDate and @ToDate and isnull(ot.StatusID,0) < 3


  select EmployeeID, OTCategoryID ,OTDate ,OTKind ,OTFrom ,OTTo
  into #tmpOT_Duplicate
  from (
    SELECT EmployeeID, OTCategoryID,AttDate as OTDate,OTKind,ShiftID,OTFrom12 as OTFrom,OTTo12 as OTTo
   FROM #tmpOT where V12 > 0
   union all
   SELECT EmployeeID, OTCategoryID,AttDate,OTKind,ShiftID,OTFrom34,OTTo34
   FROM #tmpOT WHERE V34 > 0
   union all
   SELECT EmployeeID, OTCategoryID,AttDate,OTKind,ShiftID,OTFrom56,OTTo56
   FROM #tmpOT WHERE V56 > 0
   ) as ot
  group by EmployeeID, OTCategoryID ,OTDate ,OTKind ,OTFrom ,OTTo -- lau lau lai bi duplicate
  having count(1) > 1

  delete #tmpOT from #tmpOT as ot inner join #tmpOT_Duplicate as d
   on ot.EmployeeID = d.EmployeeID and  ot.OTCategoryID = d.OTCategoryID
    and  ot.AttDate = d.OTDate and ot.OTKind = d.OTKind and  ot.OTFrom12 = d.OTFrom and  ot.OTTo12 = d.OTTo
  delete #tmpOT from #tmpOT as ot inner join #tmpOT_Duplicate as d
   on ot.EmployeeID = d.EmployeeID and  ot.OTCategoryID = d.OTCategoryID
    and  ot.AttDate = d.OTDate and ot.OTKind = d.OTKind and  ot.OTFrom34 = d.OTFrom and  ot.OTTo34 = d.OTTo
  delete #tmpOT from #tmpOT as ot inner join #tmpOT_Duplicate as d
   on ot.EmployeeID = d.EmployeeID and  ot.OTCategoryID = d.OTCategoryID
    and  ot.AttDate = d.OTDate and ot.OTKind = d.OTKind and  ot.OTFrom56 = d.OTFrom and  ot.OTTo56 = d.OTTo
	
-- duyet tang ca cho nhung bác tài xế
update o set Approved = 0 from #tmpOT o
 where o.employeeID in ('AAF4617','AAF0076','AAF0121')
 and o.OTCategoryID  = 1

 update o set Approved = 1 from #tmpOT o
 where o.employeeID in ('AAF4617','AAF0076','AAF0121')
 and o.OTCategoryID  = 1
 and exists (select 1 from #tblHasTA_Org ta where o.EmployeeID = ta.EmployeeID and o.AttDate = ta.AttDate and isnull(ta.TAStatus,0) in (1,3))
 -- tang ca truoc va sau, ngay Chu nhat, khong dc duyệt cho bộ phần Pha Mau và tạp vụ carteen
 update o set Approved = 0 from #tmpOT o
 where o.OTCategoryID  in(1,2) and o.DayType > 0
 and exists (select 1 from #tmpEmployee te where o.EmployeeID = te.EmployeeID and te.GroupID in (464,461,14)) -- sau khi test thi thấy tất cả đều ko đc
 -- pha mau tang ca truoc khong dc tu duyet
  update o set Approved = 0 from #tmpOT o
 where o.OTCategoryID  in(1) and o.DayType = 0
 and exists (select 1 from #tmpEmployee te where o.EmployeeID = te.EmployeeID and te.GroupID in (464))
  --select * from #tmpOT order by AttDate return
  INSERT INTO tblOTList(EmployeeID, OTCategoryID,OTDate,Period,OTKind,ShiftID,OTFrom,OTTo,OTHour,Approved,ApprovedHours,StatusID,MealDeductHours,Notes)
   SELECT EmployeeID, OTCategoryID,AttDate,Period,OTKind,ShiftID,OTFrom12,OTTo12,ISNULL(v12Real,V12),Approved,V12,1,MealDeductHours,remark
   FROM #tmpOT where V12 > 0
   union all
   SELECT EmployeeID, OTCategoryID,AttDate,Period,OTKind,ShiftID,OTFrom34,OTTo34,V34,Approved,V34,1,MealDeductHours,remark
   FROM #tmpOT WHERE V34 > 0
   union all
   SELECT EmployeeID, OTCategoryID,AttDate,Period,OTKind,ShiftID,OTFrom56,OTTo56,V56,Approved,V56,1,MealDeductHours,remark
   FROM #tmpOT WHERE V56 > 0
   --AAF Truc mo nuoc AAF0007,AAF0023 truc mo nuoc, ngay nao truc thi dc 80phut tang cang 100% (vao som hon khoang 40 phut va ve tren hon 10 phut)
  delete tblOTList from tblOTList ot inner join #tblPendingTaProcessMain p on ot.EmployeeID = p.EmployeeID and ot.OTDate = p.[Date]
  where Notes = N'Trực mở nước' and isnull(StatusID,0) <>3
  INSERT INTO tblOTList(EmployeeID, OTCategoryID,OTDate,Period,OTKind,ShiftID
  ,OTFrom,OTTo,OTHour,Approved,ApprovedHours,StatusID,MealDeductHours,Notes)
  select ta.EmployeeID,0,ta.AttDate,ta.Period
  --,case when daytype = 2 then 21 when ta.DayType = 1 then 23 else 11 end -- Truc mo nuoc tinh 100% het
  ,11
  ,ta.ShiftID
  ,ta.AttStart,ta.AttEnd,0.8888888888888889,0,0.8888888888888889,1,0,N'Trực mở nước'
  from #tmpHasTA ta
   where
   ta.MiWorkStart - ta.MiAttStart > 40 and ta.MiAttEnd - ta.MiWorkEnd > 1
   and ta.EmployeeID in ('AAF0007','AAF0023')
   and not exists (select 1 from tblOTList ot where ta.employeeId = ot.EmployeeId and ta.AttDate = ot.OTDate and ot.Notes = N'Trực mở nước')



if(OBJECT_ID('TA_ProcessMain_ROUND_OT' )is null)
begin
exec('CREATE PROCEDURE TA_ProcessMain_ROUND_OT
(
  @FromDate datetime
 ,@ToDate datetime
 ,@LoginID int
 ,@IsAuditAccount bit
 ,@StopUpdate bit output
)
as
begin
 SET NOCOUNT ON;
end')
end
SET @StopUpdate = 0
EXEC TA_ProcessMain_ROUND_OT @FromDate=@FromDate, @ToDate=@ToDate, @LoginID=@LoginID, @IsAuditAccount=@IsAuditAccount, @StopUpdate=@StopUpdate output
  if @StopUpdate = 0
  begin
   -- làm tròn OT theo quy tắc
   UPDATE tblOTList SET ApprovedHours = (ROUND((ApprovedHours+0.5)/0.5,0)-0.5)*0.5-0.25
   FROM tblOTList ot inner join #tblPendingTaProcessMain p on ot.EmployeeID = p.EmployeeID and ot.OTDate = p.[Date]
   where ot.ApprovedHours <> (ROUND((ApprovedHours+0.5)/0.5,0)-0.5)*0.5-0.25 and ot.StatusID <> 3

  end
  if @MATERNITY_OT = 1
   UPDATE tblOTList SET OTHour = OTHour + 1,ApprovedHours = ApprovedHours + 1
   from tblOTList ot inner join #tblPendingTaProcessMain p on ot.EmployeeID = p.EmployeeID and ot.OTDate = p.[Date]
   where OTHour >= 7
   --AND ot.EmployeeID in (select EmployeeID from #tmpHasTAMaternity) and DATEPART(dw,ot.OTDate) = 1
   AND EXISTS (SELECT 1 FROM #tmpHasTAMaternity m WHERE m.EmployeeID = ot.EmployeeID AND m.AttDate = ot.OTDate AND m.DayType > 0)
   and StatusID <> 3
 end
 else
 begin
  delete tblOTList_CT from tblOTList_CT ot inner join #tblPendingTaProcessMain p on ot.EmployeeID = p.EmployeeID and ot.OTDate = p.[Date]
  where not exists(select 1 from #OTNotOverwrite ov where ot.EmployeeID = ov.EmployeeID and ot.OTDate = ov.OTDate)

  INSERT INTO tblOTList_CT(EmployeeID, OTCategoryID,OTDate,OTKind,ShiftID,OTFrom,OTTo,OTHour,Approved,ApprovedHours,StatusID)
   SELECT EmployeeID, OTCategoryID,AttDate,OTKind,ShiftID,OTFrom12,OTTo12,ISNULL(v12Real,V12),Approved,V12,1
   FROM #tmpOT WHERE V12 > 0
   union all
   SELECT EmployeeID, OTCategoryID,AttDate,OTKind,ShiftID,OTFrom34,OTTo34,V34,Approved,V34,1
   FROM #tmpOT WHERE V34 > 0
   union all
   SELECT EmployeeID, OTCategoryID,AttDate,OTKind,ShiftID,OTFrom56,OTTo56,V56,Approved,V56,1
   FROM #tmpOT WHERE V56 > 0

  -- làm tròn OT theo quy tắc
  UPDATE tblOTList_CT SET ApprovedHours = (ROUND((ApprovedHours+0.5)/0.5,0)-0.5)*0.5-0.25
  FROM tblOTList_CT ot inner join #tblPendingTaProcessMain p on ot.EmployeeID = p.EmployeeID and ot.OTDate = p.[Date]
  where ApprovedHours <> (ROUND((ApprovedHours+0.5)/0.5,0)-0.5)*0.5-0.25 and ot.StatusID <> 3

  if @MATERNITY_OT = 1
   update tblOTList_CT  SET OTHour = OTHour + 1,ApprovedHours = ApprovedHours + 1
   from tblOTList_CT ot inner join #tblPendingTaProcessMain p on ot.EmployeeID = p.EmployeeID and ot.OTDate = p.[Date]
   where OTHour >= 7 and ot.EmployeeID in (select EmployeeID from #tmpHasTAMaternity) and DATEPART(dw,ot.OTDate)=1
    and StatusID <> 3
 end



if(OBJECT_ID('TA_ProcessMain_Finish_OTCalculator' )is null)
begin
exec('CREATE PROCEDURE TA_ProcessMain_Finish_OTCalculator
(
  @FromDate datetime
 ,@ToDate datetime
 ,@LoginID int
 ,@IsAuditAccount bit
 ,@StopUpdate bit output
)
as
begin
 SET NOCOUNT ON;
end')
end
SET @StopUpdate = 0
EXEC TA_ProcessMain_Finish_OTCalculator @FromDate=@FromDate, @ToDate=@ToDate, @LoginID=@LoginID, @IsAuditAccount=@IsAuditAccount, @StopUpdate=@StopUpdate output

/*lam toi 6h sang nhung k duoc duyet OT thi k tinh Night COunt 2*/
select EmployeeID, OTDate , case when OTTo > OTFrom then datepart(hh,OTTo)*60 + datepart(mi,OTTo)
	else datepart(hh,OTTo)*60 + datepart(mi,OTTo) + 60*24 end OTToMi
into #tmpOTMi_forNightCount
from tblOTList al where exists(select 1 from #tblPendingTaProcessMain p where al.EmployeeID = p.EmployeeID and al.OTDate = p.Date)
and al.Approved = 1

update al set NightCount = 0, WorkUntil6AM = 0 from tblAllBusinessTrip al
where exists(select 1 from #tblPendingTaProcessMain p where al.EmployeeID = p.EmployeeID and al.AttDate = p.Date)
and al.WorkUntil6AM = 1
and not exists(select 1 from #tmpOTMi_forNightCount ns where al.EmployeeID = ns.EmployeeID and al.AttDate = ns.OTDate and ns.OTToMi >= 1770)

drop table #tmpOTMi_forNightCount


 DROP TABLE #tmpOT
 DROP TABLE #tmpHasTA_OT
 END
end



 --end OT

 --begin  Night Shift

if(OBJECT_ID('TA_ProcessMain_InsertOTAddition' )is null)
begin
exec('CREATE PROCEDURE TA_ProcessMain_InsertOTAddition
(
  @FromDate datetime
 ,@ToDate datetime
 ,@LoginID int
 ,@IsAuditAccount bit
 ,@StopUpdate bit output
)
as
begin
 SET NOCOUNT ON;
end')
end
SET @StopUpdate = 0
EXEC TA_ProcessMain_InsertOTAddition @FromDate=@FromDate, @ToDate=@ToDate, @LoginID=@LoginID, @IsAuditAccount=@IsAuditAccount, @StopUpdate=@StopUpdate output

--begin ns, begin night shift
if(@StopUpdate = 0 and @IsAuditAccount = 0)
begin
  DECLARE
    @IS_OT_IN_NIGHTSHIFT BIT,
    @NIGHT_SHIFT_START  DATETIME,
    @NIGHT_SHIFT_STOP  DATETIME,
    @Point1    int,
    @Point2    int,
    @Point3    int,
    @Point4    int
  BEGIN
 DECLARE @NS_ROUND_UNIT int
  SET @NS_ROUND_UNIT = (select cast(value as float) from tblParameter where code = 'NS_ROUND_UNIT')
  SET @NS_ROUND_UNIT = isnull(@NS_ROUND_UNIT,30)

 IF @NS_ROUND_UNIT <=0 SET @NS_ROUND_UNIT = 1
  SET @IS_OT_IN_NIGHTSHIFT = (select cast(value as float) from tblParameter where code = 'IS_OT_IN_NIGHTSHIFT')
  SET @IS_OT_IN_NIGHTSHIFT = isnull(@IS_OT_IN_NIGHTSHIFT,30)
  ---------------------------------------------------------------------------------------------------

  CREATE TABLE #tmpNS
  (
   EmployeeID  nvarchar(20),
   AttDate  datetime,
   Period  int,
   ShiftID  int,
   DayType  int,

   AttStart datetime,
   AttEnd  datetime,

   MiAttStart int,  -- Doi gio bat dau lam viec ra phut so voi AttDate
   MiAttEnd int,  -- Doi gio ket thuc lam viec ra phut so voi AttDate
   MiBreakStart int,
   MiBreakEnd int,
   MiWorkStart int,  -- Doi gio bat dau cua ca ra phut so voi AttDate
   MiWorkEnd int,  -- Doi gio ket thuc cua ca ra phut so voi AttDate

   MiNSStart int,
   MiNSEnd  int,


   MiNSStartTmp int,
   MiNSEndTmp int,

   Point1  int,
   Point2  int,
   Point3  int,
   Point4  int,
   V12   float,
   V34   float,
   NSKind  int,
   NSValue  float
  )

  --create table #NSSetting(NSKind int, DayType int, NSFrom time, NSTo Time,NSFromDate datetime, NSToDate DateTime, NSValue float)
  --insert into #NSSetting(NSKind,DayType,NSFrom,NSTo,NSFromDate,NSToDate,NSValue)
--select NSKind,DayType,NSFrom,NSTo,NSFrom,NSTo,NSValue from tblNightShiftSetting
  --select * from #NSSetting return
  INSERT INTO #tmpNS(EmployeeID, AttDate, ShiftID,DayType, AttStart, AttEnd, MiAttStart, MiAttEnd, MiBreakStart, MiBreakEnd, MiWorkStart, MiWorkEnd,Period)
  SELECT ta.EmployeeID, ta.AttDate, ta.ShiftID, ta.DayType, ta.AttStart MinAttTime,ta.AttEnd MaxAttTime,ta.MiAttStart MinMiAttStart,ta.MiAttEnd MaxMiAttEnd, MiBreakStart, MiBreakEnd, ta.MiWorkStart MinMiWorkStart, ta.MiWorkEnd MaxMiWorkEnd,Period
  FROM #tmpHasTA ta where ta.AttStart is not null and ta.AttEnd is not null

 ---------------------------------------Kiem tra
  DELETE tmp FROM #tmpNS tmp -- Xoa du lieu ko can tinh toan
  where exists(select 1 from tblNightShiftList ns where tmp.EmployeeID = ns.EmployeeID and tmp.AttDate = ns.[Date] and ns.StatusID = 3)

 ----------------------------------------------------------------------------------------------------------

  IF @IS_OT_IN_NIGHTSHIFT = 0 -- Neu thoi gian night shift khong bao gom thoi gian OT (vi da co loai OT 30% hoac 180,230...)
  BEGIN      -- Khi do thoi gian de tinh night shift chi co the trong gio cua ca

   --DELETE FROM #tmpNS WHERE DayType != 0 -- Xoa thoi gian ngay nghi (HolidayStatus !=0) do da duoc tinh trong OT

   UPDATE #tmpNS
   SET  MiNSStart = MiAttStart
   WHERE MiAttStart >= MiWorkStart -- Di lam muon, gio bat dau tinh Nigh shift la gio vao thuc te MiAttStart

   UPDATE #tmpNS
   SET  MiNSStart = MiWorkStart

   WHERE MiAttStart <= MiWorkStart+15 -- Di lam som (co OT before), gio bat dau tinh night shift la gio vao cua ca MiWorkStart

   UPDATE #tmpNS
   SET  MiNSEnd = MiAttEnd -- Di ve som, gio ket thuc tinh nightshift la gio ra thuc te MiAttEnd
   WHERE MiAttEnd <= MiWorkEnd

   UPDATE #tmpNS
  SET  MiNSEnd = MiWorkEnd -- Di ve muon (co OT after), gio bat dau tinh night shift la gio ket thuc ca MiWorkEnd
   WHERE MiAttEnd+15 > MiWorkEnd

  END
  ELSE ------------------- Thoi gian tinh NS bao gom ca thoi gian cua OT (vi ko co loai OT 30%, 180%,230%....)
  BEGIN --------------------Truong hop nay se lay thoi gian bat dau va ket thuc lam viec thuc te de tinh night shift
   -- OT trong NS thì đã được trợ cấp 30% lương của OT đó rồi, nên NS ko tinh cho ca thường nữa, chỉ tính cho ca đêm (Ca3)
   DELETE #tmpNS where ShiftID not in (select ShiftID from tblShiftSetting where datepart(hh, WorkStart) > datepart(hh, WorkEnd))
   UPDATE #tmpNS SET MiNSStart = MiAttStart, MiNSEnd = MiAttEnd
  END

  ----------------------------------------------Tinh night shift ---------------------------------
  select DayType, NSKind, NSValue,datepart(hh,NSFrom)*60 + datepart(mi,NSFrom) as NSFrom,
   datepart(hh,NSTo)*60 + datepart(mi,NSTo) as NSTo into #tmpNSSetting from tblNightShiftSetting

  UPDATE #tmpNS
  SET  Point1 = 0,
    Point2 = 0,
    Point3 = NSFrom,
    Point4 = NSTo,
    NSKind = s.NSKind
  FROM #tmpNS t inner join #tmpNSSetting s on t.DayType = s.DayType

  -- Trong TH vat qua ngay` thi phai kiem tra 2 doan (Point1 den Point2, Point3 den Point4)
  -- VD:Khoang tu 0h - 6h va` khoang tu 22h den 6h+24h
  UPDATE  #tmpNS
  SET  Point2 = Point4,
    Point4 = Point4 + 24*60
  WHERE Point3 > Point4

if(OBJECT_ID('TA_ProcessMain_Finish_NightShift_SetPoint') is null)
begin
exec('CREATE PROCEDURE TA_ProcessMain_Finish_NightShift_SetPoint
(
  @FromDate datetime
 ,@ToDate datetime
 ,@LoginID int
 ,@IsAuditAccount bit
 ,@StopUpdate bit output
)
as
begin
 SET NOCOUNT ON;
end')
end
SET @StopUpdate = 0
EXEC TA_ProcessMain_Finish_NightShift_SetPoint @FromDate=@FromDate, @ToDate=@ToDate, @LoginID=@LoginID, @IsAuditAccount=@IsAuditAccount, @StopUpdate=@StopUpdate output


  -------1: Night Shift trong khoang Point1 den Point2:

  UPDATE #tmpNS
  SET  MiNSStartTmp = MiNSStart
  WHERE MiNSStart >= Point1

  UPDATE #tmpNS
  SET  MiNSStartTmp = Point1
  WHERE MiNSStart < Point1

  UPDATE #tmpNS
  SET  MiNSEndTmp = Point2
  WHERE MiNSEnd >= Point2

  UPDATE #tmpNS
  SET  MiNSEndTmp = MiNSEnd
  WHERE MiNSEnd < Point2

 --select * from #tmpNS
  UPDATE #tmpNS SET V12 = MiNSEndTmp - MiNSStartTmp
  UPDATE #tmpNS SET V12 = (MiNSEndTmp - MiBreakEnd) + (MiBreakStart - MiNSStartTmp) where MiBreakStart > MiNSStartTmp and MiBreakEnd < MiNSEndTmp --lam day du
  UPDATE #tmpNS SET V12 = (CASE WHEN MiNSEndTmp >= MiBreakStart THEN MiBreakStart ELSE MiNSEndTmp END) - MiNSStartTmp where MiBreakStart >= MiNSStartTmp and MiNSEndTmp <= MiBreakEnd --lam toi gio nghi giua gio roi ve
  UPDATE #tmpNS SET V12 = MiNSEndTmp - (CASE WHEN MiNSStartTmp >= MiBreakEnd THEN MiNSStartTmp ELSE MiBreakEnd END) where MiNSStartTmp >= MiBreakStart and MiNSEndTmp > MiBreakEnd --vao lam sau khi nghi giua gio
  UPDATE #tmpNS SET V12 = (CAST(ISNULL(V12,0) as int)/@NS_ROUND_UNIT) * (CAST(@NS_ROUND_UNIT AS FLOAT)/60) --(CAST(MiNSEndTmp - MiNSStartTmp AS INT)/@NS_ROUND_UNIT) * (CAST(@NS_ROUND_UNIT AS FLOAT)/60)

  UPDATE #tmpNS
  SET V12 = 0
  WHERE isnull(V12,0) <=0

  --------2: Night shift trong khoang Point3 den Point4
  UPDATE #tmpNS
  SET  MiNSStartTmp = MiNSStart
  WHERE MiNSStart >= Point3

  UPDATE #tmpNS
  SET  MiNSStartTmp = Point3
  WHERE MiNSStart < Point3

  UPDATE #tmpNS
  SET  MiNSEndTmp = Point4
  WHERE MiNSEnd >= Point4

  UPDATE #tmpNS
  SET  MiNSEndTmp = MiNSEnd
  WHERE MiNSEnd < Point4


  UPDATE #tmpNS SET V34 = MiNSEndTmp - MiNSStartTmp
  UPDATE #tmpNS SET V34 = (MiNSEndTmp - MiBreakEnd) + (MiBreakStart - MiNSStartTmp) where MiBreakStart > MiNSStartTmp and MiBreakEnd < MiNSEndTmp --lam day du
  UPDATE #tmpNS SET V34 = (CASE WHEN MiNSEndTmp >= MiBreakStart THEN MiBreakStart ELSE MiNSEndTmp END) - MiNSStartTmp where MiBreakStart >= MiNSStartTmp and MiNSEndTmp <= MiBreakEnd --lam toi gio nghi giua gio roi ve
  UPDATE #tmpNS SET V34 = MiNSEndTmp - (CASE WHEN MiNSStartTmp >= MiBreakEnd THEN MiNSStartTmp ELSE MiBreakEnd END) where MiNSStartTmp >= MiBreakStart and MiNSEndTmp > MiBreakEnd --vao lam sau khi nghi giua gio
  UPDATE #tmpNS SET V34 = (CAST(ISNULL(V34,0) as int)/@NS_ROUND_UNIT) * (CAST(@NS_ROUND_UNIT AS FLOAT)/60)
  --UPDATE #tmpNS SET V34 = (CAST(MiNSEndTmp - MiNSStartTmp AS INT)/@NS_ROUND_UNIT) * (CAST(@NS_ROUND_UNIT AS FLOAT)/60)

  UPDATE #tmpNS
  SET V34 = 0
  WHERE isnull(V34,0) <=0

  -----------Night shift tong:
  UPDATE #tmpNS

  SET NSValue = V12 + V34

  ----------------------------Xoa nhung ban ghi ko co night shift ----------------------------
 DELETE FROM #tmpNS WHERE NSValue <=0 OR NSValue IS NULL
if(OBJECT_ID('TA_ProcessMain_ROUND_NS' )is null)
begin
exec('CREATE PROCEDURE TA_ProcessMain_ROUND_NS
(
  @FromDate datetime
 ,@ToDate datetime
 ,@LoginID int
 ,@IsAuditAccount bit
 ,@StopUpdate bit output
)

as
begin
 SET NOCOUNT ON;
end')
end
SET @StopUpdate = 0
EXEC TA_ProcessMain_ROUND_NS @FromDate=@FromDate, @ToDate=@ToDate, @LoginID=@LoginID, @IsAuditAccount=@IsAuditAccount, @StopUpdate=@StopUpdate output
if @StopUpdate = 0
begin
 UPDATE #tmpNS SET NSValue = ROUND(NSValue,4)
 update #tmpNS set NSValue = 8 where NSValue between 6.5 and 8
end


 -- Note: sau nay co the phai dieu chinh Point, point 2, Point3, Point4 theo shift nhu gia tri AdjustTime khi tinh overtime, It's so easy :D
 delete #tmpNS where NSKind <> 1
 -----------------------------Ket thuc tinh ns, gio trong bang #tmpNS chi bao gom nhung ngay, nhung nguoi co OT.
  /*--Xoa du lieu truoc khi insert
 DELETE tblNightShiftList FROM tblNightShiftList ot
 inner join #tblPendingTaProcessMain p on ot.EmployeeID = p.EmployeeID and ot.[Date] = p.[Date]
 WHERE StatusID <> 3

INSERT INTO tblNightShiftList(EmployeeID, [Date], Period,NSKind,ShiftID,AttStart,AttEnd, Hours, Approval, HourApprove, StatusID)
  SELECT EmployeeID, AttDate,0, NSKind,ShiftID,AttStart,AttEnd, NSValue, 1, NSValue, 1
  FROM #tmpNS as tmp

  where not exists(select 1 from tblNightShiftList as ns where ns.employeeid = tmp.employeeid and ns.date = tmp.AttDate)
 -- làm tròn OT theo quy tắc

 2.1, 2.2 tính 2
 , 2.3 2.4 - 2.5- 2.6, 2.7  tính 2.5
 , 2.8 2.9, 3, 3.1, 3.2, 3.3 tính 3
 */
 --UPDATE tblNightShiftList SET HourApprove = (ROUND((HourApprove+0.5)/0.5,0)-0.5)*0.5-0.25 FROM tblNightShiftList ot INNER JOIN #tmpNS ta ON ot.EmployeeID = ta.EmployeeID AND ot.Date = ta.AttDate
 END
END
 --end Night Shift


delete tblPendingTaProcessMain from tblPendingTaProcessMain d where EmployeeId in (select distinct EmployeeID from #tmpEmployee) and [date] between @fromdate and @todate
and not exists(select 1 from #tmpOT_Duplicate as dup where dup.employeeid = d.EmployeeID and dup.OTDate = d.Date)

if(OBJECT_ID('TA_ProcessMain_ConfigTAData' )is null)
begin
exec('CREATE PROCEDURE TA_ProcessMain_ConfigTAData
(
  @FromDate datetime
 ,@ToDate datetime
 ,@LoginID int
 ,@IsAuditAccount bit
 ,@StopUpdate bit output
)
as
begin
 SET NOCOUNT ON;
end')
end
SET @StopUpdate = 0
EXEC TA_ProcessMain_ConfigTAData @FromDate=@FromDate, @ToDate=@ToDate, @LoginID=@LoginID, @IsAuditAccount=@IsAuditAccount, @StopUpdate=@StopUpdate output
--AAF lo say dua gio lam ca 3 vao ot 1.5
 delete ot from #tmpNS o
 inner join tblOTList ot on o.EmployeeID = ot.EmployeeID and o.AttDate = ot.OTDate and ot.OTKind = 11 and ot.OTCategoryID = 6
 where ot.OTDate between @FromDate and @ToDate and isnull(ot.StatusID,0) < 3

INSERT INTO tblOTList(EmployeeID, OTCategoryID,OTDate,Period,OTKind,ShiftID,OTFrom,OTTo,OTHour,Approved,ApprovedHours,StatusID,MealDeductHours,Notes)
  select ta.EmployeeID,6,ta.AttDate,ta.Period,11,ta.ShiftID,ta.AttStart,ta.AttEnd,ta.NSValue*0.3/1.5,case when ta.NSValue > 4 then 1 else 0 end,ta.NSValue*0.3/1.5,1,0,N'Giờ làm đêm'
   from #tmpNS ta
   where ta.NSValue > 0
   and ta.ShiftID in (select ShiftID from tblShiftSetting ss where ss.ShiftCode in ('C1','C2','C3','22-06','HC-Dem'))
   and ta.EmployeeID not in ('AAF3446')
   and not exists (select 1 from tblOTList o where ta.employeeId = o.EmployeeID and ta.AttDate = o.OTDate and o.OTCategoryID = 6)
 DROP TABLE #tmpHasTA
 DROP TABLE #tmpEmployee
 DROP TABLE #Maternity
 DROP TABLE #ShiftInfo
 DROP TABLE #tblEmployeeWithoutOT
 DROP TABLE #tblLvHistoryP
 drop table #tblHasTA_Org
 drop table #tblWSchedule
  DROP TABLE #tmpNS

exec ('Enable trigger ALL on tblWSchedule')
exec ('Enable trigger ALL on tblHasTA')
exec ('Enable trigger ALL on tblLvhistory')
print 'eof'
END

/*
exec sp_InsertPendingProcessAttendanceData @LoginID=15,@Fromdate='2019-05-17',@ToDate='2019-05-18',@EmployeeID='-1'
exec TA_Process_Main @LoginID=15,@Fromdate='2019-05-17',@ToDate='2019-05-18',@EmployeeID='-1'
exec sp_ReCalculate_TAData @LoginID=25,@Fromdate='20190926',@ToDate='20190926',@EmployeeID_Pram='-1',@RunShiftDetector = 0,@RunTA_Precess_Main = 1
*/
GO