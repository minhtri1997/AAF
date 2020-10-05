USE Paradise_WTC
GO
if object_id('[dbo].[sp_ShiftDetector]') is null
	EXEC ('CREATE PROCEDURE [dbo].[sp_ShiftDetector] as select 1')
GO
ALTER PROCEDURE [dbo].[sp_ShiftDetector]
(
  @LoginID int = null
 ,@FromDate datetime = null
 ,@ToDate datetime = null
 ,@EmployeeID varchar(20) = '-1'
)
--WITH encryption
AS
BEGIN
--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

/*

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tblShiftGroupByDivision]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[tblShiftGroupByDivision](
	[DivisionID] [int] NOT NULL,
	[ShiftGroupCode] [int] NOT NULL,
	[FromDate] [datetime] NULL,
	[ToDate] [datetime] NULL,
	[Notes] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_tblShiftGroupByDivision] PRIMARY KEY CLUSTERED
(
	[DivisionID] ASC,
	[ShiftGroupCode] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END


IF COL_LENGTH('tblHasTA','AttMiddle') is NULL EXEC ('ALTER TABLE tblHasTA ADD [AttMiddle] datetime NULL')
--tblShiftGroupByDivision

IF COL_LENGTH('tblSection','LATE_PERMIT') is null alter table tblSection add LATE_PERMIT float
IF COL_LENGTH('tblSection','Working2ShiftADay') is null alter table tblSection add Working2ShiftADay bit
IF COL_LENGTH('tblDepartment','Working2ShiftADay') is null alter table tblDepartment add Working2ShiftADay bit
IF COL_LENGTH('tblDivision','Working2ShiftADay') is null alter table tblDivision add Working2ShiftADay bit
IF COL_LENGTH('tblDepartment','LATE_PERMIT') is null alter table tblDepartment add LATE_PERMIT float
IF COL_LENGTH('tblDivision','LATE_PERMIT') is null alter table tblDivision add LATE_PERMIT float
IF COL_LENGTH('tblPosition','LATE_PERMIT') is null alter table tblPosition add LATE_PERMIT float

IF COL_LENGTH('tblSection','EARLY_PERMIT') is null alter table tblSection add EARLY_PERMIT float
IF COL_LENGTH('tblDepartment','EARLY_PERMIT') is null alter table tblDepartment add EARLY_PERMIT float
IF COL_LENGTH('tblDivision','EARLY_PERMIT') is null alter table tblDivision add EARLY_PERMIT float
IF COL_LENGTH('tblPosition','EARLY_PERMIT') is null alter table tblPosition add EARLY_PERMIT float
IF COL_LENGTH('[dbo].[tblWSchedule]','ApprovedHolidayStatus') is null ALTER TABLE  [dbo].[tblWSchedule] ADD [ApprovedHolidayStatus] [bit] NULL
IF COL_LENGTH('tblDivision','ManagerID') is null ALTER TABLE tblDivision ADD [ManagerID] varchar(20)
IF COL_LENGTH('tblDivision','IsNotCheckTA') is null ALTER TABLE tblDivision ADD [IsNotCheckTA] bit
IF COL_LENGTH('tblDepartment','Security24hWorking') is null ALTER TABLE tblDepartment ADD [Security24hWorking] bit
IF COL_LENGTH('tblSection','Security24hWorking') is null ALTER TABLE tblSection ADD [Security24hWorking] bit
IF COL_LENGTH('tblDepartment','OTCalculated') is null ALTER TABLE tblDepartment ADD OTCalculated bit
IF COL_LENGTH('tblShiftSetting','isOfficalShift') is null ALTER TABLE tblShiftSetting ADD isOfficalShift bit
IF COL_LENGTH('tblOTList','Period') is null ALTER TABLE tblOTList ADD [Period] tinyint NULL

if not exists (select 1 from tblParameter where Code = 'RemoveDuplicateAttTime_Interval')
insert into tblParameter(Code,Value,Category,Description,Visible)
values('RemoveDuplicateAttTime_Interval','120','TIME ATTENDANCE',N'Xóa bỏ những dòng bấm giờ công liên tiếp trong khoảng thời gian bao nhiêu giây? Nhập số giây',1)

if not exists (select 1 from tblParameter where Code = 'IgnoreTimeOut_ShiftDetector')
insert into tblParameter(Code,Value,Category,Description,Visible)
values('IgnoreTimeOut_ShiftDetector','0','TIME ATTENDANCE',N'Không dựa trên giờ bấm ra để làm cơ sở nhận dạng ca làm việc (nhập 1 xác nhận đúng vậy, 0: xác nhận có)',1)
if not exists (select 1 from tblParameter where Code = 'StatisticShiftPerweek_ShiftDetector')
insert into tblParameter(Code,Value,Category,Description,Visible)
values('StatisticShiftPerweek_ShiftDetector','330','TIME ATTENDANCE',N'Thông kê số lần đi ca nào trong tuần nhiều nhất thì ưu tiên nhân ca đó: Nhập 0 nêu không thống kê, nhập số điểm tăng thêm nếu có thống kê',1)

if not exists (select 1 from tblParameter where Code = 'WrongShiftProcess_ShiftDetector')
insert into tblParameter(Code,Value,Category,Description,Visible)
values('WrongShiftProcess_ShiftDetector','1','TIME ATTENDANCE',N'Xử lý phạt điểm những ca nhận nhầm sẽ dẫn đến làm mất giờ công (nhập 1 nếu muốn bật tính năng này, nhập 0 nếu không dùng tính năng này)',1)

*/

if(OBJECT_ID('CheckIsRunningProc' )is null)
execute ('CREATE FUNCTION [dbo].[CheckIsRunningProc] (@ProcName nvarchar(255)) returns bit Begin
 if exists (select 1 from sys.sysprocesses as qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st where object_name(st.objectid) = @ProcName and st.dbid = DB_ID() and qs.status in (''runnable'',''suspended''))
  return 1

 return 0
end')

--nhung account con lai thi thả cổng cho chạy bt
if [dbo].[CheckIsRunningProc]('sp_ShiftDetector') = 1 AND (/*@LoginID = 3 OR */NOT EXISTS (SELECT 1 FROM tblSC_Login WHERE LoginID = @LoginID))
RETURN

if OBJECT_ID('sp_ShrinkTempDatabase') > 0
 exec sp_ShrinkTempDatabase
SET NOCOUNT ON;
SET ANSI_WARNINGS OFF;

declare @sysDatetime datetime2 = SYSDATETIME()
declare @StopUpdate bit = 0
SET @EmployeeID = ISNULL(@EmployeeID,'-1')
if LEN(@EmployeeID) <= 1 set @EmployeeID = '-1'


--  get Fromdate, ToDate from Pendding data
if @FromDate is null or @ToDate is NULL
BEGIN
 SELECT @FromDate = MIN(Date),  @ToDate = MAX(Date) FROM dbo.tblPendingImportAttend  WHERE LoginID = @LoginID
 IF DATEDIFF(DAY, @FromDate,@ToDate) > 45
 BEGIN
  SET @ToDate = NULL
 end
END

if @FromDate is null or @ToDate is null
begin
 select @FromDate= ISNULL(@FromDate,Fromdate), @ToDate = isnull(@ToDate,Todate) from dbo.fn_Get_SalaryPeriod_ByDate(getdate())
  delete tblPendingImportAttend where date < @FromDate
end

IF NOT EXISTS (SELECT 1 FROM dbo.tblPendingImportAttend WHERE Date BETWEEN @FromDate AND @ToDate)
RETURN
-- neu @loginID is null thì xử lý toàn bộ nhan vien trong pending
IF @LoginID is NULL
BEGIN
SET @LoginID = 6900
DELETE dbo.tmpEmployeeTree WHERE LoginID = @LoginID
INSERT INTO tmpEmployeeTree(EmployeeID, LoginID)
SELECT DISTINCT EmployeeID, @LoginID FROM tblPendingImportAttend  WHERE Date BETWEEN @FromDate AND @ToDate
END
 SELECT DivisionID,IsNotCheckTA,Working2ShiftADay into #tblDivision from tblDivision
 if exists(select 1 from tblCompany where UseAttendanceMachine =0)
  update #tblDivision set IsNotCheckTA= 1



select te.EmployeeID,TerminateDate,PositionID
,te.DivisionID,te.DepartmentID,te.SectionID,te.GroupID,te.EmployeeTypeID,te.EmployeeStatusID
,Sex,isnull(ta.NotCheckTA,isnull(dv.IsNotCheckTA,0)) NotCheckTA,ta.UseImportTaData,HireDate
,isnull(ss.Security24hWorking,ISNULL(td.Security24hWorking,0)) Security24hWorking -- x? lý nh?ng nhân viên b?o v? di làm 24h 1 ngày
,isnull(ss.Working2ShiftADay,ISNULL(td.Working2ShiftADay,isnull(dv.Working2ShiftADay,0))) Working2ShiftADay -- thong tin nhan vien di lam chong ca (1 ngay lam 2 ca)
,isnull(et.SaturdayOff,0)as SaturdayOff,isnull(et.SundayOff,0) as SundayOff
into #tblEmployeeList
from dbo.fn_vtblEmployeeList_Simple_ByDate(@ToDate,@EmployeeID,@LoginID) te
left join tblEmployeeTAOptions ta on te.TAOptionID = ta.TAOptionID
left join #tblDivision dv on te.DivisionID = dv.DivisionID
left join tblDepartment td on te.DepartmentID = td.DepartmentID
left join tblSection ss on te.SectionID = ss.SectionID
left join tblEmployeeType et on et.EmployeeTypeID = te.EmployeeTypeID



if not exists (select 1 from tblShiftDetector_InOutStatistic)
and exists (select 1 from tblWSchedule ws
inner join #tblEmployeeList te on ws.EmployeeID = te.EmployeeID
where te.TerminateDate is null and DATEDIFF(day,ws.ScheduleDate, @FromDate) > 30)
begin
 exec sp_ShiftDetector_InOutStatistic
END



DECLARE @FromDate3 datetime, @ToDate3 datetime
,@FromMonthYear int, @ToMonthYear int
,@iCount int, @Month int, @Year int


,@Re_Process int = 0

declare @MATERNITY_LATE_EARLY_OPTION int ,@AUTO_FILL_TIMEINOUT_FWC int
select @MATERNITY_LATE_EARLY_OPTION = isnull((select top 1 cast(Value as int) from tblparameter where Code ='MATERNITY_LATE_EARLY_OPTION'),0)
select @AUTO_FILL_TIMEINOUT_FWC = isnull((select top 1 cast(Value as int) from tblparameter where Code ='AUTO_FILL_TIMEINOUT_FWC'),0)

set @FromDate = CAST(@FromDate as date)

select ta.EmployeeID,ta.[Date]
, CAST(0 as int) as EmployeeStatusID
, CAST(0 as int) as NotTrackTA
into #tblPendingImportAttend

from tblPendingImportAttend ta
left join #tblEmployeeList e on e.employeeID = ta.EmployeeID and ta.Date >= e.HireDate
left join tblAtt_lock al on ta.EmployeeId = al.EmployeeId and ta.[date] = al.[date]
where ta.[Date] between @FromDate and @ToDate AND LoginID = @LoginID and e.EmployeeID is not null and al.EmployeeID is null
--and exists (select 1 from #tblEmployeeList e where e.employeeID = ta.EmployeeID and ta.Date >= e.HireDate)
--and not exists(select 1 from tblAtt_lock al where ta.EmployeeId = al.EmployeeId and ta.[date] = al.[date])


if ROWCOUNT_BIG() <=0
return

--CREATE CLUSTERED INDEX ix_PendingImportAttend ON #tblPendingImportAttend(EmployeeID,Date)



if(OBJECT_ID('sp_ShiftDetector_PrepareDataForProcessing' )is null)
begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_PrepareDataForProcessing
(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUpdate = 0
exec dbo.sp_ShiftDetector_PrepareDataForProcessing @StopUpdate output ,@LoginID,@FromDate,@ToDate

/*
exec ('Disable trigger all on tblWSchedule')
exec ('Disable trigger all on tblHasTA')
exec ('Disable trigger all on tblLvhistory')
*/
insert into #tblPendingImportAttend(EmployeeID,[Date],EmployeeStatusID)
select EmployeeID,dateadd(day,-1,[Date]),0 from #tblPendingImportAttend ta1
where not exists(select 1 from #tblPendingImportAttend ta2 where ta1.EmployeeID = ta2.EmployeeID and ta1.[Date] = dateadd(day,1,ta2.[Date]))

-- chua vao lam, loai ra khoi pending
DELETE #tblPendingImportAttend FROM #tblPendingImportAttend p
WHERE EXISTS (SELECT 1 FROM #tblEmployeeList e WHERE e.EmployeeID = p.EmployeeID AND e.HireDate > p.Date)



SET @FromDate = DATEADD(day,-1,@FromDate)

set @FromDate3 = DATEADD(day,-1,@FromDate)
set @ToDate3 = DATEADD(day,3,@ToDate)
select @FromMonthYear = Month+Year*12 from dbo.fn_Get_Sal_Month_Year(@FromDate)
select @ToMonthYear = Month+Year*12 from dbo.fn_Get_Sal_Month_Year(@ToDate)


--delete tblPendingImportAttend where employeeId not in (select EmployeeID from tblEmployee)

--declare @prev3Todate date = dateadd(day,-5,getdate())
--declare @today date = getdate()
--if(@prev3Todate > @ToDate)
--set @prev3Todate = @ToDate

--if(@today > @ToDate)
--set @today = @ToDate
--exec sp_InsertPendingProcessAttendanceData @loginID,@prev3Todate,@today

delete te from #tblEmployeeList te where not exists (select 1 from #tblPendingImportAttend p where te.EmployeeID = p.EmployeeID)



-- neu ShiftId = 0 ma trang thai Approved = 1 thi set Approved = 0
update s set Approved = 0 from tblWSchedule s
where s.ShiftID = 0 and s.Approved = 1 and
s.ScheduleDate between @FromDate3 and @ToDate3 and
exists (select 1 from #tblEmployeeList t where t.EmployeeID = s.EmployeeID)


declare @trackingML bit = 0
 if exists(select 1 from tblParameter where Code = 'TRACKING_ATT_WHILE_ML' and Value ='1')
 set @trackingML = 1

UPDATE #tblPendingImportAttend SET EmployeeStatusID = es.EmployeeStatusID
, NotTrackTA = case when CutSI = 1 and (@trackingML = 0 ) then 1 else 0
 end
from #tblPendingImportAttend pen
inner join dbo.fn_EmployeeStatusRange(0) es
inner join tblEmployeeStatus e on es.EmployeeStatusID = e.EmployeeStatusID
on pen.EmployeeID = es.EmployeeID and pen.[Date] between es.ChangedDate and es.StatusEndDate

-- chua vao lam
delete tblHasTA from tblHasTA ta
inner join #tblEmployeeList e on ta.EmployeeID = e.EmployeeID and ta.AttDate < e.[HireDate] --and NotTrackTA =1

--loai bo nhan vien thai san va nhan vien nghi viec
delete tblHasTA from tblHasTA ta
inner join #tblPendingImportAttend p on ta.EmployeeID = p.EmployeeID and ta.AttDate = p.[Date] and NotTrackTA =1
where ISNULL(ta.TAStatus,0) <> 3

delete tblWSchedule from tblWSchedule ta
inner join #tblPendingImportAttend p on ta.EmployeeID = p.EmployeeID and ta.ScheduleDate = p.[Date] and NotTrackTA =1
where ISNULL(ta.DateStatus,1) <> 3

delete tblLvHistory from tblLvHistory ta
inner join #tblPendingImportAttend p on ta.EmployeeID = p.EmployeeID and ta.LeaveDate = p.[Date] and NotTrackTA =1

--Wtc: delete nhung records leave rac'
delete tblLvHistory from tblLvHistory lv
inner join #tblEmployeeList te on lv.EmployeeID = te.EmployeeID
where lv.LeaveDate between dateadd(dd,-1,@FromDate) and @ToDate and (lv.LeaveDate < te.HireDate or lv.LeaveDate >= isnull(te.TerminateDate,'9999-01-01'))

delete #tblPendingImportAttend  where NotTrackTA =1

-- preparing data
-- Shift list
select IDENTITY(int,1,1) as STT,0 as ShiftID,
 ShiftCode,
 max(isnull(SwipeOptionID,3)) SwipeOptionID
 , max(datepart(hour,WorkStart)*60 + DATEPART(minute,WorkStart)) WorkStartMi
 ,max(datepart(hour,WorkEnd)*60 + DATEPART(minute,WorkEnd)) WorkEndMi
 ,max(datepart(hour,BreakStart)*60 + DATEPART(minute,BreakStart)) BreakStartMi
 ,max(datepart(hour,BreakEnd)*60 + DATEPART(minute,BreakEnd)) BreakEndMi
 ,cast(0.0 as float) as ShiftHours
 ,max(datepart(hour,OTBeforeStart)*60 + DATEPART(minute,OTBeforeStart)) OTBeforeStartMi
 ,max(datepart(hour,OTBeforeEnd)*60 + DATEPART(minute,OTBeforeEnd)) OTBeforeEndMi
 ,max(datepart(hour,OTAfterStart)*60 + DATEPART(minute,OTAfterStart)) OTAfterStartMi
 ,max(datepart(hour,OTAfterEnd)*60 + DATEPART(minute,OTAfterEnd)) OTAfterEndMi
 ,cast(0 as bit) as isNightShift
 ,isnull(isOfficalShift,0) isOfficalShift
 ,cast(0 as int) WorkStartStatisticMi
 ,cast(0 as int) WorkEndStatisticMi
 ,max(WorkStart) as WorkStart,max(WorkEnd) as WorkEnd
 ,max(Std_Hour_PerDays) * 60 as STDWorkingTime_SS
into #tblShiftSetting
from tblShiftSetting where (ISNULL(AuditShiftType,0) <> 1 and ShiftID >1
 ) and WeekDays>0
 and isnull(IsRecognition,1 )=1
 and DATEPART(hh,WorkStart) <> DATEPART(hh,WorkEnd)
group by ShiftCode,isnull(isOfficalShift,0)
--create clustered index indextblShiftSetting on #tblshiftSetting(ShiftCode)


update #tblShiftSetting set BreakStartMi = 1440+BreakStartMi where BreakStartMi < WorkStartMi and WorkStartMi > WorkEndMi
update #tblShiftSetting set BreakEndMi = 1440+BreakEndMi where BreakEndMi < WorkStartMi and WorkStartMi > WorkEndMi
update #tblShiftSetting set WorkEndMi = 1440+WorkEndMi where WorkEndMi < WorkStartMi
update #tblShiftSetting set OTBeforeStartMi = WorkStartMi where OTBeforeStartMi is null
update #tblShiftSetting set OTBeforeStartMi = 1440+OTBeforeStartMi where OTBeforeStartMi < WorkStartMi
update #tblShiftSetting set OTBeforeEndMi = WorkStartMi + 960 where OTBeforeEndMi is null
update #tblShiftSetting set OTBeforeEndMi = 1440+OTBeforeEndMi where OTBeforeEndMi < OTBeforeStartMi

update #tblShiftSetting set OTAfterStartMi = WorkEndMi where OTAfterStartMi is null
update #tblShiftSetting set OTAfterStartMi = 1440+OTAfterStartMi where OTAfterStartMi < WorkEndMi

update #tblShiftSetting set OTAfterEndMi = WorkEndMi + 960 where OTAfterEndMi is null
update #tblShiftSetting set OTAfterEndMi = 1440+OTAfterEndMi where OTAfterEndMi < OTAfterStartMi
update #tblShiftSetting set BreakStartMi = WorkEndMi where BreakStartMi is null or BreakStartMi > WorkEndMi or BreakStartMi<WorkStartMi
update #tblShiftSetting set BreakEndMi = WorkEndMi where BreakEndMi is null or BreakEndMi > WorkEndMi or BreakEndMi < WorkStartMi
update #tblShiftSetting set BreakEndMi = 1440+BreakEndMi where BreakEndMi < BreakStartMi
update #tblShiftSetting set ShiftHours = (WorkEndMi - WorkStartMi - (BreakEndMi - BreakStartMi))/60.0
update #tblShiftSetting set STDWorkingTime_SS = (WorkEndMi - WorkStartMi - (BreakEndMi - BreakStartMi)) where isnull(STDWorkingTime_SS,0) <= 120

update #tblShiftSetting set isNightShift = case when WorkEndMi>1440 then 1 else 0 end
update #tblShiftSetting set WorkStartStatisticMi = WorkStartMi,WorkEndStatisticMi = WorkEndMi
,STDWorkingTime_SS = case when STDWorkingTime_SS is null then WorkEndMi - WorkStartMi - (BreakEndMi - BreakStartMi)
else STDWorkingTime_SS end

update d set ShiftID = s.ShiftID
from #tblShiftSetting d
inner join tblShiftSetting s on d.ShiftCode = s.ShiftCode
where d.ShiftID = 0 and s.ShiftID is not null and DATEPART(hh,s.WorkStart) <> DATEPART(hh,s.WorkEnd)
update #tblShiftSetting set STDWorkingTime_SS = 480 where STDWorkingTime_SS <= 0
-------------- get parameters---------------------------------
declare @TA_TIMEINBEFORE float, @TA_INOUT_MINIMUM float,@TA_TIMEOUTAFTER float,@TA_IO_SWIPE_OPTION int, @WORK_HOURS float, @MATERNITY_MUNITE int,@LEAVEFULLDAYSTILLHASATTTIME int,@MATERNITY_ADD_ATLEAST float, @SHIFTDETECTOR_LATE_PERMIT int,@SHIFTDETECTOR_EARLY_PERMIT int, @SHIFTDETECTOR_IN_EARLY_USUALLY int
,@IgnoreTimeOut_ShiftDetector bit = 0,@StatisticShiftPerweek_ShiftDetector int = 330,@WrongShiftProcess_ShiftDetector bit = 1
select @TA_TIMEINBEFORE= CAST(Value as float) from tblParameter where Code = 'TA_TIMEINBEFORE'
select @TA_INOUT_MINIMUM= CAST(Value as float) from tblParameter where Code = 'TA_INOUT_MINIMUM'
select @TA_TIMEOUTAFTER= CAST(Value as float) from tblParameter where Code = 'TA_TIMEOUTAFTER'
select @MATERNITY_MUNITE= CAST(Value as float) from tblParameter where Code = 'MATERNITY_MUNITE'
select @WORK_HOURS= CAST(Value as float) from tblParameter where Code = 'WORK_HOURS'
select @LEAVEFULLDAYSTILLHASATTTIME= CAST(Value as int) from tblParameter where Code = 'LEAVEFULLDAYALSOHASOVERTIME'
select @MATERNITY_ADD_ATLEAST = CAST(Value as float) from tblParameter where Code = 'MATERNITY_ADD_ATLEAST'
select @IgnoreTimeOut_ShiftDetector = CAST(Value as bit) from tblParameter where Code = 'IgnoreTimeOut_ShiftDetector'
select @WrongShiftProcess_ShiftDetector = CAST(Value as bit) from tblParameter where Code = 'WrongShiftProcess_ShiftDetector'
select @StatisticShiftPerweek_ShiftDetector = CAST(Value as int) from tblParameter where Code = 'StatisticShiftPerweek_ShiftDetector'

SET @SHIFTDETECTOR_IN_EARLY_USUALLY= ISNULL((select CAST(Value as int) from tblParameter where Code = 'SHIFTDETECTOR_IN_EARLY_USUALLY'),0)
SET @SHIFTDETECTOR_LATE_PERMIT= ISNULL((select CAST(Value as int) from tblParameter where Code = 'SHIFTDETECTOR_LATE_PERMIT'),0)
SET @SHIFTDETECTOR_EARLY_PERMIT= ISNULL((select CAST(Value as int) from tblParameter where Code = 'SHIFTDETECTOR_EARLY_PERMIT'),0)

-- Option 0: xoa gio vao ra neu co nghi ca ngay
-- Option 1: xoa nghi ca ngay neu co gio vao ra
-- Option 2: Xóa gio vao ra neu nghi ca ngày và workingtimeMi < 120
-- Option 3: Xóa xoa nghi ca ngay neu gio vào ra và WorkingTimeMi > 240
-- Option 4: Vẫn giữ giờ công và leave
set @LEAVEFULLDAYSTILLHASATTTIME = ISNULL(@LEAVEFULLDAYSTILLHASATTTIME,0)

set @TA_TIMEINBEFORE = ISNULL(@TA_TIMEINBEFORE,5)
set @TA_INOUT_MINIMUM = ISNULL(@TA_INOUT_MINIMUM,60)
set @TA_TIMEOUTAFTER = ISNULL(@TA_TIMEOUTAFTER,18)
set @MATERNITY_MUNITE = isnull(@MATERNITY_MUNITE,60)
SET @MATERNITY_ADD_ATLEAST = ISNULL(@MATERNITY_ADD_ATLEAST,400)
-- d?i @TA_TIMEINBEFORE ra phút
set @TA_TIMEINBEFORE = @TA_TIMEINBEFORE*60
/*
0 Bam tu do
1 Vào làm bam cong, ve bam cong
2 Bam gio 2 lan dau ca cuoi ca, tang ca bam rieng
3 Sang bam, trua bam chieu bam va tang ca bam cong
*/
update #tblShiftSetting set SwipeOptionID = 2 where SwipeOptionID = 3 and BreakStartMi = WorkEndMi

-- working schedule
select s.EmployeeID,ss.ShiftCode,isnull(ss.ShiftID,s.ShiftID) ShiftID, s.ScheduleDate, s.HolidayStatus, s.DateStatus, isnull(s.Approved,0) as Approved
,dateadd(day,1,Scheduledate) as NextDate
,dateadd(day,-1,Scheduledate) as PrevDate
,ApprovedHolidayStatus
into #tblWSchedule
from tblWSchedule s
INNER JOIN #tblEmployeeList te ON te.EmployeeID = s.EmployeeID
left join tblShiftSetting ss on s.ShiftID = ss.ShiftID
where s.ScheduleDate between @FromDate3 and @ToDate3


CREATE TABLE #tblHasTA(EmployeeID nvarchar(20) null,Attdate datetime null,[Period] int null,AttStart datetime null,AttMiddle datetime null,AttEnd datetime null,WorkingTime float null,TAStatus int null,WorkStart datetime null,WorkEnd datetime null,IsNightShift bit null,ShiftCode nvarchar(20) null,NextDate datetime null,PrevDate datetime null)

CREATE CLUSTERED INDEX ix_HasTA ON #tblHasTA (EmployeeID,Attdate,Period)

CREATE TABLE #tblHasTA_Fixed(EmployeeID nvarchar(20) null,Attdate datetime null,[Period]int null,AttStart datetime null,AttMiddle datetime null,AttEnd datetime null,WorkingTime float null,TAStatus int null,WorkStart datetime null,WorkEnd datetime null,IsNightShift bit null,ShiftCode nvarchar(20) null,NextDate datetime null,PrevDate datetime null)

CREATE CLUSTERED INDEX ix_HasTA_Fixed ON #tblHasTA_Fixed(EmployeeID,Attdate,Period)

insert into #tblHasTA(EmployeeID,AttDate,[Period]
, AttStart
,AttMiddle
,AttEnd
,WorkingTime
,TAStatus
--,IsNightShift,ShiftCode
,NextDate,PrevDate)
select t.EmployeeID,t.AttDate,t.[Period]
,case when isnull(e.NotCheckTA,0) = 0  or isnull(TAStatus,0)>0 then  t.AttStart else null  end as AttStart
,t.AttMiddle
,case when isnull(e.NotCheckTA,0) = 0  or isnull(TAStatus,0)>0 then  t.AttEnd else null  end
as AttEnd
,t.WorkingTime,t.TAStatus
--,ss1.isNightShift,ss.ShiftCode
,dateadd(day,1,AttDate) NextDate,dateadd(day,-1,AttDate) PrevDate
from tblHasTA t
inner join #tblWSchedule ws on t.AttDate = ws.ScheduleDate and t.EmployeeID = ws.EmployeeID
inner join #tblEmployeeList e on t.EmployeeID= e.EmployeeID
where t.AttDate between @FromDate3 and @ToDate3


-- chua hieu ly do gi phai tach ra de update Shiftcode, nhung tach ra thi performance tang rat nhieu
 update t set t.ShiftCode = ss.ShiftCode, t.IsNightShift = ss1.isNightShift from #tblHasTA t
 inner join #tblWSchedule ws on t.AttDate = ws.ScheduleDate and t.EmployeeID = ws.EmployeeID
 join tblShiftSetting ss on ws.ShiftID = ss.ShiftID
 join #tblShiftSetting ss1 on ss.ShiftCode = ss1.ShiftCode
update ta1 set TAStatus = 3
from #tblHasTA ta1
where not exists(select 1 from #tblPendingImportAttend ta2 where ta1.EmployeeID = ta2.EmployeeID and ta1.Attdate = ta2.Date)



-- AttEnd Time, AttState: 1 in, 2 Out, 0 dùng chung
-- dedecator signal separate In-Out or not
declare @IN_OUT_TA_SEPARATE bit
set @IN_OUT_TA_SEPARATE = (select case when Value ='1' then 1 else 0 end from tblParameter where Code = 'IN_OUT_TA_SEPARATE')
SET @IN_OUT_TA_SEPARATE = ISNULL(@IN_OUT_TA_SEPARATE,0)

select AttTime,@IN_OUT_TA_SEPARATE*t.AttState AttState,t.EmployeeID,t.MachineNo,t.sn
into #tblTmpAttendAndHasTA from tblTmpAttend t
where isnull(t.sn,'') not in (select ISNULL(SN,'9999999') SN from Machines where isnull(MealMachine,0) = 1) and
t.AttTime between @FromDate3 and @ToDate3
and exists (select 1 from #tblEmployeeList e where e.EMployeeID =  t.EmployeeID )
union
select AttStart, 1, EmployeeID,1,null from #tblHasTA where TAStatus = 1
union
select AttEnd, 2, EmployeeID,2,null from #tblHasTA where TAStatus = 2

declare @RemoveDuplicateAttTime_Interval int
select  @RemoveDuplicateAttTime_Interval = value from tblParameter where Code = 'RemoveDuplicateAttTime_Interval'
set @RemoveDuplicateAttTime_Interval = ISNULL(@RemoveDuplicateAttTime_Interval,120)

select distinct cast(cast(t.AttTime as datetime2(0)) as datetime) as AttTime -- cat phan milisecond
 ,AttState
 ,t.EmployeeID
 ,t.MachineNo
 ,DATEADD(SECOND,1,AttTime) as atttime1,DATEADD(SECOND,@RemoveDuplicateAttTime_Interval,AttTime) as atttime120
 ,DATEADD(SECOND,-1,AttTime) as atttimeM1,DATEADD(SECOND,0-@RemoveDuplicateAttTime_Interval,AttTime) as atttimeM120
 ,cast(isnull(m.InOutStatus,t.AttState)*@IN_OUT_TA_SEPARATE as bit) as ForceState --wtc: may o F2 phan biet in/out, neu du lieu import excel vao thi de 'Dung chung'
into #tblTmpAttend
from #tblTmpAttendAndHasTA t
left join Machines m on t.sn = m.sn

 drop table #tblTmpAttendAndHasTA
if(OBJECT_ID('sp_ShiftDetector_SetForceStateTotblTmpAttend' )is null)
begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_SetForceStateTotblTmpAttend
(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUpdate = 0
exec sp_ShiftDetector_SetForceStateTotblTmpAttend @StopUpdate output ,@LoginID,@FromDate,@ToDate



select * into #tblTmpAttend_Org from #tblTmpAttend
-- XOA, LOAI BO NHUNG RECORD BAM NHIEU LAN LIEN TIEP

if ROWCOUNT_BIG() >0
begin
 if @IN_OUT_TA_SEPARATE = 1
 begin
  DELETE B FROM #tblTmpAttend a
   cross apply #tblTmpAttend b where a.EmployeeID = b.EmployeeID and B.AttTime between a.atttimeM1 and a.atttimeM120
   and a.AttState = b.AttState
 end
 DELETE B FROM #tblTmpAttend a
  cross apply #tblTmpAttend b where a.EmployeeID = b.EmployeeID and B.AttTime between a.atttime1 and a.atttime120
  and a.AttState = b.AttState
end
 --create clustered index indextblTmpAttendtmp on #tblTmpAttend(EmployeeID,AttTime,AttState)


-- assign shift group for employee or department


select * into #tblShiftGroup_Shift
from tblShiftGroup_Shift sg
where exists (select 1 from #tblShiftsetting ss where ss.ShiftCode = sg.ShiftCode)

-- get history of change department
CREATE TABLE #tblDivDepSecPos(STT int, EmployeeID varchar(20),DivisionID int,DepartmentID int,SectionID int,GroupID int,EmployeeTypeID int,ChangedDate datetime, EndDate datetime)

-- c?n ki?m soát k? vi?c c?p nh?t thông tin vào b?ng tblDivDepSecPos, ko không s? nh?n d?ng sai.
-- N?u công ty có phát sinh b? ph?n ngh? vi?c và nhét nhân viên vào b? ph?n dó thì ph?i lo?i ra kh?i l?ch s?
insert into #tblDivDepSecPos(EmployeeID, DivisionID,DepartmentID,SectionID,GroupID,EmployeeTypeID,ChangedDate)
select e.EmployeeID, e.DivisionID,isnull(h.DepartmentID,e.DepartmentID),isnull(h.SectionID,e.SectionID),isnull(h.GroupID, e.GroupID),e.EmployeeTypeID,isnull(h.ChangedDate,@FromDate)
from #tblEmployeeList e left join dbo.fn_DivDepSecPos_ByDate(@ToDate) h on e.EmployeeID = h.EmployeeID

insert into #tblDivDepSecPos(EmployeeID, DivisionID,DepartmentID,SectionID,GroupID,ChangedDate)
select his.EmployeeID, his.DivisionID,his.DepartmentID,his.SectionID,his.GroupID,isnull(his.ChangedDate,@FromDate) from dbo.fn_DivDepSecPos_ByDate(@FromDate) his
where exists(select 1 FROM #tblEmployeeList te WHERE his.EmployeeID = te.EmployeeID)
and not exists (select 1 from #tblDivDepSecPos d where d.EmployeeID = his.EmployeeID and d.ChangedDate = his.ChangedDate)


insert into #tblDivDepSecPos(EmployeeID, DivisionID,DepartmentID,SectionID,GroupID,EmployeeTypeID,ChangedDate)
select his.EmployeeID, his.DivisionID,his.DepartmentID,his.SectionID,his.GroupID,his.EmployeeTypeID,isnull(his.ChangedDate,@FromDate)
from tblDivDepSecPos his where ChangedDate between @FromDate and @ToDate
AND EXISTS (select 1 FROM #tblEmployeeList te WHERE his.EmployeeID = te.EmployeeID)
and not exists (select 1 from #tblDivDepSecPos d where d.EmployeeID = his.EmployeeID and d.ChangedDate = his.ChangedDate)


update c set STT = tmp.STT from #tblDivDepSecPos c inner join (
select ROW_NUMBER()Over (PARTITION BY EmployeeID order by EmployeeID, ChangedDate) STT, EmployeeID, ChangedDate from #tblDivDepSecPos
) tmp on c.EmployeeID = tmp.EmployeeID and c.ChangedDate = tmp.ChangedDate
update c1 set EndDate = c2.ChangedDate -1 from #tblDivDepSecPos c1 inner join #tblDivDepSecPos c2 on c1.employeeID = c2.employeeID and c1.Stt = c2.Stt-1 where c1.EndDate is null
update #tblDivDepSecPos set ChangedDate = @FromDate, EndDate = @ToDate where EmployeeID not in (
select EmployeeID from #tblDivDepSecPos where Stt >1
)
update #tblDivDepSecPos set EndDate = @toDate where EndDate is null

CREATE TABLE #tblShiftGroupCode(EmployeeID varchar(20),ShiftGroupCode int, FromDate datetime, ToDate datetime)
insert into #tblShiftGroupCode(EmployeeID,ShiftGroupCode,FromDate,Todate)
select d.EmployeeID, e.ShiftGroupCode
,d.ChangedDate,d.EndDate
from #tblDivDepSecPos d
left join tblShiftGroupByEmployee e on e.EmployeeID = d.EmployeeID where e.ShiftGroupCode is not null

insert into #tblShiftGroupCode(EmployeeID,ShiftGroupCode,FromDate,Todate)
select d.EmployeeID, g.ShiftGroupCode
,d.ChangedDate,d.EndDate
from #tblDivDepSecPos d
left join tblShiftGroupByGroup g on g.GroupID = d.GroupID
where not exists (select 1 from #tblShiftGroupCode t where t.EmployeeID = d.EmployeeID and t.FromDate = d.ChangedDate)
and g.ShiftGroupCode is not null

insert into #tblShiftGroupCode(EmployeeID,ShiftGroupCode,FromDate,Todate)
select d.EmployeeID, s.ShiftGroupCode
,d.ChangedDate,d.EndDate
from #tblDivDepSecPos d
left join tblShiftGroupBySection s on s.SectionID = d.SectionID
where not exists (select 1 from #tblShiftGroupCode t where t.EmployeeID = d.EmployeeID and t.FromDate = d.ChangedDate)
and s.ShiftGroupCode is not null

insert into #tblShiftGroupCode(EmployeeID,ShiftGroupCode,FromDate,Todate)
select d.EmployeeID, de.ShiftGroupCode
,d.ChangedDate,d.EndDate
from #tblDivDepSecPos d
left join tblShiftGroupByDepartment de on de.DepartmentID = d.DepartmentID
where not exists (select 1 from #tblShiftGroupCode t where t.EmployeeID = d.EmployeeID and t.FromDate = d.ChangedDate)
and de.ShiftGroupCode is not null

insert into #tblShiftGroupCode(EmployeeID,ShiftGroupCode,FromDate,Todate)
select d.EmployeeID, de.ShiftGroupCode
,d.ChangedDate,d.EndDate
from #tblDivDepSecPos d
left join tblShiftGroupByDivision de on de.DivisionID = d.DivisionID
where not exists (select 1 from #tblShiftGroupCode t where t.EmployeeID = d.EmployeeID and t.FromDate = d.ChangedDate)
and de.ShiftGroupCode is not null

insert into #tblShiftGroupCode(EmployeeID,ShiftGroupCode,FromDate,Todate)
select EmployeeID,sgs.ShiftGroupID,@FromDate,@ToDate
from #tblEmployeeList e
cross join tblShiftGroup_Shift sgs
where
not exists (select 1 from #tblShiftGroupCode sg where e.EmployeeID = sg.EmployeeID)
--EmployeeID not in(select EmployeeID from #tblShiftGroupCode)


if(OBJECT_ID('sp_ShiftDetector_FinishConfigtblShiftGroupCode' )is null)
begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_FinishConfigtblShiftGroupCode
(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUpdate = 0
exec sp_ShiftDetector_FinishConfigtblShiftGroupCode @StopUpdate output ,@LoginID,@FromDate,@ToDate

if(select COUNT(1) from #tblPendingImportAttend) = 0
 goto FinishedShiftDetector

-- khoa luong, khoa cong roi khong nhan ca nua
--khóa công, theo ngày,tung nguoi
--Luu ý các bác, khóa luong r?i thì không du?c cho m? công nha

if(OBJECT_ID('sp_ShiftDetector_Begin_AttLock' )is null)
begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_Begin_AttLock
(@StopUpdate bit output)
as
begin
 SET NOCOUNT ON;
end')
end
 set @StopUpdate = 0
 exec sp_ShiftDetector_Begin_AttLock @StopUpdate output

if(@StopUpdate = 0)
begin
 --if exists (select 1 from tblAtt_LockMonth where EmployeeID in (select EmployeeID from #tblEmployeeList))
 delete tblAtt_LockMonth where EmployeeID is null
 delete tblAtt_Lock where EmployeeID is null
 update ws set Approved = 1,DateStatus = 3 from #tblWSchedule ws where exists (select 1 from tblAtt_Lock l where ws.EmployeeID = l.EmployeeID and ws.ScheduleDate = l.Date)
 delete ws from #tblPendingImportAttend ws where exists (select 1 from tblAtt_Lock l where ws.EmployeeID = l.EmployeeID and ws.Date = l.Date)
end
 update ta1 set TAStatus = 3
from #tblHasTA ta1
where not exists(select 1 from #tblPendingImportAttend ta2 where ta1.EmployeeID = ta2.EmployeeID and ta1.Attdate = ta2.Date)
declare @DO_NOT_USE_InOutStatistic bit = 0
select @DO_NOT_USE_InOutStatistic =
isnull(cast( value as bit),0) from tblParameter where Code = 'DO_NOT_USE_InOutStatistic'

if(@DO_NOT_USE_InOutStatistic = 0)
BEGIN

 --insert into #tblShiftDetector_InOutStatistic
  select * into #tblShiftDetector_InOutStatistic
  from tblShiftDetector_InOutStatistic s
  where s.CountTime > 1
  and s.EmployeeID is null or s.EmployeeID ='-1'
 union
  select * from tblShiftDetector_InOutStatistic s
  where s.CountTime > 1 and EmployeeID ='DepartmentID' AND
  exists(select distinct 1 from #tblDivDepSecPos d WHERE s.DepartmentID = d.DepartmentID)
 union
  select * from tblShiftDetector_InOutStatistic s
  where s.CountTime > 1 and EmployeeID ='SectionID' AND
  EXISTS(SELECT 1 FROM #tblDivDepSecPos d WHERE s.SectionID = d.SectionID)
 union
select * from tblShiftDetector_InOutStatistic s
  where s.CountTime > 1 and EmployeeID ='EmployeeTYpeID' AND
  EXISTS (select 1 FROM #tblDivDepSecPos d WHERE s.EmployeeTypeID = d.EmployeeTypeID)
 union
  select * from tblShiftDetector_InOutStatistic s
  where s.CountTime > 1 AND
  EXISTS (select 1 FROM #tblEmployeeList te WHERE s.EmployeeID = te.EmployeeID)

 --create clustered index indextblShiftDetector_InOutStatistic  on #tblShiftDetector_InOutStatistic(EmployeeID, DepartmentID,SectionID,CountTime,ismax)
end

-- th?ng kê ca

if(@DO_NOT_USE_InOutStatistic = 0)
begin
 update ss set WorkStartStatisticMi = s.SwipeTimeIn,WorkEndStatisticMi = case when isNightShift = 1 and s.SwipeTimeOut < 1440 then 1440 + s.SwipeTimeOut else s.SwipeTimeOut end
 from #tblShiftSetting ss
 inner join (select s.ShiftCode,s.SwipeTimeIn,s.SwipeTimeOut from #tblShiftDetector_InOutStatistic s
 where ismax = 1 and EmployeeID is null) s on s.ShiftCode = ss.ShiftCode
end



-------------detector shift code----------------------------
create table #tblShiftDetector (
EmployeeId varchar(20) null,
ScheduleDate datetime null,
ShiftCode varchar(20) null,
RatioMatch int null,
InInterval int null,
OutInterval int null,
InIntervalS int null,
OutIntervalS int null,
InIntervalE int null,
OutIntervalE int null,
AttStart datetime null,
AttEnd datetime null,
WorkingTimeMi int null,
StdWorkingTimeMi int null,
Late_Permit int null,
Early_Permit int null,
AttStartMi int null,
AttEndMi int null,
ShiftID int null,
WorkStart datetime null,
WorkEnd datetime null,
WorkStartMi int null,
WorkEndMi int null,
BreakStartMi int null,
BreakEndMi int null,
WorkStartSMi int null,
WorkEndSMi int null,
WorkStartEMi int null,
WorkEndEMi int null,
BreakStart datetime null,
BreakEnd datetime null,
OTBeforeStart datetime null,
OTBeforeEnd datetime null,
OTAfterStart datetime null,
OTAfterEnd datetime null,
AttEndYesterday datetime null,
AttStartTomorrow datetime null,
AttEndYesterdayFixed bit null,
AttStartTomorrowFixed bit null,

AttEndYesterdayFixedTblHasta bit null,
AttStartTomorrowFixedTblHasta bit null,

isNightShift bit null,
isNightShiftYesterday bit null,
ShiftCodeYesterday varchar(20) null,
isOfficalShift bit null,
HolidayStatus int null,
FixedAtt bit null,
TIMEINBEFORE datetime null,
INOUT_MINIMUM float null,
TIMEOUTAFTER datetime null,
isWrongShift bit null,
Approved bit null,
IsLeaveStatus3 bit null,
StateIn int null, -- is Correct In [1]
StateOut int null, -- is Correct Out [2]
EmployeeStatusID int null
)



if(OBJECT_ID('sp_ShiftDetector_AdditionColumn' )is null)
begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_AdditionColumn
(@StopUpdate bit output)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUpdate = 0
 exec sp_ShiftDetector_AdditionColumn @StopUpdate output

select EmployeeId,ShiftCode,ScheduleDate,AttStart,AttEnd,isNightShift,HolidayStatus,cast(null as datetime) as Prevdate,cast(null as datetime) as NextDate,IsLeaveStatus3
into #tblPrevMatch from #tblShiftDetector
where 1=0
--create clustered index indextblPrevMatch on #tblPrevMatch(EmployeeID,PrevDate,NextDate)

create table #tblPrevRemove(EmployeeId nvarchar(20) null, ScheduleDate datetime null,ShiftCode nvarchar(20) null)

create table #tblShiftDetectorReprocess (
STT int null,
EmployeeId varchar(20) null,
ScheduleDate datetime null,
ShiftCode varchar(20) null,
WorkStart datetime null,
WorkEnd datetime null,
AttEndYesterday datetime null,
AttStartTomorrow datetime null
)
select * into #tblShiftDetectorMatched
from #tblShiftDetector where 1=0



insert into #tblShiftDetectorMatched(EmployeeId,ScheduleDate,EmployeeStatusID)
select distinct pe.EmployeeID,pe.[Date],pe.EmployeeStatusID
from #tblPendingImportAttend pe
inner join #tblEmployeeList e on pe.EmployeeID = e.EmployeeID

/*
Xu ly nhung nhan vien di lam 2 ca 1 ngay
1. Đi ca 1 + ca 3
2. Đi Ca 1 + Ca 2
3. Đi Ca 2+ Ca 3
4. Đi HC + Ca 3
*/






create table #tblWorking2ShiftADay_Detect(
EmployeeID varchar(20),
ScheduleDate datetime,
ShiftCode1 varchar(20),
AttStart1 datetime,
AttEnd1 datetime,
WorkStartMi1 int,
WorkEndMi1 int,
AttTimeStart1Min datetime,
AttTimeStart1Max datetime,
AttTimeEnd1Min datetime,
AttTimeEnd1Max datetime,
ShiftCode2 varchar(20),
AttStart2 datetime,
AttEnd2 datetime,
WorkStartMi2 int,
WorkEndMi2 int,
AttTimeStart2Min datetime,
AttTimeStart2Max datetime,
AttTimeEnd2Min datetime,
AttTimeEnd2Max datetime,
WorkingStyleId int, --1. Đi ca 1 + ca 3, 2. Đi Ca 1 + Ca 2, 3. Đi Ca 2+ Ca 3, 4. Đi HC + Ca 3
)
if(OBJECT_ID('sp_ShiftDetector_Working2ShiftADay_Detect' )is null)
begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_Working2ShiftADay_Detect
(@StopUpdate bit output)
as
begin
 SET NOCOUNT ON;
end')
end
 set @StopUpdate = 0
 exec sp_ShiftDetector_Working2ShiftADay_Detect @StopUpdate output



if @StopUpdate = 0
begin

insert into #tblShiftDetector(EmployeeID,ScheduleDate,ShiftCode,HolidayStatus,RatioMatch,EmployeeStatusID)
select c.EmployeeID,s.ScheduleDate,sg.ShiftCode,s.HolidayStatus,0,EmployeeStatusID
from #tblShiftDetectorMatched s
inner join #tblShiftGroupCode c on s.EmployeeId = c.EmployeeID
full outer join #tblShiftGroup_Shift sg on c.ShiftGroupCode = sg.ShiftGroupID
where sg.ShiftCode is not null and s.EmployeeId is not null
and s.ScheduleDate between c.FromDate and c.ToDate
and exists (select 1 from #tblEmployeeList te where s.employeeID = te.EmployeeID and te.Working2ShiftADay = 1)



insert into #tblShiftDetector(EmployeeID,ScheduleDate,ShiftCode,HolidayStatus,RatioMatch,EmployeeStatusID)
select s.EmployeeID,s.ScheduleDate,ss.ShiftCode,s.HolidayStatus,0,EmployeeStatusID
from #tblShiftDetectorMatched s
cross join
(select distinct ShiftCode from #tblShiftSetting) ss
where not exists(select 1 from #tblShiftDetector sd where s.EmployeeId = sd.EmployeeID and s.Scheduledate = sd.Scheduledate)
-- cap ca 1, Ca 3
insert into #tblWorking2ShiftADay_Detect(EmployeeId,ScheduleDate,WorkingStyleID,
ShiftCode1,WorkStartMi1,WorkEndMi1,AttTimeStart1Min,AttTimeStart1Max,AttTimeEnd1Min,AttTimeEnd1Max,	
ShiftCode2,WorkStartMi2,WorkEndMi2,AttTimeStart2Min,AttTimeStart2Max,AttTimeEnd2Min,AttTimeEnd2Max
)
select d1.EmployeeId,d1.ScheduleDate,1 as WorkingStyleID
,s1.ShiftCode ShiftCode1,s1.WorkStartMi,s1.WorkEndMi,DATEADD(mi,s1.WorkStartMi-60,d1.ScheduleDate) AttTimeStart1Min,DATEADD(mi,s1.WorkStartMi+60,d1.ScheduleDate) AttTimeStart1Max,DATEADD(mi,s1.WorkEndMi-60,d1.ScheduleDate) AttTimeEnd1Min,DATEADD(mi,s1.WorkEndMi+60,d2.ScheduleDate) AttTimeEnd1Max
,s2.ShiftCode ShiftCode2,s2.WorkStartMi,s2.WorkEndMi,DATEADD(mi,s2.WorkStartMi-60,d2.ScheduleDate) AttTimeStart2Min,DATEADD(mi,s2.WorkStartMi+60,d2.ScheduleDate) AttTimeStart2Max,DATEADD(mi,s2.WorkEndMi-60,d2.ScheduleDate) AttTimeEnd2Min,DATEADD(mi,s2.WorkEndMi+60,d2.ScheduleDate) AttTimeEnd2Max
from #tblShiftDetector d1 inner join #tblShiftSetting s1 on d1.ShiftCode = s1.ShiftCode
inner join #tblShiftDetector d2 on d1.EmployeeId = d2.EmployeeId and d1.ScheduleDate = d2.ScheduleDate  inner join #tblShiftSetting s2 on d2.ShiftCode = s2.ShiftCode
where s1.WorkStartMi between 300 and 420 and s2.WorkStartMi between 1260 and 1380
and exists (select 1 from #tblEmployeeList te where d1.EmployeeId = te.EmployeeID and Working2ShiftADay = 1)
-- cap ca 1, ca 2
insert into #tblWorking2ShiftADay_Detect(EmployeeId,ScheduleDate,WorkingStyleID,
ShiftCode1,WorkStartMi1,WorkEndMi1,AttTimeStart1Min,AttTimeStart1Max,AttTimeEnd1Min,AttTimeEnd1Max,	
ShiftCode2,WorkStartMi2,WorkEndMi2,AttTimeStart2Min,AttTimeStart2Max,AttTimeEnd2Min,AttTimeEnd2Max
)
select d1.EmployeeId,d1.ScheduleDate,2 as WorkingStyleID
,s1.ShiftCode ShiftCode1,s1.WorkStartMi,s1.WorkEndMi,DATEADD(mi,s1.WorkStartMi-60,d1.ScheduleDate) AttTimeStart1Min,DATEADD(mi,s1.WorkStartMi+60,d1.ScheduleDate) AttTimeStart1Max,DATEADD(mi,s1.WorkEndMi-60,d1.ScheduleDate) AttTimeEnd1Min,DATEADD(mi,s1.WorkEndMi+60,d2.ScheduleDate) AttTimeEnd1Max
,s2.ShiftCode ShiftCode2,s2.WorkStartMi,s2.WorkEndMi,DATEADD(mi,s2.WorkStartMi-60,d2.ScheduleDate) AttTimeStart2Min,DATEADD(mi,s2.WorkStartMi+60,d2.ScheduleDate) AttTimeStart2Max,DATEADD(mi,s2.WorkEndMi-60,d2.ScheduleDate) AttTimeEnd2Min,DATEADD(mi,s2.WorkEndMi+60,d2.ScheduleDate) AttTimeEnd2Max
from #tblShiftDetector d1 inner join #tblShiftSetting s1 on d1.ShiftCode = s1.ShiftCode
inner join #tblShiftDetector d2 on d1.EmployeeId = d2.EmployeeId and d1.ScheduleDate = d2.ScheduleDate  inner join #tblShiftSetting s2 on d2.ShiftCode = s2.ShiftCode
where s1.WorkStartMi between 300 and 420 and s2.WorkStartMi between 780 and 900
and exists (select 1 from #tblEmployeeList te where d1.EmployeeId = te.EmployeeID and Working2ShiftADay = 1)
-- cap ca 2, ca 3
insert into #tblWorking2ShiftADay_Detect(EmployeeId,ScheduleDate,WorkingStyleID,
ShiftCode1,WorkStartMi1,WorkEndMi1,AttTimeStart1Min,AttTimeStart1Max,AttTimeEnd1Min,AttTimeEnd1Max,	
ShiftCode2,WorkStartMi2,WorkEndMi2,AttTimeStart2Min,AttTimeStart2Max,AttTimeEnd2Min,AttTimeEnd2Max
)
select d1.EmployeeId,d1.ScheduleDate,3 as WorkingStyleID
,s1.ShiftCode ShiftCode1,s1.WorkStartMi,s1.WorkEndMi,DATEADD(mi,s1.WorkStartMi-60,d1.ScheduleDate) AttTimeStart1Min,DATEADD(mi,s1.WorkStartMi+60,d1.ScheduleDate) AttTimeStart1Max,DATEADD(mi,s1.WorkEndMi-60,d1.ScheduleDate) AttTimeEnd1Min,DATEADD(mi,s1.WorkEndMi+60,d2.ScheduleDate) AttTimeEnd1Max
,s2.ShiftCode ShiftCode2,s2.WorkStartMi,s2.WorkEndMi,DATEADD(mi,s2.WorkStartMi-60,d2.ScheduleDate) AttTimeStart2Min,DATEADD(mi,s2.WorkStartMi+60,d2.ScheduleDate) AttTimeStart2Max,DATEADD(mi,s2.WorkEndMi-60,d2.ScheduleDate) AttTimeEnd2Min,DATEADD(mi,s2.WorkEndMi+60,d2.ScheduleDate) AttTimeEnd2Max
from #tblShiftDetector d1 inner join #tblShiftSetting s1 on d1.ShiftCode = s1.ShiftCode
inner join #tblShiftDetector d2 on d1.EmployeeId = d2.EmployeeId and d1.ScheduleDate = d2.ScheduleDate  inner join #tblShiftSetting s2 on d2.ShiftCode = s2.ShiftCode
where s1.WorkStartMi between 780 and 900 and s2.WorkStartMi between 1260 and 1380
and exists (select 1 from #tblEmployeeList te where d1.EmployeeId = te.EmployeeID and Working2ShiftADay = 1)
-- cap HC, Ca3
insert into #tblWorking2ShiftADay_Detect(EmployeeId,ScheduleDate,WorkingStyleID,
ShiftCode1,WorkStartMi1,WorkEndMi1,AttTimeStart1Min,AttTimeStart1Max,AttTimeEnd1Min,AttTimeEnd1Max,	
ShiftCode2,WorkStartMi2,WorkEndMi2,AttTimeStart2Min,AttTimeStart2Max,AttTimeEnd2Min,AttTimeEnd2Max
)
select d1.EmployeeId,d1.ScheduleDate,4 as WorkingStyleID
,s1.ShiftCode ShiftCode1,s1.WorkStartMi,s1.WorkEndMi,DATEADD(mi,s1.WorkStartMi-60,d1.ScheduleDate) AttTimeStart1Min,DATEADD(mi,s1.WorkStartMi+60,d1.ScheduleDate) AttTimeStart1Max,DATEADD(mi,s1.WorkEndMi-60,d1.ScheduleDate) AttTimeEnd1Min,DATEADD(mi,s1.WorkEndMi+60,d2.ScheduleDate) AttTimeEnd1Max
,s2.ShiftCode ShiftCode2,s2.WorkStartMi,s2.WorkEndMi,DATEADD(mi,s2.WorkStartMi-60,d2.ScheduleDate) AttTimeStart2Min,DATEADD(mi,s2.WorkStartMi+60,d2.ScheduleDate) AttTimeStart2Max,DATEADD(mi,s2.WorkEndMi-60,d2.ScheduleDate) AttTimeEnd2Min,DATEADD(mi,s2.WorkEndMi+60,d2.ScheduleDate) AttTimeEnd2Max
from #tblShiftDetector d1 inner join #tblShiftSetting s1 on d1.ShiftCode = s1.ShiftCode
inner join #tblShiftDetector d2 on d1.EmployeeId = d2.EmployeeId and d1.ScheduleDate = d2.ScheduleDate  inner join #tblShiftSetting s2 on d2.ShiftCode = s2.ShiftCode
where s1.WorkStartMi between 421 and 540 and s2.WorkStartMi between 1260 and 1380
and exists (select 1 from #tblEmployeeList te where d1.EmployeeId = te.EmployeeID and Working2ShiftADay = 1)
truncate table #tblShiftDetector
-- neu biet chac ca dau la ca nao thi luoc bo du lieu cho nhe
delete s from #tblWorking2ShiftADay_Detect s where exists (
select 1 from #tblWorking2ShiftADay_Detect d where exists (select 1 from #tblWSchedule ws where ws.Approved = 1 and d.EmployeeID = ws.EmployeeID and d.ScheduleDate = ws.ScheduleDate and d.ShiftCode1 = ws.ShiftCode)
and s.EmployeeID = d.EmployeeID and s.ScheduleDate = d.ScheduleDate and d.ShiftCode1 <> s.ShiftCode1
)
-- neu hom sau biet chac di ca 1 thi loai bo nhung cap ca sau la ca 3
delete s from #tblWorking2ShiftADay_Detect s where exists (
select 1 from #tblWorking2ShiftADay_Detect d where exists (select 1 from #tblWSchedule ws where ws.Approved = 1 and d.EmployeeID = ws.EmployeeID and d.ScheduleDate = ws.ScheduleDate and d.ShiftCode1 = ws.ShiftCode and d.WorkStartMi1 < 421)
and s.EmployeeID = d.EmployeeID and s.ScheduleDate = d.ScheduleDate - 1 and abs(d.WorkStartMi1 + 1440 - s.WorkEndMi2) < 30
)
-- neu biet chac hom do di ca 3 thi khong co chuyen lam chong ca

-- AttStart1
update #tblWorking2ShiftADay_Detect set AttStart1 = t.AttTime
from #tblWorking2ShiftADay_Detect  d inner join (
select max(att.AttTime) AttTime, d.employeeID, d.ScheduleDate,d.ShiftCode1,d.ShiftCode2 from #tblWorking2ShiftADay_Detect d
inner join #tblTmpAttend att on d.EmployeeID = att.EmployeeID and att.AttTime between d.AttTimeStart1Min and dateadd(mi,d.WorkStartMi1, d.ScheduleDate)
group by d.employeeID, d.ScheduleDate ,d.ShiftCode1,d.ShiftCode2
) t on d.EmployeeID = t.EmployeeID and d.ScheduleDate = t.ScheduleDate and d.ShiftCode1 = t.ShiftCode1 and d.ShiftCode2 = t.ShiftCode2

update #tblWorking2ShiftADay_Detect set AttStart1 = t.AttTime from #tblWorking2ShiftADay_Detect  d inner join (
select Min(att.AttTime) AttTime, d.employeeID, d.ScheduleDate,d.ShiftCode1,d.ShiftCode2 from #tblWorking2ShiftADay_Detect d
inner join #tblTmpAttend att on d.EmployeeID = att.EmployeeID and att.AttTime between dateadd(mi,d.WorkStartMi1, d.ScheduleDate) and d.AttTimeStart1Max
where d.AttStart1 is null
group by d.employeeID, d.ScheduleDate ,d.ShiftCode1,d.ShiftCode2
) t on d.EmployeeID = t.EmployeeID and d.ScheduleDate = t.ScheduleDate and d.ShiftCode1 = t.ShiftCode1 and d.ShiftCode2 = t.ShiftCode2



-- doi di lam an xa
update #tblWorking2ShiftADay_Detect set AttStart1 = t.AttTime from #tblWorking2ShiftADay_Detect  d inner join (
select Min(att.AttTime) AttTime, d.employeeID, d.ScheduleDate,d.ShiftCode1,d.ShiftCode2 from #tblWorking2ShiftADay_Detect d
inner join #tblTmpAttend att on d.EmployeeID = att.EmployeeID and abs(datediff(mi ,d.ScheduleDate,att.AttTime)-d.WorkStartMi1) < 241
where d.AttStart1 is null
group by d.employeeID, d.ScheduleDate ,d.ShiftCode1,d.ShiftCode2
) t on d.EmployeeID = t.EmployeeID and d.ScheduleDate = t.ScheduleDate and d.ShiftCode1 = t.ShiftCode1 and d.ShiftCode2 = t.ShiftCode2


-- AttEnd1
update #tblWorking2ShiftADay_Detect set AttEnd1 = t.AttTime from #tblWorking2ShiftADay_Detect  d inner join (
select Min(att.AttTime) AttTime, d.employeeID, d.ScheduleDate,d.ShiftCode1,d.ShiftCode2 from #tblWorking2ShiftADay_Detect d
inner join #tblTmpAttend att on d.EmployeeID = att.EmployeeID and att.AttTime between dateadd(mi,d.WorkEndMi1, d.ScheduleDate) and d.AttTimeEnd1Max
where d.WorkingStyleId = 1 -- chi trường hợp cặp ca 1, ca 3 mới tách Min max
group by d.employeeID, d.ScheduleDate ,d.ShiftCode1,d.ShiftCode2
) t on d.EmployeeID = t.EmployeeID and d.ScheduleDate = t.ScheduleDate and d.ShiftCode1 = t.ShiftCode1 and d.ShiftCode2 = t.ShiftCode2

update #tblWorking2ShiftADay_Detect set AttEnd1 = t.AttTime
from #tblWorking2ShiftADay_Detect  d inner join (
select max(att.AttTime) AttTime, d.employeeID, d.ScheduleDate,d.ShiftCode1,d.ShiftCode2 from #tblWorking2ShiftADay_Detect d
inner join #tblTmpAttend att on d.EmployeeID = att.EmployeeID and att.AttTime > d.AttStart1 and att.AttTime between d.AttTimeEnd1Min and dateadd(mi,d.WorkEndMi1, d.ScheduleDate)
where d.AttEnd1 is null and d.WorkingStyleId = 1 -- chi trường hợp cặp ca 1, ca 3 mới tách Min max
group by d.employeeID, d.ScheduleDate ,d.ShiftCode1,d.ShiftCode2
) t on d.EmployeeID = t.EmployeeID and d.ScheduleDate = t.ScheduleDate and d.ShiftCode1 = t.ShiftCode1 and d.ShiftCode2 = t.ShiftCode2

update #tblWorking2ShiftADay_Detect set AttEnd1 = t.AttTime
from #tblWorking2ShiftADay_Detect  d inner join (
select min(att.AttTime) AttTime, d.employeeID, d.ScheduleDate,d.ShiftCode1,d.ShiftCode2 from #tblWorking2ShiftADay_Detect d
inner join #tblTmpAttend att on d.EmployeeID = att.EmployeeID and att.AttTime > d.AttStart1 and att.AttTime between d.AttTimeEnd1Min and d.AttTimeEnd1Max
where d.AttEnd1 is null -- truong hop con lai lay min, de thang con lai cho cap sau
group by d.employeeID, d.ScheduleDate ,d.ShiftCode1,d.ShiftCode2
) t on d.EmployeeID = t.EmployeeID and d.ScheduleDate = t.ScheduleDate and d.ShiftCode1 = t.ShiftCode1 and d.ShiftCode2 = t.ShiftCode2



-- đói đi làm ăn xa
update #tblWorking2ShiftADay_Detect set AttEnd1 = t.AttTime
from #tblWorking2ShiftADay_Detect  d inner join (
select min(att.AttTime) AttTime, d.employeeID, d.ScheduleDate,d.ShiftCode1,d.ShiftCode2 from #tblWorking2ShiftADay_Detect d
inner join #tblTmpAttend att on d.EmployeeID = att.EmployeeID and att.AttTime > d.AttEnd1 and abs(datediff(mi ,d.ScheduleDate,att.AttTime)-d.WorkEndMi1) < 241
where d.AttEnd1 is null -- truong hop con lai lay min, de thang con lai cho cap sau
and not exists (select 1 from #tblWorking2ShiftADay_Detect w where d.EmployeeID = w.EmployeeID and d.ScheduleDate = w.ScheduleDate and w.AttStart1 is not null and w.AttEnd1 is not null)
group by d.employeeID, d.ScheduleDate ,d.ShiftCode1,d.ShiftCode2
) t on d.EmployeeID = t.EmployeeID and d.ScheduleDate = t.ScheduleDate and d.ShiftCode1 = t.ShiftCode1 and d.ShiftCode2 = t.ShiftCode2


-- AttStart2
update #tblWorking2ShiftADay_Detect set AttStart2 = t.AttTime
from #tblWorking2ShiftADay_Detect  d inner join (
select max(att.AttTime) AttTime, d.employeeID, d.ScheduleDate,d.ShiftCode1,d.ShiftCode2 from #tblWorking2ShiftADay_Detect d
inner join #tblTmpAttend att on d.EmployeeID = att.EmployeeID and att.AttTime > d.AttEnd1 and att.AttTime between d.AttTimeStart2Min and dateadd(mi,d.WorkStartMi2, d.ScheduleDate)
group by d.employeeID, d.ScheduleDate ,d.ShiftCode1,d.ShiftCode2
) t on d.EmployeeID = t.EmployeeID and d.ScheduleDate = t.ScheduleDate and d.ShiftCode1 = t.ShiftCode1 and d.ShiftCode2 = t.ShiftCode2

update #tblWorking2ShiftADay_Detect set AttStart2 = t.AttTime from #tblWorking2ShiftADay_Detect  d inner join (
select Min(att.AttTime) AttTime, d.employeeID, d.ScheduleDate,d.ShiftCode1,d.ShiftCode2 from #tblWorking2ShiftADay_Detect d
inner join #tblTmpAttend att on d.EmployeeID = att.EmployeeID and att.AttTime > d.AttEnd1 and att.AttTime between dateadd(mi,d.WorkStartMi2, d.ScheduleDate) and d.AttTimeStart2Max
where d.AttStart2 is null
group by d.employeeID, d.ScheduleDate ,d.ShiftCode1,d.ShiftCode2
) t on d.EmployeeID = t.EmployeeID and d.ScheduleDate = t.ScheduleDate and d.ShiftCode1 = t.ShiftCode1 and d.ShiftCode2 = t.ShiftCode2

-- doi thi di lam an xa
update #tblWorking2ShiftADay_Detect set AttStart2 = t.AttTime from #tblWorking2ShiftADay_Detect  d inner join (
select Min(att.AttTime) AttTime, d.employeeID, d.ScheduleDate,d.ShiftCode1,d.ShiftCode2 from #tblWorking2ShiftADay_Detect d
inner join #tblTmpAttend att on d.EmployeeID = att.EmployeeID and att.AttTime > d.AttEnd1 and abs(datediff(mi ,d.ScheduleDate,att.AttTime)-d.WorkStartMi2) < 241
where d.AttStart2 is null
group by d.employeeID, d.ScheduleDate ,d.ShiftCode1,d.ShiftCode2
) t on d.EmployeeID = t.EmployeeID and d.ScheduleDate = t.ScheduleDate and d.ShiftCode1 = t.ShiftCode1 and d.ShiftCode2 = t.ShiftCode2



-- AttEnd2
update #tblWorking2ShiftADay_Detect set AttEnd2 = t.AttTime from #tblWorking2ShiftADay_Detect  d inner join (
select Min(att.AttTime) AttTime, d.employeeID, d.ScheduleDate,d.ShiftCode1,d.ShiftCode2 from #tblWorking2ShiftADay_Detect d
inner join #tblTmpAttend att on d.EmployeeID = att.EmployeeID and att.AttTime between dateadd(mi,d.WorkEndMi2, d.ScheduleDate) and d.AttTimeEnd2Max
group by d.employeeID, d.ScheduleDate ,d.ShiftCode1,d.ShiftCode2
) t on d.EmployeeID = t.EmployeeID and d.ScheduleDate = t.ScheduleDate and d.ShiftCode1 = t.ShiftCode1 and d.ShiftCode2 = t.ShiftCode2

update #tblWorking2ShiftADay_Detect set AttEnd2 = t.AttTime
from #tblWorking2ShiftADay_Detect  d inner join (
select max(att.AttTime) AttTime, d.employeeID, d.ScheduleDate,d.ShiftCode1,d.ShiftCode2 from #tblWorking2ShiftADay_Detect d
inner join #tblTmpAttend att on d.EmployeeID = att.EmployeeID and att.AttTime between d.AttTimeEnd2Min and dateadd(mi,d.WorkEndMi2, d.ScheduleDate)
where d.AttEnd2 is null
group by d.employeeID, d.ScheduleDate ,d.ShiftCode1,d.ShiftCode2
) t on d.EmployeeID = t.EmployeeID and d.ScheduleDate = t.ScheduleDate and d.ShiftCode1 = t.ShiftCode1 and d.ShiftCode2 = t.ShiftCode2


delete #tblWorking2ShiftADay_Detect where (AttStart1 is null or AttEnd1 is null or AttStart2 is null or AttEnd2 is null)



delete d from #tblWorking2ShiftADay_Detect d where not exists (select 1 from (
select max(datediff(mi,d.AttEnd1,d.AttStart2)) MaxSE, d.EmployeeID,d.ScheduleDate from #tblWorking2ShiftADay_Detect d group by d.EmployeeID,d.ScheduleDate
)t where d.EmployeeID = t.EmployeeID and d.ScheduleDate = t.ScheduleDate and datediff(mi,d.AttEnd1,d.AttStart2) = t.MaxSE)

end


select * into #tblHoliday from tblHoliday where LeaveDate between @FromDate and @ToDate
if(OBJECT_ID('sp_ShiftDetector_Begin_HolidayStatusByEmployeeType' )is null)
begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_Begin_HolidayStatusByEmployeeType
(@StopUpdate bit output)
as
begin
 SET NOCOUNT ON;
end')
end
 set @StopUpdate = 0
 exec sp_ShiftDetector_Begin_HolidayStatusByEmployeeType @StopUpdate output

 if(@StopUpdate = 0)
 BEGIN

  -- tu bang tblwschdule
 update m set HolidayStatus = s.HolidayStatus
 from #tblShiftDetectorMatched m
 inner join (select EmployeeID,ScheduleDate,HolidayStatus
 from #tblWSchedule s where s.ApprovedHolidayStatus = 1) s
 on m.EmployeeId = s.EmployeeID and m.ScheduleDate = s.ScheduleDate
 --where m.HolidayStatus is null -- bỏ đi do approvedholidaystatus tức là khách đã approve cái ngày đó là nghỉ hay đi làm rồi

 create table #tblHasHoliday(EmployeeID varchar(20),ScheduleDate date)

 insert into #tblHasHoliday(EmployeeID,ScheduleDate)
 select EmployeeID,ScheduleDate from
 (
 update d set HolidayStatus = h.HolidayStatus output inserted.EmployeeID,inserted.ScheduleDate
 from #tblShiftDetectorMatched d
 inner join #tblEmployeeList e on d.EmployeeId = e.EmployeeID
 inner join #tblHoliday h on h.LeaveDate = d.ScheduleDate and (e.EmployeeTypeID = h.EmployeeTypeID or h.EmployeeTypeID = -1)
 inner join dbo.fn_EmployeeStatusRange(0) es on d.EmployeeId = es.EmployeeID and d.Scheduledate between es.ChangedDate and es.StatusEndDate
  and es.EmployeeStatusID in(select EmployeeStatusID from tblEmployeeStatus where ISNULL(CutSI,0) =0)
 where d.HolidayStatus is null
 ) ho

 -- tu loai nhan vien
 update d set HolidayStatus =
  case when (e.SaturdayOff = 1 and DATENAME(dw,d.ScheduleDate) = 'Saturday') OR (e.SundayOff = 1 and DATENAME(dw,d.ScheduleDate) = 'Sunday') then 1 else null end
 from #tblShiftDetectorMatched d
 inner join #tblEmployeeList e on d.EmployeeId = e.EmployeeID
 where d.HolidayStatus is null
 -- ngay le roi vao ngay Chu nhat, set Holidaystatus = 2 nhung ko insert nghi
  update d set HolidayStatus = h.HolidayStatus
 from #tblShiftDetectorMatched d
 inner join #tblEmployeeList e on d.EmployeeId = e.EmployeeID
 inner join #tblHoliday h on h.LeaveDate = d.ScheduleDate and (e.EmployeeTypeID = h.EmployeeTypeID or h.EmployeeTypeID = -1)
 inner join dbo.fn_EmployeeStatusRange(0) es on d.EmployeeId = es.EmployeeID and d.Scheduledate between es.ChangedDate and es.StatusEndDate
  and es.EmployeeStatusID in(select EmployeeStatusID from tblEmployeeStatus where ISNULL(CutSI,0) =0)
 where d.HolidayStatus = 1

 select  m.EmployeeID,m.ScheduleDate,h.LeaveStatus,h.LeaveCode as LeaveCode
 ,CASE WHEN h.LeaveStatus IN(1,2) THEN 4 WHEN h.LeaveStatus IN(4,5) THEN 2 ELSE 8 END as LvAmount,1 as LvRegister,N'System automatically insert leave' as Reason
 ,h.EmployeeTypeID
 into #LeaveAuto
from #tblHasHoliday m
  inner join #tblEmployeeList e  on m.EmployeeId = e.EmployeeId
 inner join #tblHoliday h  on m.ScheduleDAte = h.LeaveDate and (e.EmployeeTypeID = h.EmployeeTypeID or h.EmployeeTypeID = -1) and h.LeaveCode is not null

 -- remove duplicate holiday record
 delete l from #LeaveAuto l inner join (
 select l.EmployeeID, l.ScheduleDate, l.LeaveCode, max(l.EmployeeTypeID) EmployeeTypeID from #LeaveAuto l group by l.EmployeeID, l.ScheduleDate, l.LeaveCode having count(1) > 1
 ) tmp on l.EmployeeID = tmp.EmployeeID and l.ScheduleDate = tmp.ScheduleDate and l.LeaveCode = tmp.LeaveCode and l.EmployeeTypeID < tmp.EmployeeTypeID


 delete lv from tblLvhistory lv
 INNER JOIN #tblEmployeeList te ON te.EmployeeID = lv.EmployeeID
 inner join #tblShiftDetectorMatched m on lv.EmployeeID  = m.EmployeeId and lv.LeaveDate = m.ScheduleDate
 where lv.LeaveDate between @FromDate and @ToDate
 and Reason = N'System automatically insert leave'
  -- xóa tất cả những thằng cản đường
 and not exists(select 1 from #LeaveAuto la where lv.EmployeeID  = la.EmployeeId and lv.LeaveDate = la.ScheduleDate and lv.LeaveCode = la.LeaveCode and lv.LvAmount = la.LvAmount)


 DELETE  tblLvhistory from tblLvhistory lv
 where exists (SELECT 1 FROM #tblEmployeeList st where lv.EmployeeID = st.EmployeeID and lv.LeaveDate between dateadd(dd,-30,st.HireDate) and st.HireDate)
 and lv.Reason = N'System automatically insert leave'


  INSERT INTO tblLvHistory( EmployeeID, LeaveDate, LeaveStatus, LeaveCode, LvAmount, LvRegister,Reason)
  select EmployeeID, ScheduleDate, LeaveStatus, LeaveCode, LvAmount, LvRegister,Reason
   from #LeaveAuto la
   where not exists(select 1 from tblLvHistory lv where la.EmployeeID = lv.EmployeeID and la.ScheduleDate = lv.LeaveDate)

 drop table #LeaveAuto

 UPDATE #tblShiftDetectorMatched SET HolidayStatus = 0 where HolidayStatus is null
 -- ngay nghi le va ngay nghi bu neu khong phai la ngay nghi cuoi tuan thi them 1 ngay thi tinh luong vao lvhistory de tinh cong ngay do

 if @trackingML = 1
 begin
  --phot vao roi thi xoa di
  delete tblLvHistory from tblLvHistory lv
  inner join #tblPendingImportAttend p on lv.EmployeeID = p.EmployeeID and lv.LeaveDate = p.[Date]
  AND EXISTS (select 1 FROM tblEmployeeStatus es where CutSI = 1 AND es.LeaveCodeForCutSI = lv.LeaveCode)
  where  lv.Reason= N'System automatically insert leave' AND lv.LeaveDate between DATEADD(dd,1,@FromDate) and @ToDate

 insert into tblLvHistory(EmployeeID,LeaveDate,LeaveCode,LeaveStatus,LvAmount,Reason)
  select ws.EmployeeID,ws.ScheduleDate as LeaveDate, s.LeaveCodeForCutSI as LeaveCode,3 as LeaveStatus ,8 as LvAmount
  ,N'System automatically insert leave' as Reason
  --into #CutSItblLvHistory
  FROM tblWSchedule ws
  inner join #tblPendingImportAttend p on ws.EmployeeID = p.EmployeeID and ws.ScheduleDate = p.[Date]
  inner join tblEmployeeStatus s on p.EmployeeStatusID = s.EmployeeStatusID
  and s.CutSI  = 1 and s.LeaveCodeForCutSI is not null
  and s.LeaveCodeForCutSI in(select LeaveCode from tblLeaveType)
  where ws.HolidayStatus = 0 and ws.ScheduleDate between DATEADD(dd,1,@FromDate) and @ToDate
  and not exists(select 1 from tblLvHistory lv where ws.EmployeeID =lv.EmployeeID and ws.ScheduleDate = lv.LeaveDate
  and isnull(lv.Reason,'')  <> 'System automatically insert leave'
  )
  --exec sp_InsertUpdateFromTempTableTOTable '#CutSItblLvHistory' ,'tblLvHistory'
  --drop table #CutSItblLvHistory


 end


end

if(OBJECT_ID('sp_ShiftDetector_Finish_HolidayStatusByEmployeeType' )is null)
begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_Finish_HolidayStatusByEmployeeType
(@StopUpdate bit output)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUpdate = 0
exec sp_ShiftDetector_Finish_HolidayStatusByEmployeeType @StopUpdate output


-- leave
select lv.EmployeeID,lv.LeaveDate,lv.LeaveStatus,lv.LeaveCode,lv.LvAmount,isnull(lt.PaidRate,0) PaidRate,lt.LeaveCategory
,lv.Reason
into #tblLvHistory
from tblLvHistory lv
INNER JOIN #tblEmployeeList te ON te.EmployeeID = lv.EmployeeID
INNER join tblLeaveType lt on lv.LeaveCode = lt.LeaveCode
where
lv.LeaveDate between @FromDate3 and @ToDate3
and lv.LeaveCode in (select LeaveCode from tblLeaveType where (LeaveCategory = 1 or (LeaveCategory = 0 and PaidRate = 0)) and LeaveCode <> '
' )


--create nonclustered index ix_temptblLvHistory on #tblLvHistory(EmployeeId,Leavedate,LeaveStatus,LeaveCode) include(lvamount,PaidRate)

select lv.EmployeeId,lv.LeaveDate,lv.LeaveStatus
into #tblFWC from tblLvhistory lv
where lv.LeaveDate between @FromDate3 and @ToDate3 and
EXISTS (select 1 FROM #tblEmployeeList te WHERE lv.EmployeeID = te.EmployeeID)
and lv.LeaveCode = 'FWC'

-- dua các ca vào d? ch?m di?m
insert into #tblShiftDetector(EmployeeID,ScheduleDate,ShiftCode,HolidayStatus,RatioMatch,EmployeeStatusID)
select c.EmployeeID,s.ScheduleDate,sg.ShiftCode,s.HolidayStatus,0,EmployeeStatusID
from #tblShiftDetectorMatched s
inner join #tblShiftGroupCode c on s.EmployeeId = c.EmployeeID
full outer join #tblShiftGroup_Shift sg on c.ShiftGroupCode = sg.ShiftGroupID
where sg.ShiftCode is not null and s.EmployeeId is not null
and s.ScheduleDate between c.FromDate and c.ToDate


insert into #tblShiftDetector(EmployeeID,ScheduleDate,ShiftCode,HolidayStatus,RatioMatch,EmployeeStatusID)
select s.EmployeeID,s.ScheduleDate,ss.ShiftCode,s.HolidayStatus,0,EmployeeStatusID
from #tblShiftDetectorMatched s
cross join
(select distinct ShiftCode from #tblShiftSetting) ss
where not exists(select 1 from #tblShiftDetector sd where s.EmployeeId = sd.EmployeeID and s.Scheduledate = sd.Scheduledate)


if(OBJECT_ID('sp_ShiftDetector_FinishCustomizeListShiftCode' )is null)
begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_FinishCustomizeListShiftCode
(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)
as
begin
 SET NOCOUNT ON;
end')
end
 set @StopUpdate = 0
 exec sp_ShiftDetector_FinishCustomizeListShiftCode @StopUpdate output ,@LoginID,@FromDate,@ToDate

-- *XAC DINH CA CHINH XAC2
-- da dc nguoi dung duyet, hoac tao lich manual
TRUNCATE TABLE #tblShiftDetectorMatched
INSERT INTO #tblShiftDetectorMatched(EmployeeId,ScheduleDate,ShiftCode,RatioMatch,WorkStart,WorkEnd
 ,BreakStart,BreakEnd
 ,OTBeforeStart,OTBeforeEnd
 ,OTAfterStart,OTAfterEnd
 ,HolidayStatus,Approved,EmployeeStatusID
)
SELECT ws.EmployeeID,ws.ScheduleDate,ws.ShiftCode,1000, dateadd(mi,ss.WorkStartMi, ws.ScheduleDate), dateadd(mi,ss.WorkEndMi, ws.ScheduleDate)
,dateadd(mi,ss.BreakStartMi, ws.ScheduleDate), dateadd(mi,ss.BreakEndMi, ws.ScheduleDate)
,dateadd(mi,ss.OTBeforeStartMi, ws.ScheduleDate), dateadd(mi,ss.OTBeforeStartMi, ws.ScheduleDate)
,dateadd(mi,ss.OTAfterStartMi, ws.ScheduleDate), dateadd(mi,ss.OTAfterEndMi, ws.ScheduleDate)
,ws.HolidayStatus,ws.Approved,p.EmployeeStatusID--,e.WHPerWeek
FROM #tblWSchedule ws inner join #tblPendingImportAttend p on ws.EmployeeID = p.EmployeeID and ws.ScheduleDate = p.[Date]
left join #tblShiftSetting ss on ws.ShiftCode = ss.ShiftCode
where
((ws.Approved =1)
-- ngu?i dùng xác nh?n gi? vào và gi? ra c?a ngày hôm dó, và hôm dó ch? có 1 period
or exists (select 1 from (
select EmployeeID, Attdate from #tblHasTA where TAStatus = 3 and AttStart is null and AttEnd is null group by EmployeeID, Attdate having COUNT(1) = 1
) tmp where ws.employeeID = tmp.EmployeeID and tmp.Attdate = ws.ScheduleDate)
)
and not exists (select 1 from #tblWorking2ShiftADay_Detect ts where ts.EmployeeID = ws.EmployeeId and ts.ScheduleDate = ws.ScheduleDate)
and not exists (select 1 from #tblLvHistory lv where lv.EmployeeID = ws.EmployeeId and lv.LeaveDate = ws.ScheduleDate and lv.LeaveStatus = 3 and @LEAVEFULLDAYSTILLHASATTTIME = 0)


DELETE D FROM #tblShiftDetector D
WHERE EXISTS (SELECT 1 FROM #tblShiftDetectorMatched M WHERE M.EmployeeId = D.EmployeeId AND M.ScheduleDate = D.ScheduleDate)

-- ch? có 1 ca duy nh?t
INSERT INTO #tblShiftDetectorMatched(EmployeeId,ScheduleDate,ShiftCode,RatioMatch,HolidayStatus,WorkStart,WorkEnd
,BreakStart,BreakEnd
,OTBeforeStart,OTBeforeEnd
,OTAfterStart,OTAfterEnd
,Approved,EmployeeStatusID
)
select d.EmployeeId,d.ScheduleDate,d.ShiftCode,d.RatioMatch,d.HolidayStatus, dateadd(mi,ss.WorkStartMi, d.ScheduleDate), dateadd(mi,ss.WorkEndMi, d.ScheduleDate)
 , dateadd(mi,ss.BreakStartMi, d.ScheduleDate), dateadd(mi,ss.BreakEndMi, d.ScheduleDate)
 ,dateadd(mi,ss.OTBeforeStartMi, d.ScheduleDate), dateadd(mi,ss.OTBeforeStartMi, d.ScheduleDate)
 , dateadd(mi,ss.OTAfterStartMi, d.ScheduleDate), dateadd(mi,ss.OTAfterEndMi, d.ScheduleDate)
 ,1,d.EmployeeStatusID
from #tblShiftDetector d
inner join #tblShiftSetting ss on d.ShiftCode = ss.ShiftCode
where exists (select 1 from (
select EmployeeId, ScheduleDate from #tblShiftDetector
 group by EmployeeId, ScheduleDate having COUNT(1) =1
) tmp where tmp.EmployeeId = d.EmployeeId and tmp.ScheduleDate = d.ScheduleDate)

if(OBJECT_ID('sp_ShiftDetector_MatchedShift_Process' )is null)
begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_MatchedShift_Process
(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)
as
begin
 SET NOCOUNT ON;
end')
end
 set @StopUpdate = 0
 exec sp_ShiftDetector_MatchedShift_Process @StopUpdate output ,@LoginID,@FromDate,@ToDate
 if @StopUpdate = 0
 begin
update #tblShiftDetectorMatched set TIMEINBEFORE = DATEADD(MI,-@TA_TIMEINBEFORE,WorkStart), TIMEOUTAFTER = DATEADD(hour,@TA_TIMEOUTAFTER,WorkStart), INOUT_MINIMUM = @TA_INOUT_MINIMUM

-- lo?i nh?ng ?ng viên l?y gi? ra hôm tru?c làm gi? vào hôm nay
delete m2 from #tblShiftDetectorMatched m1
inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate-1 and m1.AttEnd = m2.AttStart
DELETE D FROM #tblShiftDetector D WHERE EXISTS (SELECT 1 FROM #tblShiftDetectorMatched M WHERE M.EmployeeId = D.EmployeeId AND M.ScheduleDate = D.ScheduleDate)
-- XÁC Ð?NH GI? VÀO RA CHO CA CHÍNH XÁC
-- fixed att
update #tblShiftDetectorMatched set FixedAtt =0

--update m1 set FixedAtt = 1 from #tblShiftDetectorMatched m1 inner join #tblWSchedule m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate
-- where m2.DateStatus = 3

update m set AttStart = ta.AttStart, StateIn = 1
FROM #tblShiftDetectorMatched M
INNER JOIN #tblHasTA TA ON M.EmployeeId = ta.EmployeeID and m.ScheduleDate = ta.AttDate
 where (ta.TAStatus = 1 )

 update m set AttEnd = ta.AttEnd, StateOut = 2
FROM #tblShiftDetectorMatched M
INNER JOIN #tblHasTA TA ON M.EmployeeId = ta.EmployeeID and m.ScheduleDate = ta.AttDate
 where (ta.TAStatus = 2 )
update m set AttStart = ta.AttStart, AttEnd = ta.AttEnd,FixedAtt = 1
FROM #tblShiftDetectorMatched M
INNER JOIN (
 select EmployeeID,AttDate,max(TAStatus) TAStatus,Min(AttStart) AttStart, Max(AttEnd) AttEnd
 from #tblHasTA group by EmployeeID,AttDate
) TA ON M.EmployeeId = ta.EmployeeID and m.ScheduleDate = ta.AttDate
where (ta.TAStatus = 3)
--phang t?i t?p qua ben kia luôn, ngu?i dùng s?a gi? r?i mà
update m set AttStart = ta.AttStart, AttEnd = ta.AttEnd,FixedAtt = 1, StateIn = 1,StateOut = 2
FROM #tblShiftDetector M
INNER JOIN (
 select EmployeeID,AttDate,max(TAStatus) TAStatus,Min(AttStart) AttStart, Max(AttEnd) AttEnd
 from #tblHasTA group by EmployeeID,AttDate
) TA ON M.EmployeeId = ta.EmployeeID and m.ScheduleDate = ta.AttDate
where (ta.TAStatus = 3)


update #tblShiftDetectorMatched set IsLeaveStatus3 = 0
update ta1 set IsLeaveStatus3 = 1 from #tblShiftDetectorMatched ta1
inner join #tblLvHistory ta2 on ta1.EmployeeId = ta2.EmployeeID and ta1.ScheduleDate = ta2.LeaveDate
 and LeaveStatus = 3

-- AttEnd Yesterday cho bang Matched
update m1 set AttEndYesterday = isnull(m2.AttEnd, m2.WorkEnd)
from #tblShiftDetectorMatched m1 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate+1
where (m2.AttEnd is not null or m2.WorkEnd is not null) and m2.Approved = 1
update m1 set AttStartTomorrow = isnull(m2.AttStart,m2.WorkStart) from #tblShiftDetectorMatched m1 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate-1
where (m2.AttStart is not null or m2.WorkStart is not null) and m2.Approved = 1
-- trong b?ng HasTA
update m1 set AttEndYesterday = isnull(m2.AttEnd, dateadd(HOUR,-10,m1.WorkStart))
from #tblShiftDetectorMatched m1 inner join #tblHasTA m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.NextDate
where m2.AttEnd is not null and (m2.TAStatus = 3 or m2.AttDate between @FromDate3 and @FromDate)

update m1 set AttStartTomorrow = isnull(m2.AttStart,DATEADD(hour,16,m1.WorkEnd)) from #tblShiftDetectorMatched m1
inner join #tblHasTA m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.PrevDate
where m2.AttStart is not null and (m2.TAStatus = 3)
-- xac dinh gio vao ra do hom qua và ngày mai dã du?c fix c? d?nh chua
update m1 set AttEndYesterdayFixed = 1 from #tblShiftDetectorMatched m1 inner join #tblWSchedule m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.NextDate
where m2.DateStatus = 3
update m1 set AttStartTomorrowFixed = 1 from #tblShiftDetectorMatched m1 inner join #tblWSchedule m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.PrevDate
where m2.DateStatus = 3

update #tblShiftDetectorMatched set AttEndYesterday = dateadd(HOUR,-10,WorkStart) where AttEndYesterday is null
update #tblShiftDetectorMatched set AttStartTomorrow = DATEADD(hour,16,WorkEnd) where AttStartTomorrow is null

-- trong b?ng HasTA
update m1 set AttEndYesterday = isnull(m2.AttEnd, dateadd(HOUR,-10,m1.WorkStart))
from #tblShiftDetector m1 inner join #tblHasTA m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.NextDate
where m2.AttEnd is not null and (m2.TAStatus = 3 or m2.AttDate between @FromDate3 and @FromDate)
-- xac dinh gio vao ra do hom qua và ngày mai dã du?c fix c? d?nh chua
update m1 set AttEndYesterdayFixed = 1 from #tblShiftDetector m1 inner join #tblWSchedule m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.NextDate
where m2.DateStatus = 3
update m1 set AttStartTomorrowFixed = 1 from #tblShiftDetector m1 inner join #tblWSchedule m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.PrevDate
where m2.DateStatus = 3


 -- xác d?nh AttStart cho #tblShiftDetectorMatched
 -- 1. gà què an quanh c?i xay
update #tblShiftDetectorMatched set AttStart = tmp.AttTime
from #tblShiftDetectorMatched m inner join (
 select m.EmployeeId, m.ScheduleDate, MIN(t.AttTime) AttTime
 from #tblShiftDetectorMatched m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where m.AttStart is null and FixedAtt = 0
  and (ForceState = 0 or AttState = 1)
  and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
  and abs(DATEDIFF(mi,m.WorkStart,t.AttTime))<=60
 group by m.EmployeeId, m.ScheduleDate
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate



update #tblShiftDetectorMatched set AttStart = tmp.AttTime


from #tblShiftDetectorMatched m inner join (
 select m.EmployeeId, m.ScheduleDate, max(t.AttTime) AttTime
 from #tblShiftDetectorMatched m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where m.AttStart is null and FixedAtt = 0
  and (ForceState = 0 or AttState = 1)
  and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
  and DATEDIFF(mi,m.WorkStart,t.AttTime)between -330 and -1
 group by m.EmployeeId, m.ScheduleDate
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate

update #tblShiftDetectorMatched set AttStart = tmp.AttTime
from #tblShiftDetectorMatched m inner join (
 select m.EmployeeId, m.ScheduleDate, MIN(t.AttTime) AttTime
 from #tblShiftDetectorMatched m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where m.AttStart is null and FixedAtt = 0
  and (ForceState = 0 or AttState = 1)
and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
  and DATEDIFF(mi,m.WorkStart,t.AttTime)between 0 and 330
 group by m.EmployeeId, m.ScheduleDate
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate


/*
 AttEnd cho #tblShiftDetectorMatched */
 --1. ga que an quan coi xay
update #tblShiftDetectorMatched set AttEnd = tmp.AttTime
from #tblShiftDetectorMatched m inner join (
 select m.EmployeeId, m.ScheduleDate, max(t.AttTime) AttTime
 from #tblShiftDetectorMatched m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where m.AttEnd is null and m.FixedAtt =0
  and (t.ForceState = 0 or t.AttState = 2)
  and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
  and abs(DATEDIFF(mi,m.WorkEnd,t.AttTime))<=60
  and (t.AttTime > m.AttStart or (m.AttStart is null and t.AttTime > m.WorkStart))
 group by m.EmployeeId, m.ScheduleDate
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate


--1. xu ly truong hop bam nham, sau do hon 1h moi ra ve

update #tblShiftDetectorMatched set AttEnd = tmp.AttTime
from #tblShiftDetectorMatched m inner join (
 select m.EmployeeId, m.ScheduleDate, max(t.AttTime) AttTime
 from #tblShiftDetectorMatched m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where m.AttEnd < m.WorkEnd and m.FixedAtt =0
  and (t.ForceState = 0 or t.AttState = 2)
  and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
  and DATEDIFF(mi,m.WorkEnd,t.AttTime) <= 120
  and (t.AttTime > m.AttStart or (m.AttStart is null and t.AttTime > m.WorkStart))
 group by m.EmployeeId, m.ScheduleDate
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate

-- riêng v?i nh?ng ngu?i thu?c b? ph?n b?o v? làm 24h/ngày
update m set AttStartTomorrow = dateadd(MI,60,AttStartTomorrow)
from #tblShiftDetectorMatched m where exists (select 1 from #tblEmployeeList e where m.EmployeeId = e.EmployeeID and e.Security24hWorking = 1)

update m set AttEnd = tmp.AttTime
from #tblShiftDetectorMatched m
inner join (
 select m.EmployeeId, m.ScheduleDate, min(t.AttTime) AttTime
 from #tblShiftDetectorMatched m
 inner join #tblTmpAttend_Org t on m.EmployeeId = t.EmployeeID
 where m.AttEnd is null and FixedAtt =0
  and (ForceState = 0 or AttState = 2)
  and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow

  and abs(DATEDIFF(mi,m.WorkEnd,t.AttTime))<=60
  and (t.AttTime > m.AttStart or (m.AttStart is null and t.AttTime > m.WorkStart))
 group by m.EmployeeId, m.ScheduleDate
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate
where exists (select 1 from #tblEmployeeList e where m.EmployeeId = e.EmployeeID and e.Security24hWorking = 1)


-- nhân viên làm 24h m?t ngày (bao ve di 24h ngay), làm 1 ngay nghi 1 ngay, vì th? b? nh?ng ngày k? ti?p
update m2 set AttStart = null, AttEnd = null
from #tblShiftDetectorMatched m1 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate - 1
and (m1.AttEnd = m2.AttStart or (m1.AttStart is not null and m1.AttEnd is not null))
where m1.AttStart is not null and m1.AttEnd is not null and (m2.AttStart is null or m2.AttEnd is null)
and exists (select 1 from #tblEmployeeList e where m2.EmployeeId = e.EmployeeID and e.Security24hWorking = 1)

select ROW_NUMBER() over (Partition by datediff(day,m1.ScheduleDate, m2.ScheduleDate) order by m2.employeeID) as STT, m2.EmployeeId, m2.ScheduleDate ,m2.ShiftCode,m2.AttStart,m2.AttEnd
into #Security24hWorkingNeedDelete
from #tblShiftDetectorMatched m1 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate - 1 and m1.AttEnd = m2.AttStart
where m2.AttStart is not null and m2.AttEnd is not null and m1.AttStart is not null and m1.AttEnd is not null
and exists (select 1 from #tblEmployeeList e where m2.EmployeeId = e.EmployeeID and e.Security24hWorking = 1)

delete #Security24hWorkingNeedDelete where STT%2 = 0

update m set AttStart = null, AttEnd = null
from #Security24hWorkingNeedDelete d1 inner join #tblShiftDetectorMatched m on d1.EmployeeId = m.EmployeeId and d1.ScheduleDate = m.ScheduleDate


update #tblShiftDetectorMatched set AttEnd = tmp.AttTime from #tblShiftDetectorMatched m inner join (
 select m.EmployeeId, m.ScheduleDate, max(t.AttTime) AttTime
 from #tblShiftDetectorMatched m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where m.AttEnd is null and AttStart is not null and FixedAtt =0
  and (ForceState = 0 or AttState = 2)
  and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
and abs(DATEDIFF(mi,m.WorkEnd,t.AttTime))<=330
  and (t.AttTime > m.AttStart or (m.AttStart is null and t.AttTime > m.WorkStart))
 group by m.EmployeeId, m.ScheduleDate
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate



update m1 set AttEndYesterday = isnull(m2.AttEnd, m2.WorkEnd) from #tblShiftDetectorMatched m1 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate+1
where (m2.AttEnd is not null or m2.WorkEnd is not null) and m2.Approved = 1
update m1 set AttStartTomorrow = isnull(m2.AttStart,m2.WorkStart) from #tblShiftDetectorMatched m1 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate-1
where (m2.AttStart is not null or m2.WorkStart is not null) and m2.Approved = 1


-- 2. Ðói thì di làm an xa
update #tblShiftDetectorMatched set AttStart = tmp.AttTime from #tblShiftDetectorMatched m inner join (
 select m.EmployeeId, m.ScheduleDate, MIN(t.AttTime) AttTime
 from #tblShiftDetectorMatched m inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where (m.AttStart is null ) and FixedAtt =0 --or DATEDIFF(mi,t.AttTime,m.WorkEnd) >= 30
  and (ForceState = 0 or AttState = 1)
  and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
  and (t.AttTime < m.AttEnd or (m.AttEnd is null and t.AttTime < m.WorkEnd))
  and t.AttTime between m.TimeinBefore and m.TIMEOUTAFTER
  AND DATEDIFF(hh,t.AttTime,m.WorkStart) <= 6 --wtc:gio vào k được cách quá xa so với giờ bắt đầu ca
 group by m.EmployeeId, m.ScheduleDate
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate





update m1 set AttStartTomorrow = isnull(m2.AttStart,m2.WorkStart) from #tblShiftDetectorMatched m1 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate-1
where (m2.AttStart is not null or m2.WorkStart is not null) and m2.Approved = 1


-- 2. Ðói thì di làm an xa
update #tblShiftDetectorMatched set AttEnd = tmp.AttTime from #tblShiftDetectorMatched m inner join (
 select m.EmployeeId, m.ScheduleDate, max(t.AttTime) AttTime
 from #tblShiftDetectorMatched m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where m.AttEnd is null and FixedAtt =0
 and ((ForceState = 0 and (datediff(day,t.Atttime,WorkEnd ) =0 or datediff(hour,t.AttTime,TIMEOUTAFTER)> 3)) or AttState = 2)
  and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
  and t.AttTime < m.TIMEOUTAFTER
  and t.AttTime > isnull(m.AttStart,m.WorkStart)
 group by m.EmployeeId, m.ScheduleDate
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate

-- 2. Ðói thì di làm an xa
update #tblShiftDetectorMatched set AttEnd = tmp.AttTime from #tblShiftDetectorMatched m inner join (
 select m.EmployeeId, m.ScheduleDate, max(t.AttTime) AttTime
 from #tblShiftDetectorMatched m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where m.AttEnd is null and FixedAtt =0
  and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
  --and t.AttTime < m.TIMEOUTAFTER
  and t.AttTime > isnull(m.AttStart,m.WorkStart)
  AND DATEDIFF(hh,m.WorkEnd,t.AttTime) <= 6 --wtc: giờ ra k đc cách quá xa so với giờ kết thúc ca
 group by m.EmployeeId, m.ScheduleDate
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate



-- quên b?m 1 d?u và AttStart dang trùng AttEnd thì xác d?nh l?i cho dúng anh nào vào anh nào ra
-- tru?ng h?p nhân viên s?a l?i gi? vào ra, nen bi du thua attTime
update #tblShiftDetectorMatched set AttStart = case when DATEDIFF(mi,WorkStart,AttStart) < 240 and (isnull(AttEndYesterdayFixed,0) = 0 or DATEDIFF(mi,AttEndYesterday,AttStart) > 120) then AttStart else null end ,AttEnd = case when DATEDIFF(mi,WorkEnd,AttEnd) >=-240 and (isnull(AttStartTomorrowFixed,0) = 0 or DATEDIFF(mi,AttStartTomorrow,AttStart) < 120) then AttEnd else null end
from #tblShiftDetectorMatched where AttStart = AttEnd --and EmployeeId = 'HLS001'




-- ngh? c? ngày mà b?m thi?u d?u thì b?
update m set AttStart = null, AttEnd = null
from #tblShiftDetectorMatched m where ((m.AttStart is not null and m.AttEnd is null ) or (m.AttStart is null and m.AttEnd is not null))
and IsLeaveStatus3 =1
and FixedAtt =0

end


-- tinh workingTime cho bang dang duyet
UPDATE ws set WorkStart = dateadd(mi,ss.WorkStartMi, ws.ScheduleDate), WorkEnd = dateadd(mi,ss.WorkEndMi, ws.ScheduleDate), BreakStart = dateadd(mi,ss.BreakStartMi, ws.ScheduleDate), BreakEnd = dateadd(mi,ss.BreakEndMi, ws.ScheduleDate) ,isNightShift = case when ss.WorkEndMi > 1440 then 1 else 0 end
,isOfficalShift = ISNULL(ss.isOfficalShift,0)
,WorkStartMi = ss.WorkStartMi, WorkEndMi = ss.WorkEndMi,BreakStartMi = ss.BreakStartMi, BreakEndMi = ss.BreakEndMi
,WorkStartSMi = ss.WorkStartStatisticMi, WorkEndSMi = ss.WorkEndStatisticMi
,WorkStartEMi = ss.WorkStartStatisticMi, WorkEndEMi = ss.WorkEndStatisticMi
FROM #tblShiftDetectorMatched ws inner join #tblShiftSetting ss on ws.ShiftCode = ss.ShiftCode


update #tblShiftDetectorMatched set AttStartMi = datepart(hour,AttStart)*60 + DATEPART(minute,AttStart)
, AttEndMi = datepart(hour,AttEnd)*60 + DATEPART(minute,AttEnd) + CASE WHEN DATEPART(SECOND,AttEnd) >= 30 THEN 1 ELSE 0 END --wtc:gio ve neu giây >=30 thì làm tròn phút lên


update #tblShiftDetectorMatched set AttEndMi = 1440+AttEndMi where DATEDIFF(day,ScheduleDate,AttEnd) = 1

if(@AUTO_FILL_TIMEINOUT_FWC =1 )
begin
 update ta1 set AttStartMi = case when AttStartMi is null and ta2.LeaveStatus in (1,3,4) then ta1.WorkStartMi else AttStartMi end
 , AttEndMi = case when AttEndMi is null and ta2.LeaveStatus in (2,3,5) then ta1.workendMi else AttEndMi end
 from #tblShiftDetectorMatched ta1
 inner join #tblFWC ta2 on ta1.EmployeeId = ta2.EmployeeId and ta1.ScheduleDate = ta2.LeaveDAte
end

if @MATERNITY_LATE_EARLY_OPTION = 1
 update #tblShiftDetectorMatched set AttStartMi =
 case when AttStartMi > WorkStartMi then case when AttStartMi - WorkStartMi <= 30 then WorkStartMi else AttStartMi - @MATERNITY_MUNITE end
 else AttStartMi end
 from #tblShiftDetectorMatched ta1 where EmployeeStatusID in (10,11) and AttStartMi is not null and AttEndMi is not null
else
if @MATERNITY_LATE_EARLY_OPTION = 2
 update #tblShiftDetectorMatched set AttEndMi = case when AttEndMi < WorkEndMi then case when WorkEndMi - AttStartMi <= 30 then WorkEndMi else AttEndMi + @MATERNITY_MUNITE end else AttEndMi end
 from #tblShiftDetectorMatched ta1 where EmployeeStatusID in (10,11) and AttStartMi is not null and AttEndMi is not null
else
if @MATERNITY_LATE_EARLY_OPTION = 3
 update #tblShiftDetectorMatched set AttEndMi = case when WorkEndMi- AttEndMi >= AttStartMi - WorkStartMi and AttEndMi < WorkEndMi then case when WorkEndMi- AttStartMi <= 30 then WorkEndMi else AttEndMi + @MATERNITY_MUNITE end else AttEndMi end
  ,AttStartMi = case when WorkEndMi- AttEndMi < AttStartMi - WorkStartMi and AttStartMi > WorkStartMi then case when AttStartMi - WorkStartMi <= 30 then WorkStartMi else AttStartMi - @MATERNITY_MUNITE end else AttStartMi end
 from #tblShiftDetectorMatched ta1 where EmployeeStatusID in (10,11) and AttStartMi is not null and AttEndMi is not null

 -- UPDATE LATE_PERMIT AND EARLY_PERMIT

  update sd
set  sd.Late_Permit =COALESCE(p.LATE_PERMIT, sc.LATE_PERMIT, dp.LATE_PERMIT,d.LATE_PERMIT)
,  sd.Early_Permit = COALESCE(p.Early_Permit, sc.Early_Permit, dp.Early_Permit,d.Early_Permit)
 from #tblShiftDetectorMatched sd
 left join #tblEmployeeList s on s.EmployeeID = sd.EmployeeId
 left join tblDivision d on d.DivisionID = s.DivisionID
 left join tblDepartment dp on dp.DepartmentID = s.DepartmentID
 left join tblSection sc on sc.SectionID = s.SectionID
 left join tblPosition p on p.PositionID = s.PositionID
 --update sd set AttStartMi = case when AttStartMi < WorkEndMi + Late_Permit then WorkEndMi else AttStartMi end from #tblShiftDetectorMatched sd
update sd
set AttStartMi = case when AttStartMi BETWEEN WorkStartMi and WorkStartMi + Late_Permit then WorkStartMi else AttStartMi end,
    AttEndMi = case when AttEndMi BETWEEN WorkEndMi - Early_Permit AND WorkEndMi then  WorkEndMi else AttEndMi end
from #tblShiftDetectorMatched sd


update #tblShiftDetectorMatched
set WorkingTimeMi =
 case
 when AttEndMi >= WorkEndMi then WorkEndMi
 when AttEndMi >= BreakEndMi then AttEndMi

 when AttEndMi >= BreakStartMi then BreakStartMi
 when AttEndMi >= WorkStartMi then AttEndMi else WorkStartMi end
- case
 when AttStartMi <= WorkStartMi then WorkStartMi
 when AttStartMi < BreakStartMi then AttStartMi
 when AttStartMi <= BreakEndMi then BreakEndMi
 when AttStartMi <= WorkEndMi then AttStartMi else WorkEndMi end
,StdWorkingTimeMi = WorkEndMi - WorkStartMi - (BreakEndMi - BreakStartMi)
where AttStartMi is not null and AttEndMi is not null

update m set StdWorkingTimeMi = StdWorkingTimeMi - lv.LvAmount*60.0
from #tblShiftDetectorMatched m
inner join (select EmployeeID,LeaveDate, sum(LvAmount) LvAmount
from #tblLvHistory where PaidRate > 0 and LeaveCategory = 1 group by EmployeeID,LeaveDate) lv on lv.EmployeeID = m.EmployeeId and m.ScheduleDate = lv.LeaveDate
where StdWorkingTimeMi is not null and m.IsLeaveStatus3 <> 1

update #tblShiftDetectorMatched set StdWorkingTimeMi = 480 where StdWorkingTimeMi <= 0

UPDATE #tblShiftDetectorMatched set WorkingTimeMi = WorkingTimeMi - (BreakEndMi - BreakStartMi)
WHERE BreakStartMi < BreakEndMi AND AttStartMi < BreakStartMi AND AttEndMi > BreakEndMi
and AttStartMi is not null and AttEndMi is not null

if @MATERNITY_LATE_EARLY_OPTION = 0
 UPDATE #tblShiftDetectorMatched SET WorkingTimeMi = case when WorkingTimeMi + @MATERNITY_MUNITE >= StdWorkingTimeMi then StdWorkingTimeMi else WorkingTimeMi + @MATERNITY_MUNITE end
 from #tblShiftDetectorMatched d where d.EmployeeStatusID in (10,11) and AttStartMi is not null and AttEndMi is not null


UPDATE #tblShiftDetectorMatched set WorkingTimeMi = StdWorkingTimeMi where WorkingTimeMi >= StdWorkingTimeMi

--s?a ch? này xíu thêm cái t? l? vào cho nó máu
UPDATE ta1 set WorkingTimeMi = cast(WorkingTimeMi as float) / ta1.StdWorkingTimeMi * (ta2.STDWorkingTime_SS -isnull(lv.LvAmount*60.0,0))
from #tblShiftDetectorMatched ta1
inner join #tblShiftSetting ta2 on ta1.ShiftCode = ta2.ShiftCode
 and ta1.StdWorkingTimeMi <> ta2.STDWorkingTime_SS


 and ta1.Workingtimemi >0
left join (select EmployeeID,LeaveDate, sum(LvAmount) LvAmount
from #tblLvHistory where LeaveCategory = 1 group by EmployeeID,LeaveDate) lv on lv.EmployeeID = ta1.EmployeeId and ta1.ScheduleDate = lv.LeaveDate
where StdWorkingTimeMi is not null and ta1.IsLeaveStatus3 <> 1

-- thi?u vào ho?c ra mà gi? vào ho?c ra quá cách xa so v?i m?c c?a ca

-- Hoa thom toa huong xa
SELECT EmployeeID, ScheduleDate, ScheduleDate + 1 as FromDate,ScheduleDate+7 as ToDate,ShiftCode, ROW_NUMBER() OVER (PARTITION BY EmployeeID order by EmployeeId, ScheduleDate) STT ,RatioMatch
into #tblBloomFlavour
FROM #tblShiftDetectorMatched where Approved = 1
update b1 set ToDate = b2.ScheduleDate - 1 from #tblBloomFlavour b1 inner join #tblBloomFlavour b2 on b1.EmployeeId = b2.EmployeeId and b1.STT = b2.STT - 1
where b1.ToDate > b1.FromDate


INSERT INTO #tblShiftDetectorMatched(EmployeeId,ScheduleDate,ShiftCode,RatioMatch,WorkStart,WorkEnd
 ,BreakStart,BreakEnd

 ,OTBeforeStart,OTBeforeEnd
 ,OTAfterStart,OTAfterEnd
 ,HolidayStatus,Approved
 ,AttStart, AttEnd
)

SELECT p.EmployeeID,p.ScheduleDate,p.ShiftCode1,10000, dateadd(mi,ss.WorkStartMi, p.ScheduleDate), dateadd(mi,ss.WorkEndMi, p.ScheduleDate)
 , dateadd(mi,ss.BreakStartMi, p.ScheduleDate), dateadd(mi,ss.BreakEndMi, p.ScheduleDate)
 , dateadd(mi,ss.OTBeforeStartMi, p.ScheduleDate), dateadd(mi,ss.OTBeforeEndMi, p.ScheduleDate)
 , dateadd(mi,ss.OTAfterStartMi, p.ScheduleDate), dateadd(mi,ss.OTAfterEndMi, p.ScheduleDate)
 ,ws.HolidayStatus,ws.Approved
 ,p.AttStart1, p.AttEnd2
FROM #tblWSchedule ws inner join #tblWorking2ShiftADay_Detect p on ws.EmployeeID = p.EmployeeID and ws.ScheduleDate = p.ScheduleDate
left join #tblShiftSetting ss on ws.ShiftCode = ss.ShiftCode
where
not exists (select 1 from #tblShiftDetectorMatched m where m.EmployeeID = ws.EmployeeId and m.ScheduleDate = ws.ScheduleDate )
 DELETE D FROM #tblShiftDetector D WHERE EXISTS (SELECT 1 FROM #tblShiftDetectorMatched M WHERE M.EmployeeId = D.EmployeeId AND M.ScheduleDate = D.ScheduleDate)


-------------------------------------B?t d?u nh?n d?ng ca--------------------------------------------
begin -- bat dau nhan dang ca
select * into #tblShiftDetector_NeedUpdate from #tblShiftDetector where 1=0
--create nonclustered index indextblShiftDetector_NeedUpdate on #tblShiftDetector_NeedUpdate(EmployeeID,ScheduleDate,AttStart,AttEnd)
StartShiftDetector:
-- AttStart, AttEnd
UPDATE ws set WorkStart = dateadd(mi,ss.WorkStartMi, ws.ScheduleDate), WorkEnd = dateadd(mi,ss.WorkEndMi, ws.ScheduleDate), BreakStart = dateadd(mi,ss.BreakStartMi, ws.ScheduleDate), BreakEnd = dateadd(mi,ss.BreakEndMi, ws.ScheduleDate)
,isNightShift = case when ss.WorkEndMi > 1440 then 1 else 0 end
,isOfficalShift = ISNULL(ss.isOfficalShift,0)
,WorkStartMi = ss.WorkStartMi, WorkEndMi = ss.WorkEndMi
,BreakStartMi = ss.BreakStartMi, BreakEndMi = ss.BreakEndMi
,WorkStartSMi = ss.WorkStartStatisticMi, WorkEndSMi = ss.WorkEndStatisticMi
,WorkStartEMi = ss.WorkStartStatisticMi, WorkEndEMi = ss.WorkEndStatisticMi
FROM #tblShiftDetector ws
inner join #tblShiftSetting ss on ws.ShiftCode = ss.ShiftCode

--lấy thống kê ca dựa trên nhân viên

if(@DO_NOT_USE_InOutStatistic = 0)
begin
 update ws set WorkStartEMi = case when WorkStartEMi > ss.SwipeTimeIn + 5 then SwipeTimeIn else WorkStartEMi end ,WorkEndEMi = case when ss.SwipeTimeOut - WorkEndEMi > 5 then ss.SwipeTimeOut else WorkEndEMi end
 FROM #tblShiftDetector ws inner join #tblShiftDetector_InOutStatistic ss on ws.ShiftCode = ss.ShiftCode and ws.EmployeeID = ss.EmployeeID
 WHERE SS.ismax = 1
end


update #tblShiftDetector set TIMEINBEFORE = DATEADD(MINUTE,-@TA_TIMEINBEFORE,WorkStart)
, TIMEOUTAFTER = DATEADD(hour,case when isNightShift = 1 and @TA_TIMEOUTAFTER > 14 then 14 else @TA_TIMEOUTAFTER end,WorkStart)
, INOUT_MINIMUM = @TA_INOUT_MINIMUM
declare @RepeatTime int = 0

update #tblShiftDetector set IsLeaveStatus3 = 0
update ta1 set IsLeaveStatus3 = 1
 from #tblShiftDetector ta1
 inner join #tblLvHistory lv on lv.EmployeeID = ta1.EmployeeId and lv.LeaveDate = ta1.ScheduleDate
 and lv.LeaveStatus = 3

if(OBJECT_ID('sp_ShiftDetector_FinishTimeInTimeOutRange' )is null)
begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_FinishTimeInTimeOutRange
(
  @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)
as
begin
SET NOCOUNT ON;
end')
end
set @StopUpdate = 0
-- Goi thu thu thuc customize import de ap dung cho tung khach hang rieng biet
exec sp_ShiftDetector_FinishTimeInTimeOutRange @StopUpdate output ,@LoginID,@FromDate,@ToDate


update #tblShiftDetector set AttEndYesterdayFixedTblHasta = 0,AttStartTomorrowFixedTblHasta = 0
truncate table #tblPrevMatch
insert into #tblPrevMatch(EmployeeId,ShiftCode,ScheduleDate,AttStart,AttEnd,isNightShift,HolidayStatus,IsLeaveStatus3,Prevdate,NextDate)
select EmployeeId,ShiftCode,ScheduleDate,AttStart,AttEnd,isNightShift,HolidayStatus ,IsLeaveStatus3,DATEADD(day,-1,ScheduleDate),DATEADD(day,1,ScheduleDate)
from #tblShiftDetectorMatched
truncate table #tblHasTA_Fixed
truncate table #tblShiftDetector_NeedUpdate


insert into #tblHasTA_Fixed

select * from #tblHasTA where TAStatus = 3 or Attdate < @FromDate

insert into #tblShiftDetector_NeedUpdate
select * from #tblShiftDetector


declare @count int =0-- (select count(1) from #tblShiftDetector_NeedUpdate)
--declare @count1 int = (select count(1) from #tblPrevMatch)


truncate table #tblShiftDetector


StartRepeat:

--set @count = (select count(1) from #tblShiftDetector_NeedUpdate)
--set @count1 = (select count(1) from #tblPrevMatch)
--print '------------------------'
--print @RepeatTime
--print 'NeedUpdate'
--print @count set @sysDatetime = SYSDATETIME()
--print 'PrevMatch'
--print @count set @sysDatetime = SYSDATETIME()1
--print 'Prev Duration'
--set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
--print @count set @sysDatetime = SYSDATETIME()
--print @Re_Process
--set @sysDatetime = SYSDATETIME()
--print '------------------------'
if(@RepeatTime > 50)
begin
 select * from #tblShiftDetector_NeedUpdate order by ScheduleDate
 select * from #tblShiftDetectorMatched order by ScheduleDate
 select * from #tblPrevMatch order by ScheduleDate
end
/*print 'x--------------------------------------------------------x1'

print 'z--------------------------------------------------------z'*/


-- gio ra hom qua va gio vao hom sau
update m1 set AttEndYesterday = isnull(m2.AttEnd, dateadd(HOUR,-10,m1.WorkStart))
,ShiftCodeYesterday = m2.ShiftCode,isNightShiftYesterday = case when m2.AttStart is not null then m2.isNightShift else 0 end
from #tblShiftDetector_NeedUpdate m1
inner join #tblPrevMatch m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.NextDate
and m2.IsLeaveStatus3 =0
where m1.AttEndYesterdayFixedTblHasta <> 1 and
(m2.AttEnd is not null or m1.Holidaystatus >0
or m1.IsLeaveStatus3 = 1)

/*print 'x--------------------------------------------------------x2'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/


update m1 set AttStartTomorrow = isnull(m2.AttStart,DATEADD(hour,16,m1.WorkEnd))
from #tblShiftDetector_NeedUpdate m1
inner join #tblPrevMatch m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.Prevdate and m2.IsLeaveStatus3 = 0
where m1.AttStartTomorrowFixedTblHasta <> 1 and m2.AttStart is not null


update m1 set AttEndYesterday = m2.AttEnd, AttEndYesterdayFixedTblHasta =1
from #tblShiftDetector_NeedUpdate m1
inner join #tblHasTA_Fixed m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.NextDate
and m2.AttEnd is not null
where m1.AttEndYesterdayFixedTblHasta <> 1
update m1 set AttEndYesterday = m2.AttEnd from #tblShiftDetector_NeedUpdate m1 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate + 1
where m1.AttEndYesterday is null and m2.AttEnd is not null

update m1 set ShiftCodeYesterday = m2.ShiftCode
from #tblShiftDetector_NeedUpdate m1
inner join #tblHasTA_Fixed m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.NextDate


where m1.ShiftCodeYesterday is null

update m1 set isNightShiftYesterday = m2.isNightShift
from #tblShiftDetector_NeedUpdate m1
inner join #tblHasTA_Fixed m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.NextDate
where m2.AttStart is not null and m2.AttEnd is not null
 and m1.ShiftCodeYesterday is null --and (m2.TAStatus = 3 or m2.AttDate < @FromDate)

-- update m1 set ShiftCodeYesterday = m2.ShiftCode from #tblShiftDetector m1 inner join #tblWSchedule m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate+1 where m2.DateStatus = 3
--ca hom qua da dc duyet, hoac Nhan vien nghi ca ngay thi lay ca hom qua ap cho ca hom nay
update m1 set ShiftCodeYesterday = m2.ShiftCode
from #tblShiftDetector_NeedUpdate m1
inner join #tblWSchedule m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.NextDAte
where ((m2.DateStatus = 3 or m2.Approved = 1)

 or m1.IsLeaveStatus3 = 3)

 update m1 set AttStartTomorrow = isnull(m2.AttStart,DATEADD(hour,16,m1.WorkEnd))
 from #tblShiftDetector_NeedUpdate m1
 inner join #tblHasTA m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.PrevDate
 where m2.AttStart is not null and (m2.TAStatus = 3 )

 update m1 set AttStartTomorrow = isnull(m2.AttStart,DATEADD(hour,16,m1.WorkEnd))
 from #tblShiftDetector_NeedUpdate m1
 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate-1
 where m2.AttStart is not null


 -- xac dinh gio vao ra do hom qua và ngày mai dã du?c fix c? d?nh chua
update m1 set AttEndYesterdayFixed = 1
from #tblShiftDetector_NeedUpdate m1
inner join #tblWSchedule m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.NextDate
where m2.DateStatus = 3


update m1 set AttStartTomorrowFixed = 1
from #tblShiftDetector_NeedUpdate m1
inner join #tblWSchedule m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.PrevDate
where m2.DateStatus = 3

 update #tblShiftDetector_NeedUpdate set AttEndYesterday = case when AttEndYesterday is null then dateadd(HOUR,-10,WorkStart) else AttEndYesterday end , AttStartTomorrow = case when AttStartTomorrow is null then DATEADD(hour,12,WorkEnd) else AttStartTomorrow end
 where AttEndYesterday is null or AttStartTomorrow is null

 -------------------------------------------------------------------------------------------------------------
 if(OBJECT_ID('sp_ShiftDetector_AttStartAttEnd' )is null)
 begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_AttStartAttEnd
(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
 ,@IN_OUT_TA_SEPARATE bit
)
as
begin
SET NOCOUNT ON;
end')
end
 set @StopUpdate = 0
exec sp_ShiftDetector_AttStartAttEnd @StopUpdate output ,@LoginID,@FromDate,@ToDate,@IN_OUT_TA_SEPARATE

if @StopUpdate = 0
 begin

--1. gà què an quanh c?i xay
-- ga que an quan coi xay
update #tblShiftDetector_NeedUpdate set AttStart = tmp.AttTime,StateIn = AttState
from #tblShiftDetector_NeedUpdate m
inner join (
SELECT ROW_NUMBER()over(partition by m.EmployeeId,m.ShiftCode,m.ScheduleDate order by AttTime asc) as STT
  , m.EmployeeId, m.ScheduleDate,m.ShiftCode, AttTime,AttState
FROM #tblShiftDetector_NeedUpdate m
inner join #tblTmpAttend t
on m.EmployeeId = t.EmployeeID and
 t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
and (ForceState = 0 or AttState = 1)
where m.AttStart is null
and abs(DATEDIFF(mi,m.WorkStart,t.AttTime))<=60

) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate and m.ShiftCode = tmp.ShiftCode
and STT = 1



/*print 'x--------------------------------------------------------x10'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/



-- voi phan biet vao ra thi lay xa hon chut neu khop trang thai vao
if @IN_OUT_TA_SEPARATE = 1
begin
 update #tblShiftDetector_NeedUpdate set AttStart = tmp.AttTime,StateIn = AttState
 from #tblShiftDetector_NeedUpdate m inner join (
  SELECT ROW_NUMBER()over(partition by m.EmployeeId,m.ShiftCode,m.ScheduleDate order by AttTime asc) as STT
    , m.EmployeeId, m.ScheduleDate,m.ShiftCode, AttTime,AttState
  FROM #tblShiftDetector_NeedUpdate m
  inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID and
  t.AttState = 1 and ISNULL(m.FixedAtt,0) = 0
  and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
  and t.AttTime between m.TIMEINBEFORE and m.TIMEOUTAFTER
  and t.attTime < dateadd(hour,2,WorkStart)
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate and m.ShiftCode = tmp.ShiftCode
 and STT= 1

 update #tblShiftDetector_NeedUpdate set AttStart = tmp.AttTime,StateIn = AttState
 from #tblShiftDetector_NeedUpdate m inner join (
  SELECT ROW_NUMBER()over(partition by m.EmployeeId,m.ShiftCode,m.ScheduleDate order by AttTime asc) as STT
    , m.EmployeeId, m.ScheduleDate,m.ShiftCode, AttTime,AttState

  FROM #tblShiftDetector_NeedUpdate m
  inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID and
  t.AttState = 1 and ISNULL(m.FixedAtt,0) = 0

  and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
  and t.AttTime between m.TIMEINBEFORE and m.TIMEOUTAFTER
  and t.attTime < WorkEnd
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate and m.ShiftCode = tmp.ShiftCode
 and STT= 1
 where AttStart is null

END

/*print 'x--------------------------------------------------------x11'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/

-- 2. Ðói thì di làm an xa
update #tblShiftDetector_NeedUpdate set AttStart = tmp.AttTime ,StateIn = AttState
from #tblShiftDetector_NeedUpdate m
inner join (
SELECT ROW_NUMBER()over(partition by m.EmployeeId,m.ShiftCode,m.ScheduleDate order by AttTime asc) as STT
  , m.EmployeeId, m.ScheduleDate,m.ShiftCode,AttTime,AttState
FROM #tblShiftDetector_NeedUpdate m
inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
and (ForceState = 0 or AttState = 1)
and t.AttTime between m.TIMEINBEFORE and m.TIMEOUTAFTER
and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
where m.AttStart is null
and abs(DATEDIFF(mi,m.WorkStart,t.AttTime))<=330
--group by m.EmployeeId, m.ScheduleDate,m.ShiftCode
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate and m.ShiftCode = tmp.ShiftCode
and STT =1

/*print 'x--------------------------------------------------------x12'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/

-- AttEnd
-- 1. ga que an quan cuoi xay
 update #tblShiftDetector_NeedUpdate set AttEnd = tmp.AttTime ,StateOut = AttState
 from #tblShiftDetector_NeedUpdate m inner join (
 SELECT ROW_NUMBER()over(partition by m.EmployeeId,m.ShiftCode,m.ScheduleDate order by AttTime desc) as STT
  , m.EmployeeId, m.ScheduleDate,m.ShiftCode,AttTime,AttState
 FROM #tblShiftDetector_NeedUpdate m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where m.AttEnd is null
 and (ForceState = 0 or AttState = 2)
 and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
 and abs(DATEDIFF(mi,m.WorkEnd,t.AttTime))<=60
 --group by m.EmployeeId, m.ScheduleDate,m.ShiftCode
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate and m.ShiftCode = tmp.ShiftCode
and STT = 1


update #tblShiftDetector_NeedUpdate set AttEnd = tmp.AttTime ,StateOut = AttState
 from #tblShiftDetector_NeedUpdate m inner join (
 SELECT ROW_NUMBER()over(partition by m.EmployeeId,m.ShiftCode,m.ScheduleDate order by AttTime desc) as STT
  , m.EmployeeId, m.ScheduleDate,m.ShiftCode,AttTime,AttState
 FROM #tblShiftDetector_NeedUpdate m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where m.AttEnd < m.WorkEnd
 and (t.ForceState = 0 or t.AttState = 2)
 and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
  and DATEDIFF(mi,m.WorkEnd,t.AttTime) <= 120
 --group by m.EmployeeId, m.ScheduleDate,m.ShiftCode
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate and m.ShiftCode = tmp.ShiftCode
and STT = 1


   /*print 'x--------------------------------------------------------x13'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/

if @IN_OUT_TA_SEPARATE = 1
begin
 update #tblShiftDetector_NeedUpdate set AttEnd = tmp.AttTime ,StateOut= 2
 from #tblShiftDetector_NeedUpdate m
 inner join (

  SELECT m.EmployeeId, m.ScheduleDate,m.ShiftCode, max(t.AttTime) AttTime
  FROM #tblShiftDetector_NeedUpdate m inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
  where t.AttState = 2 and ISNULL(FixedAtt,0) = 0
   and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
   and t.AttTime between m.TIMEINBEFORE and m.TIMEOUTAFTER
   and t.attTime >dateadd(hour,-6,WorkEnd)
  group by m.EmployeeId, m.ScheduleDate,m.ShiftCode
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate and m.ShiftCode = tmp.ShiftCode
end
/*print 'x--------------------------------------------------------x14'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/

-- 2. Ðói thì di làm an xa
update #tblShiftDetector_NeedUpdate set AttEnd = tmp.AttTime ,StateOut = AttState
from #tblShiftDetector_NeedUpdate m inner join (
SELECT ROW_NUMBER()over(partition by m.EmployeeId,m.ShiftCode,m.ScheduleDate order by AttTime desc) as STT
  , m.EmployeeId, m.ScheduleDate,m.ShiftCode, AttTime,AttState
 FROM #tblShiftDetector_NeedUpdate m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where
 m.AttEnd is null
 and (ForceState = 0 or AttState = 2)
 and (m.AttStart is null or (t.AttTime > m.AttStart and DATEDIFF(mi,m.AttStart,t.AttTime) >= 20))
 and t.AttTime between m.TIMEINBEFORE and m.TIMEOUTAFTER
 and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
 and abs(DATEDIFF(mi,m.WorkEnd,t.AttTime)) <=320
--group by m.EmployeeId, m.ScheduleDate,m.ShiftCode
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate and m.ShiftCode = tmp.ShiftCode
and STT= 1

-- AttStart
-- 2. Ðói thì di làm an xa
-- 2. doi thi di lam an xa
update #tblShiftDetector_NeedUpdate set AttStart = tmp.AttTime ,StateIn = AttState
from #tblShiftDetector m
inner join (
SELECT ROW_NUMBER()over(partition by m.EmployeeId,m.ShiftCode,m.ScheduleDate order by AttTime asc) as STT
 , m.EmployeeId, m.ScheduleDate,m.ShiftCode, AttTime , AttState
FROM #tblShiftDetector_NeedUpdate m
inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
where m.AttStart is null
and (ForceState = 0 or AttState = 1)
and (t.AttTime < m.AttEnd or m.AttEnd is null)
and t.AttTime between m.TIMEINBEFORE and m.TIMEOUTAFTER
and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
--group by m.EmployeeId, m.ScheduleDate,m.ShiftCode
) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate and m.ShiftCode = tmp.ShiftCode
/*print 'x--------------------------------------------------------x15'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/


-- quên b?m 1 d?u và AttStart dang trùng AttEnd thì xác d?nh l?i cho dúng anh nào vào anh nào ra
-- tru?ng h?p nhân viên s?a l?i gi? vào ra, nen bi du thua attTime
update #tblShiftDetector_NeedUpdate set AttStart = case when DATEDIFF(mi,WorkStart,AttStart) < 240 and (isnull(AttEndYesterdayFixed,0) = 0 or DATEDIFF(mi,AttEndYesterday,AttStart) > 120) then AttStart else null end ,AttEnd = case when DATEDIFF(mi,WorkEnd,AttEnd) >=-240 and (isnull(AttStartTomorrowFixed,0) = 0 or DATEDIFF(mi,AttStartTomorrow,AttStart) < 120) then AttEnd else null end ,StateIn = 0,StateOut = 0
from #tblShiftDetector_NeedUpdate where AttStart = AttEnd --and EmployeeId = 'HLS001'

end




-- ngh? c? ngày mà b?m thi?u d?u thì b?
update m set-- AttStart = null, AttEnd = null,
StateIn = 0,
StateOut = 0
from #tblShiftDetector_NeedUpdate m where (m.AttStart is null or m.AttEnd is null)
--and (HolidayStatus > 0 or IsLeaveStatus3 = 1)

and (IsLeaveStatus3 = 1)

/*print 'x--------------------------------------------------------x16'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/


update #tblShiftDetector_NeedUpdate set AttStartMi = datepart(hour,AttStart)*60 + DATEPART(minute,AttStart)
+(datediff(day,ScheduleDate,AttStart) * 1440)
, AttEndMi = datepart(hour,AttEnd)*60 + DATEPART(minute,AttEnd)

update #tblShiftDetector_NeedUpdate set AttEndMi = 1440+AttEndMi where DATEDIFF(day,ScheduleDate,AttEnd) = 1



if @MATERNITY_LATE_EARLY_OPTION = 1
 update ta1 set AttStartMi = case when AttStartMi > WorkStartMi then case when AttStartMi - WorkStartMi <= 30 then WorkStartMi else AttStartMi - @MATERNITY_MUNITE end else AttStartMi end
 from #tblShiftDetector_NeedUpdate ta1 where EmployeeStatusID in (10,11) and AttStartMi is not null and AttEndMi is not null
else
if @MATERNITY_LATE_EARLY_OPTION = 2
 update ta1 set AttEndMi = case when AttEndMi < WorkEndMi then case when WorkEndMi - AttStartMi <= 30 then WorkEndMi else AttEndMi + @MATERNITY_MUNITE end else AttEndMi end
 from #tblShiftDetector_NeedUpdate ta1 where EmployeeStatusID in (10,11) and AttStartMi is not null and AttEndMi is not null
else
if @MATERNITY_LATE_EARLY_OPTION = 3
 update ta1 set AttEndMi = case when WorkEndMi- AttEndMi >= AttStartMi - WorkStartMi and AttEndMi < WorkEndMi then case when WorkEndMi- AttStartMi <= 30 then WorkEndMi else AttEndMi + @MATERNITY_MUNITE end else AttEndMi end
  ,AttStartMi = case when WorkEndMi- AttEndMi < AttStartMi - WorkStartMi and AttStartMi > WorkStartMi then case when AttStartMi - WorkStartMi <= 30 then WorkStartMi else AttStartMi - @MATERNITY_MUNITE end else AttStartMi end
 from #tblShiftDetector_NeedUpdate ta1 where EmployeeStatusID in (10,11) and AttStartMi is not null and AttEndMi is not null


  -- UPDATE LATE_PERMIT AND EARLY_PERMIT

 update sd
 set sd.Late_Permit = case when p.LATE_PERMIT is not null then p.LATE_PERMIT
         when sc.LATE_PERMIT is not null then sc.LATE_PERMIT
         when dp.LATE_PERMIT is not null then dp.LATE_PERMIT else d.LATE_PERMIT end,
 sd.Early_Permit = case when p.EARLY_PERMIT is not null then p.EARLY_PERMIT
         when sc.EARLY_PERMIT is not null then sc.EARLY_PERMIT
         when dp.EARLY_PERMIT is not null then dp.EARLY_PERMIT else d.EARLY_PERMIT end

 from #tblShiftDetector_NeedUpdate sd
 left join #tblEmployeeList s on s.EmployeeID = sd.EmployeeId
 left join tblDivision d on d.DivisionID = s.DivisionID
 left join tblDepartment dp on dp.DepartmentID = s.DepartmentID
 left join tblSection sc on sc.SectionID = s.SectionID
 left join tblPosition p on p.PositionID = s.PositionID

 --update sd set AttStartMi = case when AttStartMi < WorkEndMi + Late_Permit then WorkEndMi else AttStartMi end from #tblShiftDetectorMatched sd
/*
update sd
set AttStartMi = case when AttStartMi BETWEEN WorkStartMi and WorkStartMi + case when Late_Permit < 10 then Late_Permit else 10 end then WorkStartMi else AttStartMi end,
    AttEndMi = case when AttEndMi BETWEEN WorkEndMi - case when Early_Permit < 10 then Early_Permit else 10 end AND WorkEndMi then  WorkEndMi else AttEndMi end
from #tblShiftDetector_NeedUpdate sd
*/

update #tblShiftDetector_NeedUpdate
set WorkingTimeMi =
 case
 when AttEndMi >= WorkEndMi then WorkEndMi
 when AttEndMi >= BreakEndMi then AttEndMi

 when AttEndMi >= BreakStartMi then BreakStartMi
 when AttEndMi >= WorkStartMi then AttEndMi else WorkStartMi end
- case
 when AttStartMi <= WorkStartMi then WorkStartMi
 when AttStartMi < BreakStartMi then AttStartMi
 when AttStartMi <= BreakEndMi then BreakEndMi
 when AttStartMi <= WorkEndMi then AttStartMi else WorkEndMi end
,StdWorkingTimeMi = WorkEndMi - WorkStartMi - (BreakEndMi - BreakStartMi)
where AttStartMi is not null and AttEndMi is not null

update #tblShiftDetector_NeedUpdate set StdWorkingTimeMi = WorkEndMi - WorkStartMi - (BreakEndMi - BreakStartMi)
/*print 'x--------------------------------------------------------x18'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/


update m set StdWorkingTimeMi = StdWorkingTimeMi - lv.LvAmount*60.0
 from #tblShiftDetector_NeedUpdate m
 inner join (select EmployeeID,LeaveDate, sum(LvAmount) LvAmount
from #tblLvHistory where LeaveCategory = 1 group by EmployeeID,LeaveDate) lv on lv.EmployeeID = m.EmployeeId and m.ScheduleDate = lv.LeaveDate
where StdWorkingTimeMi is not null and m.IsLeaveStatus3 <> 1

update #tblShiftDetector set StdWorkingTimeMi = 480 where -- NeedUpdate =1 and
 StdWorkingTimeMi <= 0


UPDATE #tblShiftDetector_NeedUpdate set WorkingTimeMi = WorkingTimeMi - (BreakEndMi - BreakStartMi)
 WHERE BreakStartMi < BreakEndMi AND AttStartMi < BreakStartMi AND AttEndMi > BreakEndMi
and AttStartMi is not null and AttEndMi is not null


/*print 'x--------------------------------------------------------x19'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/


if @MATERNITY_LATE_EARLY_OPTION = 0
 UPDATE #tblShiftDetector_NeedUpdate SET WorkingTimeMi = case when WorkingTimeMi + @MATERNITY_MUNITE >= StdWorkingTimeMi then StdWorkingTimeMi else WorkingTimeMi + @MATERNITY_MUNITE end
 from #tblShiftDetector_NeedUpdate d
 where d.EmployeeStatusID in (10,11) and AttStartMi is not null and AttEndMi is not null

UPDATE #tblShiftDetector_NeedUpdate set WorkingTimeMi = StdWorkingTimeMi where WorkingTimeMi >= StdWorkingTimeMi
--s?a ch? này xíu thêm cái t? l? vào cho nó máu
UPDATE ta1 set WorkingTimeMi = cast(WorkingTimeMi as float) * (ta2.STDWorkingTime_SS -isnull(lv.LvAmount*60.0,0)) / ta1.StdWorkingTimeMi
from #tblShiftDetector_NeedUpdate ta1
inner join #tblShiftSetting ta2 on ta1.ShiftCode = ta2.ShiftCode
and ta1.StdWorkingTimeMi <> ta2.STDWorkingTime_SS
and ta1.Workingtimemi >0
left join (select EmployeeID,LeaveDate, sum(LvAmount) LvAmount
 from #tblLvHistory where LeaveCategory = 1 group by EmployeeID,LeaveDate) lv
 on lv.EmployeeID = ta1.EmployeeId and ta1.ScheduleDate = lv.LeaveDate
where StdWorkingTimeMi is not null and ta1.IsLeaveStatus3 <> 1

/*print 'x--------------------------------------------------------x20'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/


-- ch?m di?m
update #tblShiftDetector_NeedUpdate set InInterval = case when AttStart is null then null else DATEDIFF(mi, AttStart,WorkStart) end, OutInterval = case when AttEnd is null then null else DATEDIFF(mi,WorkEnd,AttEnd) end
-- che do lam 7h/ngay maternity
UPDATE #tblShiftDetector_NeedUpdate SET InInterval = InInterval + @MATERNITY_MUNITE
from #tblShiftDetector_NeedUpdate d
where d.EmployeeStatusID in (10,11) and InInterval > 0 and OutInterval > 0
/*print 'x--------------------------------------------------------x21'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/



UPDATE #tblShiftDetector_NeedUpdate SET InInterval = 0
from #tblShiftDetector_NeedUpdate d
where d.EmployeeStatusID in (10,11) and InInterval < -30 and @MATERNITY_MUNITE + InInterval >= 0 and OutInterval > 0

UPDATE #tblShiftDetector_NeedUpdate SET OutInterval = 0
from #tblShiftDetector_NeedUpdate d
where d.EmployeeStatusID in (10,11) and OutInterval < -30 and @MATERNITY_MUNITE + OutInterval >= 0 and InInterval > 0

UPDATE #tblShiftDetector_NeedUpdate SET InInterval = InInterval + case when InInterval between -35 and 0 then @MATERNITY_MUNITE/2 else @MATERNITY_MUNITE end
from #tblShiftDetector_NeedUpdate d
where d.EmployeeStatusID in (10,11) and d.InInterval is not null and d.InInterval < -20

/*print 'x--------------------------------------------------------x22'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/


UPDATE #tblShiftDetector_NeedUpdate SET OutInterval = OutInterval + case when OutInterval between -35 and 0 then @MATERNITY_MUNITE/2 else @MATERNITY_MUNITE end
from #tblShiftDetector_NeedUpdate d
where d.EmployeeStatusID in (10,11) and d.OutInterval is not null and d.OutInterval < -20

update #tblShiftDetector_NeedUpdate set InIntervalS = abs(case when AttStart is null then null else AttStartMi - WorkStartSMi end), OutIntervalS = abs(case when AttEnd is null then null else WorkEndSMi-AttEndMi end)
--update #tblShiftDetector_NeedUpdate set
,
 InIntervalE = abs(case when AttStart is null then null else AttStartMi - WorkStartEMi end), OutIntervalE = abs(case when AttEnd is null then null else WorkEndEMi - AttEndMi end)

 -- n?u có tang ca sau
update u set OutIntervalS = u.AttEndMi - s.OTAfterEndMi from #tblShiftDetector_NeedUpdate u inner join #tblShiftSetting s on u.ShiftCode = s.ShiftCode
where u.AttEndMi is not null and u.OutIntervalS > (u.AttEndMi - s.OTAfterEndMi) and (u.AttEndMi - s.OTAfterEndMi) > -1

-- L?y Interval sát v?i m?c ca nh?t, 2008 khong co lenh IIF() ::(
--update #tblShiftDetector_NeedUpdate set InInterval = case when InIntervalS > InIntervalE then InIntervalE else InIntervalS end where abs(InInterval) - 30 > InIntervalS or abs(InInterval) -30 > InIntervalE
update #tblShiftDetector_NeedUpdate set InInterval = case when InIntervalS > InIntervalE then InIntervalE else InIntervalS end where abs(InInterval) > InIntervalS or abs(InInterval) > InIntervalE
--update #tblShiftDetector_NeedUpdate set OutInterval = case when OutIntervalS > OutIntervalE then OutIntervalE else OutIntervalS end where abs(OutInterval)-30 > OutIntervalS or abs(OutInterval)-30 > OutIntervalE
update #tblShiftDetector_NeedUpdate set OutInterval = case when OutIntervalS > OutIntervalE then OutIntervalE else OutIntervalS end
where (abs(OutInterval) > OutIntervalS or abs(OutInterval) > OutIntervalE) and @IgnoreTimeOut_ShiftDetector = 0



if(@DO_NOT_USE_InOutStatistic = 0)
begin
 update d set InInterval = 1, OutInterval = 1 from #tblShiftDetector_NeedUpdate d
 where (d.InInterval > 10 or d.OutInterval > 10)
 and exists (select 1 from #tblShiftDetector_InOutStatistic S
  inner join #tblDivDepSecPos h on s.DepartmentID = h.DepartmentID
 where s.ismax = 1 and CountTime > 14 and d.ShiftCode = s.ShiftCode and abs(d.AttStartMi - s.SwipeTimeIn) < 6 and abs(d.AttEndMi - s.SwipeTimeOut) < 6
 and d.ScheduleDate between h.ChangedDate and h.EndDate
 and d.EmployeeId = h.EmployeeID
 )
 update d set InInterval = 1, OutInterval = 1 from #tblShiftDetector_NeedUpdate d
 where (d.InInterval > 10 or d.OutInterval > 10)
 and exists (select 1 from #tblShiftDetector_InOutStatistic s inner join #tblDivDepSecPos h on s.SectionID = h.SectionID
 where s.ismax = 1 and CountTime > 14 and d.ShiftCode = s.ShiftCode and abs(d.AttStartMi - s.SwipeTimeIn) < 6 and abs(d.AttEndMi - s.SwipeTimeOut) < 6
 and d.ScheduleDate between h.ChangedDate and h.EndDate
 and d.EmployeeId = h.EmployeeID
 )

 update d set InInterval = 1, OutInterval = 1 from #tblShiftDetector_NeedUpdate d

 where (d.InInterval > 10 or d.OutInterval > 10)
 and exists (select 1 from #tblShiftDetector_InOutStatistic s inner join #tblDivDepSecPos h on s.EmployeeTypeID = h.EmployeeTypeID
 where s.ismax = 1 and CountTime > 14 and d.ShiftCode = s.ShiftCode and abs(d.AttStartMi - s.SwipeTimeIn) < 6 and abs(d.AttEndMi - s.SwipeTimeOut) < 6
 and d.ScheduleDate between h.ChangedDate and h.EndDate
 and d.EmployeeId = h.EmployeeID
 )
end


/*print 'x--------------------------------------------------------x24'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())

print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/

-- nghi nua buoi

update m set InInterval = InInterval + lv.LvAmount*60.0 + case when m.AttStart > m.BreakEnd then DATEDIFF(mi,m.BreakStart,m.BreakEnd) else 0 end
 from #tblShiftDetector_NeedUpdate m
 inner join #tblLvHistory lv on lv.EmployeeID = m.EmployeeId and m.ScheduleDate = lv.LeaveDate
where --NeedUpdate=1 and
 InInterval is not null and lv.LeaveStatus in(1,4)

 update m set OutInterval = OutInterval + lv.LvAmount*60.0 + case when m.AttEnd < m.BreakEnd then DATEDIFF(mi,m.BreakStart,m.BreakEnd) else 0 end from #tblShiftDetector_NeedUpdate m inner join #tblLvHistory lv on lv.EmployeeID = m.EmployeeId and m.ScheduleDate = lv.LeaveDate
where --NeedUpdate=1 and
OutInterval is not null and lv.LeaveStatus in(2,5) and @IgnoreTimeOut_ShiftDetector = 0

/*print 'x--------------------------------------------------------x241'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/

-- Xu ly nhung cap chua co diem
--update #tblShiftDetector_NeedUpdate set InInterval = case when StdWorkingTimeMi is null then 500 else StdWorkingTimeMi end where AttStart is null
update #tblShiftDetector_NeedUpdate set InInterval = 480 where AttStart is null
--update #tblShiftDetector_NeedUpdate set OutInterval = case when StdWorkingTimeMi is null then 500 else StdWorkingTimeMi end where AttEnd is null and @IgnoreTimeOut_ShiftDetector = 0
update #tblShiftDetector_NeedUpdate set OutInterval = 480 where AttEnd is null and @IgnoreTimeOut_ShiftDetector = 0
/*print 'x--------------------------------------------------------x242'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/

update #tblShiftDetector_NeedUpdate set OutInterval = isnull(StdWorkingTimeMi,500),OutIntervalE = isnull(StdWorkingTimeMi,500), OutIntervalS = isnull(StdWorkingTimeMi,500),WorkingTimeMi = StdWorkingTimeMi  where @IgnoreTimeOut_ShiftDetector = 1



UPDATE #tblShiftDetector_NeedUpdate SET InInterval = 0 where InInterval between @SHIFTDETECTOR_LATE_PERMIT*-1 and @SHIFTDETECTOR_IN_EARLY_USUALLY
UPDATE #tblShiftDetector_NeedUpdate SET OutInterval = 0 where OutInterval between @SHIFTDETECTOR_EARLY_PERMIT*-1 and 0

-- cham diem
-- ch?m di?m theo d? th? toán h?c, hàm logarit và hàm s? mu
update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch + (-91.18357565*log(InInterval)+591.0074141) where InInterval > 0
update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch + 500.1747978*POWER(1.05572192,InInterval) where InInterval <= 0

update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch + (-70*log(OutInterval)+400) where OutInterval > 0 and @IgnoreTimeOut_ShiftDetector = 0
update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch + 400*POWER(1.05572192,OutInterval) where OutInterval <= 0 and @IgnoreTimeOut_ShiftDetector = 0


if(OBJECT_ID('sp_ShiftDetector_beginUpdateLongShiftDeduct' )is null)
 begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_beginUpdateLongShiftDeduct
(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)
as
begin
 SET NOCOUNT ON;
end')
end
 set @StopUpdate = 0
 -- Goi thu thu thuc customize import de ap dung cho tung khach hang rieng biet
 exec sp_ShiftDetector_beginUpdateLongShiftDeduct @StopUpdate output ,@LoginID,@FromDate,@ToDate

if @StopUpdate = 0
begin
 update ta1 set RatioMatch -=(OutInterval) / 30* 50 from #tblShiftDetector_NeedUpdate ta1 WHERE StdWorkingTimeMi > 600 and AttEnd is not null --and OutInterval >= 30
 update ta1 set RatioMatch -=(InInterval) / 30* 50 from #tblShiftDetector_NeedUpdate ta1 WHERE StdWorkingTimeMi > 600 and Attstart is not null--and InInterval >= 30

end

 -- hành chính hi?m khi tang ca tru?c
 -- hanh chinh hiem khi tang ca truoc
UPDATE #tblShiftDetector_NeedUpdate
SET RatioMatch =
 CASE WHEN RatioMatch IS NULL THEN 550 -(ABS(InInterval)+ABS(OutInterval)) -- neu chua cho diem
   ELSE RatioMatch
     -- n?u là ca hành chính và vào s?m thì tr? di?m
     - CASE WHEN isOfficalShift = 1 AND InIntervalS IS NOT NULL AND InInterval > 30 THEN 50 * InInterval/30
            ELSE 0
   END
     +
     CASE WHEN OutInterval > (0 - @SHIFTDETECTOR_EARLY_PERMIT) AND AttEndMi - AttStartMi < 660 THEN CASE WHEN InInterval BETWEEN (0-@SHIFTDETECTOR_LATE_PERMIT) AND 11 THEN 200 WHEN InInterval BETWEEN 11 AND 20 THEN 100 ELSE 0 END
       ELSE 0  END -- Neu khop gio ra thi cong diem tuong ung, n?u kh?p gi? ra thì c?ng di?m tuong ?ng
     + isnull(WorkingTimeMi, 0) -- uu tien ca dai(cang dai cang suong), uu tiên ca dài (ca càng dài di?m càng cao)
     + CASE WHEN (WorkingTimeMi + @SHIFTDETECTOR_LATE_PERMIT) >= StdWorkingTimeMi THEN 270 ELSE 0 END
 END -(ABS(InInterval)+ABS(OutInterval))
 -- gặp ca dài (12h) mà đi làm không đủ thì phạt để quy về ca 8h
 update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch - StdWorkingTimeMi where StdWorkingTimeMi >=720 and WorkingTimeMi < StdWorkingTimeMi - 15
-- Ca dêm (ca 3) thường sẽ ra dúng giờ, nên uu tiên ca dêm ra dúng giờ (chỉ uu tiên khi có dủ giờ vào, giờ ra)
update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch + (-91.18357565*log(OutInterval)+591.0074141) where OutInterval between 1 and 10 and AttStart is not null and AttEnd is not null and WorkEndMi > 1440 and (InInterval < 60 or (WorkEndMi - WorkStartMi <500 and WorkStartMi - AttStartMi < 270 and InInterval < 270)) and @IgnoreTimeOut_ShiftDetector = 0

update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch + RatioMatch/2 where OutInterval = 0 and InInterval between -5 and 10 and WorkEndMi > 1440



--ca dài mà di s?m, v? mu?n thì b? tr? di?m d? uu tiên cho ca ng?n
-- ca dai ma di som ve muon, ve tre thi bi tru diem, uu tien cho ca ngan
UPDATE #tblShiftDetector_NeedUpdate SET RatioMatch = RatioMatch - isnull(WorkingTimeMi,0)
from #tblShiftDetector_NeedUpdate a --inner join #tblWSchedule ws on a.EmployeeId = ws.EmployeeID and a.ScheduleDate = ws.ScheduleDate
where a.WorkingTimeMi > 500 and InIntervalS > 45 and OutIntervalS > 45



-- ca 3 mà thieu dau ra thi coi nhu bo :)
update #tblShiftDetector_NeedUpdate set RatioMatch = case when RatioMatch > 400 then 400 else RatioMatch - 300 end
 where isNightShift =1 and AttEnd is null
and TIMEOUTAFTER < getdate()

/*print 'x--------------------------------------------------------x27'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/

if(OBJECT_ID('sp_ShiftDetector_WrongShiftProcess' )is null)
 begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_WrongShiftProcess

(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)
as
begin
SET NOCOUNT ON;
end')
end
 set @StopUpdate = 0

-- Goi thu thu thuc customize import de ap dung cho tung khach hang rieng biet
exec sp_ShiftDetector_WrongShiftProcess @StopUpdate output ,@LoginID,@FromDate,@ToDate
if @StopUpdate = 0 and @WrongShiftProcess_ShiftDetector = 1
begin
 -- ph?t n?ng l?i làm m?t d? li?u
 update d set RatioMatch = -500,isWrongShift = 1
  from #tblShiftDetector_NeedUpdate d
 inner join #tblShiftDetectorMatched m on d.employeeId = m.EmployeeID and d.ScheduleDate = m.ScheduleDate-1
 where
 exists (select 1 from #tblTmpAttend t where m.EmployeeId = t.EmployeeID and
 t.AttTime between d.TimeOutAfter and m.TIMEINBEFORE)

 update d set RatioMatch -=200,isWrongShift = 1
  from #tblShiftDetector_NeedUpdate d
  inner join

  (select m.EmployeeId,ScheduleDate+1 as ScheduleDate,max(AttEnd) AttEnd from #tblShiftDetector_NeedUpdate m
  group by EmployeeId,ScheduleDate
  ) ta1 on d.EmployeeId = ta1.EmployeeId and d.ScheduleDate = ta1.ScheduleDate
 where
 exists (select 1 from #tblTmpAttend t where d.EmployeeId = t.EmployeeID and
t.AttTime > ta1.AttEnd and t.AttTime <d.AttStart)

 update d set RatioMatch = -500,isWrongShift = 1
 from #tblShiftDetector_NeedUpdate d
 inner join #tblShiftDetectorMatched m on d.employeeId = m.EmployeeID and d.ScheduleDate = m.ScheduleDate + 1

 where
 exists (select 1 from #tblTmpAttend t where m.EmployeeId = t.EmployeeID and
 t.AttTime between case when d.ShiftCode = m.ShiftCode then dateadd(SECOND,1, m.TIMEOUTAFTER) else dateadd(MINUTE,240,m.AttEnd) end and dateadd(mi,-60, d.AttStart))

 -- ngay hom truoc nghi ca ngay ma hom sau bi mat gio cham cong do nhan sai ca
 update d set RatioMatch = -500,isWrongShift = 1
  from #tblShiftDetector_NeedUpdate d
 where
 (
 exists (select 1 from #tblLvHistory lv where lv.LeaveCategory = 1 and d.EmployeeId = lv.EmployeeID and lv.LeaveStatus = 3 and lv.LeaveDate = d.ScheduleDate -1)
 or exists (select 1 from (select * from #tblShiftDetector_NeedUpdate
 union all
 select * from #tblShiftDetector) l where d.EmployeeId = l.EmployeeID and l.HolidayStatus > 0 and l.AttStart is null and l.AttEnd is null and l.ScheduleDate = d.ScheduleDate -1)
 )
 and not exists (select 1 from #tblPrevMatch l
 where d.EmployeeId = l.EmployeeID and d.ScheduleDate = l.ScheduleDate and l.HolidayStatus > 0 and l.AttStart is not null and l.AttEnd is not null )
 and not exists (select 1 from #tblLvHistory lv where lv.LeaveCategory = 1 and d.EmployeeId = lv.EmployeeID and lv.LeaveStatus = 3 and lv.LeaveDate = d.ScheduleDate)
 and exists (select 1 from #tblTmpAttend t where d.EmployeeId = t.EmployeeID and
 t.AttTime between ScheduleDate and dateadd(mi,-60, d.AttStart))

 /*
 update d set RatioMatch = -500,isWrongShift = 1 from #tblShiftDetector_NeedUpdate d
 where
 (
 exists (select 1 from #tblLvHistory lv where lv.LeaveCategory = 1 and d.EmployeeId = lv.EmployeeID and lv.LeaveStatus = 3 and lv.LeaveDate = d.ScheduleDate + 1)
 or exists (select 1 from (select * from #tblShiftDetector_NeedUpdate
 union all
 select * from #tblShiftDetector) l where d.EmployeeId = l.EmployeeID and l.HolidayStatus > 0 and l.AttStart is null and l.AttEnd is null and l.ScheduleDate = d.ScheduleDate + 1)
 )
 and not exists (select 1 from #tblShiftDetectorMatched l where d.EmployeeId = l.EmployeeID and d.ScheduleDate = l.ScheduleDate and l.HolidayStatus > 0 and l.AttStart is not null and l.AttEnd is not null)
 and not exists (select 1 from #tblLvHistory lv where lv.LeaveCategory = 1 and d.EmployeeId = lv.EmployeeID and lv.LeaveStatus = 3 and lv.LeaveDate = d.ScheduleDate)
 and exists (select 1 from #tblTmpAttend t where d.EmployeeId = t.EmployeeID and
  t.AttTime between dateadd(mi,60, d.AttEnd) and dateadd(HOUR,24, d.ScheduleDate))
   */

end

-- phat hien co ca bi sai thi nang cac ca con lai len de cho len tau truoc

update d set RatioMatch = RatioMatch + 300
 from #tblShiftDetector_NeedUpdate d where exists (select 1 from (
select EmployeeId, ScheduleDate, ShiftCode
 from #tblShiftDetector_NeedUpdate where isWrongShift = 1
) t where d.EmployeeId = t.EmployeeId and d.ScheduleDate = t.ScheduleDate and d.ShiftCode <> t.ShiftCode)
and d.RatioMatch > -500
--t.AttTime between dateadd(mi,60, D.AttEnd) and dateadd(mi,-60, m.AttStart))
--if(@RepeatTime= 4)

/*print 'x--------------------------------------------------------x32'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/


-- Ch?m di?m ph?

-- Giong ca hôm qua, thêm 100 di?m, (nhung ca dêm gi?ng hôm tru?c mà thi?u gi? vào ho?c ra thì ko dc công di?m, vì có th? hôm dó xoay ca)
update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch + 100 where ShiftCodeYesterday is not null and ShiftCode = ShiftCodeYesterday and (isNightShift=0 or (isNightShift = 1 and AttStart is not null and AttEnd is not null))
-- ca dem thieu gio vao hoac ra ma hom sau la ngay cuoi tuan thi van dc uu tien nhan
update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch + 100 from #tblShiftDetector_NeedUpdate u WHERE u.ShiftCode = u.ShiftCodeYesterday AND ((u.AttStart IS NULL AND u.AttEnd IS NOT NULL) OR (u.AttEnd IS NULL AND u.AttStart IS NOT NULL)) AND u.isNightShift = 1
AND EXISTS (SELECT 1 FROM #tblWSchedule m WHERE u.EmployeeId = m.EmployeeId AND u.ScheduleDate = m.ScheduleDate - 1 AND m.HolidayStatus = 1)

-- neu khong co ca hom qua thi uu tien giong ca hom sau, chi nhung truong hop thieu gio vao hoac gio ra
update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch + 100 from #tblShiftDetector_NeedUpdate u WHERE u.ShiftCodeYesterday IS NULL AND ((u.AttStart IS NULL AND u.AttEnd IS NOT NULL) OR (u.AttStart IS NOT NULL AND u.AttEnd IS NULL))
AND EXISTS (SELECT 1 FROM #tblShiftDetectorMatched m WHERE u.EmployeeId = m.EmployeeId AND u.ShiftCode = m.ShiftCode AND u.ScheduleDate = m.ScheduleDate - 1)


-- neu tat ca cac ca diem dieu thap thi uu tien ca hom qua nhieu hon

--update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch + 100 where RatioMatch<=0 and ShiftCodeYesterday is not null and ShiftCode = ShiftCodeYesterday

--hom truoc di ca 3 mà có gi? vào, ra d? tránh nh?n ngày ti?p theo là di ca 1 thì tang di?m ca gi?ng ca hôm tru?c nhi?u lên cho nh?ng record có di?m s? < 500 , isNightShiftYesterday chi =1 khi ngay hom truoc la ca dem va co du gio vao, ra
update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch + 200 where RatioMatch<500 and isNightShiftYesterday = 1 and ShiftCodeYesterday is not null and ShiftCode = ShiftCodeYesterday
and (AttStart is not null and AttEnd is not null)
-- Hoa thom toa huong xa
update d set RatioMatch += 100 FROM #tblShiftDetector_NeedUpdate d
where exists (select 1 from #tblBloomFlavour b where d.EmployeeId = b.EmployeeId and d.ShiftCode = b.ShiftCode and d.ScheduleDate between b.FromDate and b.ToDate)
/*print 'x--------------------------------------------------------x33'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/


-- di tr?, v? s?m tr? 20 di?m
update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch - 20 where (InInterval <0 or OutInterval <0)
-- di tr? và v? s?m tr? 80 di?m
update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch - 80 where (InInterval <0 and OutInterval <0)
-- Ð?i tu?ng ngh? T7 thì ca HC du?c thêm 20 di?m

update d set RatioMatch = RatioMatch+20
from #tblShiftDetector_NeedUpdate d
 inner join #tblEmployeeList e on d.EmployeeId = e.EmployeeID
inner join tblEmployeeType t on e.EmployeeTypeID = t.EmployeeTypeID and t.SaturdayOff =1
where d.isOfficalShift = 1
-- trong tuan ty le ca di cao se dc công 330 diem -- @StatisticShiftPerweek_ShiftDetector
if @StatisticShiftPerweek_ShiftDetector > 0
begin
select ta.EmployeeId, datepart(wk,ta.ScheduleDate) WeekNumber,ss.ShiftCode, count(1) as ShiftCount
into #tblwschedule_ShiftCount from tblwschedule ta inner join tblShiftSetting ss on ta.shiftID = ss.ShiftID  where exists (select 1 from #tblPendingImportAttend m where ta.EmployeeID = m.EmployeeId and datepart(wk,ta.scheduleDate) = datepart(wk,m.Date) )
group by ta.EmployeeID,datepart(wk,ta.ScheduleDate),ss.ShiftCode
delete s from #tblwschedule_ShiftCount s where not exists (select 1 from (
select t.EmployeeID, t.WeekNumber, max(t.ShiftCount) ShiftCount from #tblwschedule_ShiftCount t group by t.EmployeeID, t.WeekNumber)
t where s.EmployeeID =  t.EmployeeID and s.WeekNumber = t.WeekNumber and s.ShiftCount = t.ShiftCount)
update #tblShiftDetector_NeedUpdate set RatioMatch = RatioMatch + @StatisticShiftPerweek_ShiftDetector
 from #tblShiftDetector_NeedUpdate m inner join #tblwschedule_ShiftCount sc on m.EmployeeId = sc.EmployeeID and datepart(wk,ScheduleDate) = sc.WeekNumber and m.ShiftCode = sc.ShiftCode
  drop table #tblwschedule_ShiftCount
end

-- Th?ng kê ca qua L?ch s? t? l? làm ca l?n nh?t dc 25 di?m
-- chua làm

--N?u có phân bi?t vào ra mà tr?ng thái vào ra, chính xác c? 2 du?c công 500 di?m
if @IN_OUT_TA_SEPARATE = 1
begin
 update s set RatioMatch = RatioMatch + (WorkEndMi - WorkStartMi) from #tblShiftDetector_NeedUpdate s
 where StateIn = 1 and StateOut = 2



 -- bam thieu 1 dau, nhung dung vao hoac ra
 update s set RatioMatch = RatioMatch + 100 from #tblShiftDetector_NeedUpdate s
 where ((StateIn = 1 and StateOut is null) or (StateIn is null and StateOut = 2))
 -- phan biet vao ra ma bam sai thi bi tru
 update s set RatioMatch = RatioMatch - (WorkEndMi - WorkStartMi) from #tblShiftDetector_NeedUpdate s
 where (StateIn <> 1 or StateOut <> 2)
 -- exists (select 1 from #tblTmpAttend t where s.EmployeeId = t.EmployeeID and s.AttStart = t.AttTime and t.AttState = 1) -- kh?p vào
 --and exists (select 1 from #tblTmpAttend t where s.EmployeeId = t.EmployeeID and s.AttEnd = t.AttTime and t.AttState = 2) -- kh?p ra
 -- neu thieu vao ra ma lai lech in out thi bo
 update s set RatioMatch = RatioMatch - 500 from #tblShiftDetector_NeedUpdate s where AttEnd is null and AttStart is not null and exists (select 1 from #tblTmpAttend t where s.EmployeeId = t.EmployeeID and s.AttStart = t.AttTime and t.AttState in (0,2))


 update s set RatioMatch = RatioMatch - 500
 from #tblShiftDetector_NeedUpdate s
 where AttStart is null and AttEnd is not null and exists (select 1 from #tblTmpAttend t where s.EmployeeId = t.EmployeeID and s.AttEnd = t.AttTime and t.AttState in (0,1))

end

update u set RatioMatch = -6000 from #tblShiftDetector_NeedUpdate u where isNightShift = 1 and StdWorkingTimeMi > 569 and abs(OutInterval) < 15 and InInterval > 90
UPDATE u set RatioMatch = -6000 from #tblShiftDetector_NeedUpdate u where isNightShift = 1 and abs(OutInterval) < 15 and InInterval > 300 AND ShiftCode <> ShiftCodeYesterday
-- sai ca qua troi sai
update u set RatioMatch = -6000 from #tblShiftDetector_NeedUpdate u where AttStart is not null and AttEnd is not null and ((abs (InInterval) >90 and abs (OutInterval) > 420) or (abs (OutInterval) >90 and abs (InInterval) > 420))
-- cùng di?m  uu tiên tru?ng h?p có gi? vào, gi? ra hon
update d set RatioMatch = d.RatioMatch + 10
from #tblShiftDetector_NeedUpdate d
inner join (Select EmployeeId,ScheduleDate,RatioMatch
  from #tblShiftDetector_NeedUpdate ta1
 group by EmployeeId,ScheduleDate,RatioMatch)
 ta1
  on d.EmployeeId = ta1.EmployeeId and d.ScheduleDate = ta1.ScheduleDate
where d.RatioMatch > 499 and d.AttStart is not null and d.AttEnd is not null


-- Nếu cùng điểm thì ưu tiên ca dài trước, cung diem thi tien ca dai gio, nhung d? sau d?i các ca khác lên di?m r?i tính toán l?i ca hôm tru?c, có th? di?m s? l?ch
if(@RepeatTime >50)
update d set RatioMatch = RatioMatch + 10* s.ShiftHours
 from #tblShiftDetector_NeedUpdate d
 inner join #tblShiftSetting s on d.ShiftCode = s.ShiftCode
where exists (select 1 from (
select d1.EmployeeId,d1.ScheduleDate from #tblShiftDetector_NeedUpdate d1 inner join #tblShiftDetector_NeedUpdate d2 on d1.EmployeeId = d2.EmployeeId and d1.ScheduleDate = d2.ScheduleDate and d1.RatioMatch = d2.RatioMatch and d1.ShiftCode <> d2.ShiftCode
) tmp where tmp.EmployeeId = d.EmployeeId and tmp.ScheduleDate = d.ScheduleDate)

-- x? lý tru?ng h?p ngu?i dùng nh?p 2 ca khác code mà gi? vào, gi? ra, gi? ngh? gi?ng h?t nhau,
update d set RatioMatch = RatioMatch + s.STT
 from #tblShiftDetector_NeedUpdate d
 inner join #tblShiftSetting s on d.ShiftCode = s.ShiftCode
where exists (select 1 from (
select d1.EmployeeId,d1.ScheduleDate from #tblShiftDetector_NeedUpdate d1 inner join #tblShiftDetector_NeedUpdate d2 on d1.EmployeeId = d2.EmployeeId and d1.ScheduleDate = d2.ScheduleDate and d1.RatioMatch = d2.RatioMatch and d1.ShiftCode <> d2.ShiftCode
and d1.WorkStart = d2.WorkStart and d1.WorkEnd = d2.WorkEnd and d1.AttStart = d2.AttStart and d1.AttEnd = d2.AttEnd
) tmp where tmp.EmployeeId = d.EmployeeId and tmp.ScheduleDate = d.ScheduleDate)




update d set RatioMatch = RatioMatch + s.STT
from #tblShiftDetector_NeedUpdate d
inner join #tblShiftSetting s on d.ShiftCode = s.ShiftCode
where d.RatioMatch < 1000

if(OBJECT_ID('sp_ShiftDetector_BloomFlavour' )is null)
 begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_BloomFlavour
(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)
as
begin
SET NOCOUNT ON;
end')
end
 set @StopUpdate = 0

-- Goi thu thu thuc customize import de ap dung cho tung khach hang rieng biet
exec sp_ShiftDetector_BloomFlavour @StopUpdate output ,@LoginID,@FromDate,@ToDate
if @StopUpdate = 0
begin
-- hoa toa huong lan nua
truncate table #tblBloomFlavour
insert into #tblBloomFlavour(EmployeeId, ScheduleDate,RatioMatch,STT)
SELECT d.EmployeeId, d.ScheduleDate, max(RatioMatch) RatioMatch,ROW_NUMBER() OVER (PARTITION BY EmployeeID order by EmployeeId, ScheduleDate) STT FROM (
select * from #tblShiftDetector where AttEndMi - AttStartMi > 660 and StdWorkingTimeMi > 500
union all
select * from #tblShiftDetector_NeedUpdate where AttEndMi - AttStartMi > 660 and StdWorkingTimeMi > 500
) d
group by d.EmployeeId, d.ScheduleDate

--LongKa: hôm qua ko có gi? công, hôm nay có gi? d?y d? thì cung dua vào luôn
insert into #tblBloomFlavour(EmployeeId, ScheduleDate,RatioMatch,STT)
SELECT n.EmployeeId, n.ScheduleDate, (max(n.RatioMatch)+500) RatioMatch,100 from #tblShiftDetector_NeedUpdate n inner join #tblWSchedule ws on n.EmployeeId = ws.EmployeeID and n.ScheduleDate = ws.ScheduleDate
where not exists(select 1 from #tblShiftDetector_NeedUpdate y where ws.EmployeeID = y.EmployeeId and y.ScheduleDate = ws.PrevDate
  and y.AttStart is not null and y.AttEnd is not null)
 and not exists(select 1 from #tblBloomFlavour b where n.EmployeeId = b.EmployeeId and n.ScheduleDate = b.ScheduleDate)
 and AttEndMi - AttStartMi > 480
group by n.EmployeeId, n.ScheduleDate

update ta1 set ToDate = (select min(ScheduleDate) from
(select EmployeeId,ScheduleDate from #tblBloomFlavour ta1
 where not exists(select 1 from #tblBloomFlavour ta2 where ta1. EmployeeId = ta2.EmployeeId and ta1.ScheduleDate = ta2.ScheduleDate-1)) ta2 where ta1.EmployeeId = ta2.EmployeeId and ta1.ScheduleDate <= ta2.ScheduleDate)
 , FromDate = (select max(ScheduleDate) from
 (select EmployeeId,ScheduleDate from #tblBloomFlavour ta1
 where not exists(select 1 from #tblBloomFlavour ta2 where ta1. EmployeeId = ta2.EmployeeId and ta1.ScheduleDate = ta2.ScheduleDate+1)
) ta2 where ta1.EmployeeId = ta2.EmployeeId and ta1.ScheduleDate >=ta2.ScheduleDate)
 from #tblBloomFlavour ta1


update d set RatioMatch = RatioMatch - 200 from #tblShiftDetector_NeedUpdate d
where exists (select 1 from #tblBloomFlavour b where b.ScheduleDate > b.FromDate and b.ScheduleDate <= b.ToDate
and b.EmployeeId = d.EmployeeId and b.ScheduleDate = d.ScheduleDate)
end



----------------------- Hot hui thoi nao-------------------------------



truncate table #tblPrevMatch
truncate table #tblPrevRemove
insert into #tblShiftDetector
select * from #tblShiftDetector_NeedUpdate

insert into #tblPrevMatch(EmployeeId,ShiftCode,ScheduleDate,AttStart,AttEnd,isNightShift,HolidayStatus,IsLeaveStatus3)
select EmployeeId,ShiftCode,ScheduleDate,AttStart,AttEnd,isNightShift,HolidayStatus,IsLeaveStatus3
from
(
 insert into #tblShiftDetectorMatched
  output inserted.EmployeeId,inserted.ShiftCode,inserted.ScheduleDate,inserted.AttStart,inserted.AttEnd,inserted.isNightShift,inserted.HolidayStatus,inserted.IsLeaveStatus3
 select m.* from #tblShiftDetector m
 inner join (
  select sd.employeeID,sd.ScheduleDate,max(sd.RatioMatch) as MaxRatioMatch from #tblShiftDetector sd
  inner join (
   SELECT EmployeeId, max(RatioMatch) MaxRatioMatch
   FROM #tblShiftDetector
   group by EmployeeId
  ) ratMax on sd.EmployeeId = ratmax.EmployeeId and
  (sd.RatioMatch = ratMax.MaxRatioMatch)
  -- b? l?y cào b?ng nh?ng ngày di?m cao g?n nhau, ch? l?y 1 thang cao nh?t
 /*(

(sd.RatioMatch between ratMax.MaxRatioMatch -(abs(ratMax.MaxRatioMatch)*0.1) and ratMax.MaxRatioMatch and sd.RatioMatch > 600)
  or
  (sd.RatioMatch = ratMax.MaxRatioMatch)
  )*/

  group by sd.EmployeeId,sd.ScheduleDate
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate and m.RatioMatch = tmp.MaxRatioMatch
) tmp


-- L?p nhi?u l?n
if ROWCOUNT_BIG() > 0
begin
/*print 'x--------------------------------------------------------x38'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/

insert into #tblPrevRemove(EmployeeId,ScheduleDate,ShiftCode)
select * from (delete ta1 output deleted.EmployeeId,deleted.ScheduleDate,deleted.ShiftCode
from #tblShiftDetectorMatched ta1
where ta1.RatioMatch = 0 and
exists(select 1 from #tblShiftDetectorMatched ta2 where ta1.EmployeeId =ta2.EmployeeId and ta1.ScheduleDate = ta2.ScheduleDate and ta2.ShiftCode> ta1.ShiftCode)) tmp

-- lo?i nh?ng ?ng viên l?y gi? ra hôm tru?c làm gi? vào hôm nay
insert into #tblPrevRemove(EmployeeId,ScheduleDate)
select EmployeeId,ScheduleDate from(
 delete m2 output deleted.EmployeeId,deleted.ScheduleDate from #tblShiftDetectorMatched m1
 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate-1 and m1.AttEnd = m2.AttStart
 and isnull( m1.StateOut,1) = 2
) tmp
 /*print 'x--------------------------------------------------------x39'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/

delete ta1 from #tblPrevMatch ta1
inner join #tblPrevRemove ta2 on ta1.EmployeeId = ta2.EmployeeId and ta1.ScheduleDate = ta2.ScheduleDate and ta1.ShiftCode = ta2.ShiftCode
truncate table #tblPrevRemove

DELETE D
FROM #tblShiftDetector D
WHERE EXISTS (SELECT 1 FROM #tblPrevMatch M WHERE M.EmployeeId = D.EmployeeId AND M.ScheduleDate = D.ScheduleDate)

update #tblPrevMatch set PrevDate = dateadd(day,-1,ScheduleDate) ,NextDate = dateadd(day,1,ScheduleDate)

-- h?n ch? tính toán l?i nhi?u l?n
truncate table #tblShiftDetector_NeedUpdate
insert into #tblShiftDetector_NeedUpdate
select * from
(
 delete ta1 output deleted.*
 from #tblShiftDetector ta1
 where exists(select 1 from #tblPrevMatch ta2
 where ta1.EmployeeId = ta2.EmployeeId and ta1.ScheduleDate in(PrevDate , NextDate ))
) tmp

 /*print 'x--------------------------------------------------------x40'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/


update ta1 set RatioMatch = 0,AttStart = CASE WHEN FixedAtt = 1 THEN AttStart ELSE null END, AttEnd = CASE WHEN FixedAtt = 1 THEN AttEnd ELSE null END
 ,AttStartTomorrow = case when AttStartTomorrowFixedTblHasta = 1 then AttStartTomorrow else null end, AttEndYesterday = case when AttEndYesterdayFixedTblHasta = 1 then AttEndYesterday else null end
 ,InInterval = null, OutInterval = null,WorkingTimeMi = null,AttStartMi = null,AttEndMi = null
from #tblShiftDetector_NeedUpdate ta1

insert into #tblPrevMatch(EmployeeId,ShiftCode,ScheduleDate,AttStart,AttEnd,isNightShift,HolidayStatus,IsLeaveStatus3,Prevdate,NextDate)
select EmployeeId,ShiftCode,ScheduleDate,AttStart,AttEnd,isNightShift,HolidayStatus,IsLeaveStatus3, dateadd(day,-1,ScheduleDate) , dateadd(day,1,ScheduleDate)
from #tblShiftDetectorMatched prev
where --not exists(select 1 from #tblShiftDetector ta2 where NeedUpdate = 1 and ta2.EmployeeId = prev.EmployeeId) and
EmployeeId in (select EmployeeId from #tblShiftDetector
except
select EmployeeId from #tblShiftDetector_NeedUpdate ta2 )

insert into #tblShiftDetector_NeedUpdate
select * from
(
 delete ta1 output deleted.*
  from #tblShiftDetector ta1
  where NOT EXISTS(SELECT * FROM #tblShiftDetector_NeedUpdate ne WHERE ta1.EmployeeID = ne.EmployeeId)
)tmp


update ta1 set RatioMatch = 0,AttStart = CASE WHEN FixedAtt = 1 THEN AttStart ELSE null END, AttEnd = CASE WHEN FixedAtt = 1 THEN AttEnd ELSE null END
 ,AttStartTomorrow = case when AttStartTomorrowFixedTblHasta =1 then AttStartTomorrow else null end
 ,AttEndYesterday = case when AttEndYesterdayFixedTblHasta =1 then AttEndYesterday else null end
 ,InInterval = null, OutInterval = null--,NeedUpdate = 1
from #tblShiftDetector_NeedUpdate ta1
 /*print 'x--------------------------------------------------------x41'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/

truncate table #tblPrevMatch
insert into #tblPrevMatch(EmployeeId,ShiftCode,ScheduleDate,AttStart,AttEnd,isNightShift,HolidayStatus,IsLeaveStatus3,Prevdate,NextDate)
select EmployeeId,ShiftCode,ScheduleDate,AttStart,AttEnd,isNightShift,HolidayStatus,IsLeaveStatus3, dateadd(day,-1,ScheduleDate) , dateadd(day,1,ScheduleDate)
from #tblShiftDetectorMatched ta1
where exists(select 1 from #tblShiftDetector_NeedUpdate ta2 where ta1.EmployeeId = ta2.EmployeeId and ta1.ScheduleDate in(dateadd(day,1,ta2.ScheduleDate), dateadd(day,-1,ta2.ScheduleDate)))
/*print 'x--------------------------------------------------------x42'
set @count =DATEdiff(MILLISECOND,@sysDatetime,SYSDATETIME())
print @count set @sysDatetime = SYSDATETIME()
print 'z--------------------------------------------------------z'*/

 set @RepeatTime +=1
 goto StartRepeat
end

--print 'pass repeat'
update m1 set AttEndYesterday = isnull(m2.AttEnd, dateadd(HOUR,-10,m1.WorkStart))
from #tblShiftDetectorMatched m1
inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate+1
 where m2.AttEnd is not null

 update m1 set AttStartTomorrow = isnull(m2.AttStart,DATEADD(hour,16,m1.WorkEnd))
 from #tblShiftDetectorMatched m1
 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate-1
 where m2.AttStart is not null

update #tblShiftDetectorMatched set FixedAtt = 0 where FixedAtt is null

 update m1 set AttEndYesterday = dateadd(hour,-16,m1.WorkStart)
 from #tblShiftDetectorMatched m1
 where m1.AttEndYesterdayFixed = 1
 and m1.AttEndYesterday < dateadd(hour,-16,m1.WorkStart)

 update m1 set AttStartTomorrow = dateadd(hour,16,m1.WorkEnd)
 from #tblShiftDetectorMatched m1 where m1.AttStartTomorrowFixed = 1 and m1.AttStartTomorrow > dateadd(hour,16,m1.WorkEnd)

-- chinh ly lai gio vao ra sau khi da nhan ca chinh xac
 update #tblShiftDetectorMatched set AttStart = tmp.AttTime
 from #tblShiftDetectorMatched m
 inner join (
 SELECT m.EmployeeId, m.ScheduleDate, MIN(t.AttTime) AttTime
 FROM #tblShiftDetectorMatched m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where FixedAtt =0
 and (ForceState = 0 or AttState = 1)
 --and Approved is null tri:bo nay di vi duyet ca thi k lien quan gi ts viec sua vao - ra
 and t.AttTime < m.AttEnd
 and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
 and t.AttTime between m.TimeinBefore and m.TIMEOUTAFTER
 group by m.EmployeeId, m.ScheduleDate
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate



 update #tblShiftDetectorMatched set AttEnd = tmp.AttTime
 from #tblShiftDetectorMatched m
 inner join (
 SELECT m.EmployeeId, m.ScheduleDate, max(t.AttTime) AttTime
 FROM #tblShiftDetectorMatched m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where FixedAtt =0
--and (ForceState = 0 or AttState = 2)
 --and Approved is null
 and t.AttTime > isnull(m.AttEnd, m.AttStart)
 and t.AttTime > m.AttEndYesterday and t.AttTime< m.AttStartTomorrow
 and t.AttTime between m.TimeinBefore and m.TIMEOUTAFTER
and datediff(mi,m.AttStart,t.AttTime) >= m.INOUT_MINIMUM
 group by m.EmployeeId, m.ScheduleDate
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate

-- x? lý l?i nh?ng ca dã nh?n v?i d? chính xác cao nhung n?u nh?n ca dó thì s? làm m?t d? li?u b?m công --> ca dó không dúng
-- Re_Process


update m1 set AttEndYesterday = isnull(m2.AttEnd, dateadd(HOUR,-10,m1.WorkStart))
from #tblShiftDetectorMatched m1
inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate+1
 where m2.AttEnd is not null

 update m1 set AttStartTomorrow = isnull(m2.AttStart,DATEADD(hour,16,m1.WorkEnd))
 from #tblShiftDetectorMatched m1
 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate-1
 where m2.AttStart is not null

 update m1 set AttStartTomorrow = isnull(m2.AttStart,DATEADD(hour,16,m1.WorkEnd))
 from #tblShiftDetectorMatched m1
 inner join #tblHasTA m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.Attdate-1
 where m1.AttStartTomorrow is null

update #tblShiftDetectorMatched set FixedAtt = 0 where FixedAtt is null
 update m1 set AttEndYesterday = dateadd(hour,-16,m1.WorkStart)
 from #tblShiftDetectorMatched m1
 where m1.AttEndYesterdayFixed = 1
and m1.AttEndYesterday < dateadd(hour,-16,m1.WorkStart)

 update m1 set AttStartTomorrow = dateadd(hour,16,m1.WorkEnd)
 from #tblShiftDetectorMatched m1 where m1.AttStartTomorrowFixed = 1 and m1.AttStartTomorrow > dateadd(hour,16,m1.WorkEnd)

if @IN_OUT_TA_SEPARATE = 1
 set @Re_Process = 4

 if(OBJECT_ID('sp_ShiftDetector_Re_Process' )is null)
 begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_Re_Process
(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)
as
begin
SET NOCOUNT ON;
end')
end
 set @StopUpdate = 0

-- Goi thu thu thuc customize import de ap dung cho tung khach hang rieng biet
exec sp_ShiftDetector_Re_Process @StopUpdate output ,@LoginID,@FromDate,@ToDate


if @Re_Process < 2 and @StopUpdate = 0
begin
set @Re_Process = @Re_Process+ 1

 -- xu ly lai
 -- xac dinh nhung dong can xu ly lai ca
 -- xác d?nh nh?ng dòng c?n x? lý l?i ca
 -- EmployeeId,ScheduleDate,HolidayStatus,ShiftCode,ShiftCodeWrong
 truncate table #tblShiftDetectorReprocess
 insert into #tblShiftDetectorReprocess(STT,EmployeeId,ScheduleDate,ShiftCode)
 select ROW_NUMBER()Over(PARTITION BY m1.EmployeeId order by m1.EmployeeId,m1.ScheduleDate) Ord, m1.EmployeeId,m1.ScheduleDate,m1.ShiftCode
 from #tblShiftDetectorMatched m1 inner join #tblShiftDetectorMatched m2 on m1.employeeId = m2.EmployeeID and m1.ScheduleDate = m2.ScheduleDate - 1
 where
 (exists (select 1 from #tblTmpAttend t where m2.EmployeeId = t.EmployeeID and m1.EmployeeId = t.EmployeeID and t.AttTime < dateadd(hour,12,m1.WorkEnd) and t.AttTime between dateadd(mi,60,isnull(m1.AttEnd,m1.WorkEnd)) and dateadd(mi,-60, isnull(m2.AttStart,m2.WorkEnd)))
 and isnull(m1.Approved,0) = 0 and isnull(m2.Approved,0) = 0
 )
 or
 (exists (select 1 from #tblShiftDetectorMatched n where m1.EmployeeId = n.EmployeeId and m1.ScheduleDate = n.ScheduleDate - 1 and n.HolidayStatus > 0 and n.AttStart is null and n.AttEnd IS NULL)
 AND
 EXISTS (SELECT 1 FROM #tblTmpAttend t where t.EmployeeID = m1.EmployeeId and t.AttTime between DATEADD(mi,60,isnull(m1.AttEnd,m1.WorkEnd)) and DATEADD(HH,22,m1.AttEnd)))

 insert into #tblShiftDetectorReprocess(STT,EmployeeId,ScheduleDate,ShiftCode)
 select ROW_NUMBER()Over(PARTITION BY m1.EmployeeId order by m1.EmployeeId,m1.ScheduleDate) Ord, m1.EmployeeId,m2.ScheduleDate,m2.ShiftCode
 from #tblShiftDetectorMatched m1 inner join #tblShiftDetectorMatched m2 on m1.employeeId = m2.EmployeeID and m1.ScheduleDate = m2.ScheduleDate - 1
 where
 (exists (select 1 from #tblTmpAttend t where m2.EmployeeId = t.EmployeeID and m1.EmployeeId = t.EmployeeID and t.AttTime >= dateadd(hour,12,m1.WorkEnd) and t.AttTime between dateadd(mi,60,isnull(m1.AttEnd,m1.WorkEnd)) and dateadd(mi,-60, isnull(m2.AttStart,m2.WorkEnd)))

 and isnull(m1.Approved,0) = 0 and isnull(m2.Approved,0) = 0
 )

 /*
 --LongKa: tru?ng h?p n?u nh?n gi? hôm nay thì b? thi?u gi? ngày hôm qua ho?c thi?u gi? ngày mai
 insert into #tblShiftDetectorReprocess(STT,EmployeeId,ScheduleDate,ShiftCode)
 select ROW_NUMBER()Over(PARTITION BY m1.EmployeeId order by m1.EmployeeId,m1.ScheduleDate) Ord, m1.EmployeeId,m1.ScheduleDate,m1.ShiftCode
 from #tblShiftDetectorMatched m1 inner join #tblShiftDetectorMatched m2 on m1.employeeId = m2.EmployeeID and m1.ScheduleDate = m2.ScheduleDate + 1
 where
 (m2.AttStart is null or m2.AttEnd is null) and
 (exists (select 1 from #tblTmpAttend t where m2.EmployeeId = t.EmployeeID and m1.EmployeeId = t.EmployeeID
 and t.AttTime between dateadd(mi,60,m2.AttEnd) and dateadd(mi,-60, isnull(m1.AttStart,m1.WorkStart)))
 and isnull(m1.Approved,0) = 0 and isnull(m2.Approved,0) = 0
 ) and exists(select 1 from #tblShiftDetectorMatched t where m1.EmployeeId = t.EmployeeId and (m1.ScheduleDate+1) = t.ScheduleDate and (t.AttStart is null or t.AttEnd is null) )
 */
 --update p2 set AttEndYesterday = p1.ScheduleDate from #tblShiftDetectorReprocess p1 inner join #tblShiftDetectorReprocess p2 on p1.employeeID = p2.EmployeeID and p1.Stt = p2.Stt-1
 --update #tblShiftDetectorReprocess set AttEndYesterday = dateadd(day,-20,Scheduledate) where AttEndYesterday is null
 update p set WorkStart = tmp.WorkStart from #tblShiftDetectorReprocess p inner join (
 select max(m.ScheduleDate) WorkStart, p.EmployeeId, p.ScheduleDate from #tblShiftDetectorReprocess p inner join #tblShiftDetectorMatched m on p.EmployeeId = m.EmployeeId and m.ScheduleDate < p.ScheduleDate and m.ScheduleDate > DATEADD(day,-7, p.ScheduleDate) and (m.AttStart is null) -- and m.AttEnd is not null
 group by p.EmployeeId, p.ScheduleDate
 ) tmp on p.EmployeeId = tmp.EmployeeId and p.ScheduleDate = tmp.ScheduleDate

 update p set WorkStart = tmp.WorkStart from #tblShiftDetectorReprocess p inner join (
 select max(m.ScheduleDate) WorkStart, p.EmployeeId, p.ScheduleDate from #tblShiftDetectorReprocess p inner join #tblShiftDetectorMatched m on p.EmployeeId = m.EmployeeId and m.ScheduleDate < p.ScheduleDate and m.ScheduleDate > DATEADD(day,-7, p.ScheduleDate) and (m.AttEnd is null) --m.AttStart is not null and
 group by p.EmployeeId, p.ScheduleDate
 ) tmp on p.EmployeeId = tmp.EmployeeId and p.ScheduleDate = tmp.ScheduleDate and p.WorkStart is null

 update p set WorkEnd = tmp.WorkEnd from #tblShiftDetectorReprocess p inner join (
 select min(m.ScheduleDate) WorkEnd, p.EmployeeId, p.ScheduleDate from #tblShiftDetectorReprocess p inner join #tblShiftDetectorMatched m on p.EmployeeId = m.EmployeeId and m.ScheduleDate > p.ScheduleDate and m.ScheduleDate < DATEADD(day,7, p.ScheduleDate) and ( m.AttEnd is null) --m.AttStart is not null and
 group by p.EmployeeId, p.ScheduleDate
 ) tmp on p.EmployeeId = tmp.EmployeeId and p.ScheduleDate = tmp.ScheduleDate

 update p set WorkEnd = tmp.WorkEnd from #tblShiftDetectorReprocess p inner join (





select min(m.ScheduleDate) WorkEnd, p.EmployeeId, p.ScheduleDate from #tblShiftDetectorReprocess p inner join #tblShiftDetectorMatched m on p.EmployeeId = m.EmployeeId and m.ScheduleDate > p.ScheduleDate and m.ScheduleDate < DATEADD(day,7, p.ScheduleDate) and (m.AttStart is null) -- and m.AttEnd is not null
 group by p.EmployeeId, p.ScheduleDate
 ) tmp on p.EmployeeId = tmp.EmployeeId and p.ScheduleDate = tmp.ScheduleDate and p.WorkEnd is null

 ---- do?n này dang x? lý sai
 --update #tblShiftDetectorReprocess set WorkStart = tmp.ScheduleDateM from #tblShiftDetectorReprocess p inner join (
 --select m.EmployeeID,p.ScheduleDate, max(m.ScheduleDate) ScheduleDateM
 --from #tblShiftDetectorReprocess p inner join #tblShiftDetectorMatched m on p.EmployeeId = m.EmployeeId and m.ScheduleDate between p.AttEndYesterday and p.ScheduleDate
 --where (m.AttStart is null and m.AttEnd is not null) or (m.AttStart is not null and m.AttEnd is null)
 --group by m.EmployeeID,p.ScheduleDate
 --) tmp on p.EmployeeId = tmp.EmployeeId and p.ScheduleDate = tmp.ScheduleDate

 update #tblShiftDetectorReprocess set WorkStart = DATEADD(day,1,ScheduleDate) where WorkStart is null and WorkEnd is not null
 update #tblShiftDetectorReprocess set WorkEnd = ScheduleDate where WorkEnd is null and WorkStart is not null
 delete #tblShiftDetectorReprocess where WorkEnd is null and WorkStart is null


 if exists (select 1 from #tblShiftDetectorReprocess)
 begin

 insert into #tblShiftDetector(EmployeeId,ScheduleDate,HolidayStatus,ShiftCode,RatioMatch,EmployeeStatusID)
 select m1.EmployeeId,m1.ScheduleDate,m1.HolidayStatus,sg.ShiftCode,0,m1.EmployeeStatusID
 from #tblShiftDetectorMatched m1
 inner join #tblShiftGroupCode c on m1.EmployeeId = c.EmployeeID
 full outer join #tblShiftGroup_Shift sg
 on c.ShiftGroupCode = sg.ShiftGroupID
 where
 exists (select 1 from #tblShiftDetectorReprocess p where p.EmployeeId = m1.EmployeeId and m1.ScheduleDate between p.WorkStart and p.WorkEnd)
 and sg.ShiftCode is not null
 and m1.EmployeeId is not null
 and m1.ScheduleDate between c.FromDate and c.ToDate



 insert into #tblShiftDetector(EmployeeId,ScheduleDate,HolidayStatus,ShiftCode,RatioMatch,EmployeeStatusID)
 select m1.EmployeeId,m1.ScheduleDate,m1.HolidayStatus,sg.ShiftCode,0,m1.EmployeeStatusID
 from #tblShiftDetectorMatched m1
 cross join
 (select distinct ShiftCode from #tblShiftSetting) sg
 where
 exists (select 1 from #tblShiftDetectorReprocess p where p.EmployeeId = m1.EmployeeId and m1.ScheduleDate between p.WorkStart and p.WorkEnd)
 and not exists(select 1 from #tblShiftDetector t where m1.EmployeeID = t.EmployeeID and m1.ScheduleDate = t.ScheduleDate)

 -- bo het ca bi sai di
 delete m from #tblShiftDetector m where exists (select 1 from #tblShiftDetectorMatched d where d.employeeID = m.employeeID and m.ScheduleDate = d.ScheduleDate and m.shiftCode = d.ShiftCode)
 delete m from #tblShiftDetectorMatched m where exists (select 1 from #tblShiftDetector d where d.employeeID = m.employeeID and d.ScheduleDate = m.ScheduleDate)



 set @RepeatTime = 0
 truncate table #tblPrevMatch
 insert into #tblPrevMatch(EmployeeId,ShiftCode,ScheduleDate,AttStart,AttEnd,isNightShift,HolidayStatus,IsLeaveStatus3,Prevdate,NextDate)
 select EmployeeId,ShiftCode,ScheduleDate,AttStart,AttEnd,isNightShift,HolidayStatus ,IsLeaveStatus3,DATEADD(day,-1,ScheduleDate),DATEADD(day,1,ScheduleDate)
 from #tblShiftDetectorMatched
 --set @MaxRatioMatch = null
 goto StartShiftDetector
 end


end
end
-- ket thuc nhan dang ca



set datefirst 7
update d set ShiftID = s.ShiftID
--,s.WorkstartMi,s.WorkendMi,s.AttStartMi,s.AttEndMi,s.BreakEndMi,s.BreakStartMi
from #tblShiftDetectorMatched d
 inner join tblShiftSetting s on d.ShiftCode = s.ShiftCode and DATEPART(dw,d.ScheduleDate) = s.WeekDays
 where DATEPART(hh,s.WorkStart) <> DATEPART(hh,s.WorkEnd)


 -- xu ly tinh chinh nhung ca khac gio vao, gio ra (vi du T7 lam nua ngay)
 --update d set ShiftID = s.ShiftID
--,s.WorkstartMi,s.WorkendMi,s.AttStartMi,s.AttEndMi,s.BreakEndMi,s.BreakStartMi
update d set d.WorkstartMi = DATEPART(hh,s.WorkStart) * 60 + DATEPART(mi,s.WorkStart), d.WorkendMi = case when  DATEPART(hh,s.WorkStart) >  DATEPART(hh,s.WorkEnd) then  1440 else 0 end + DATEPART(hh,s.WorkEnd) * 60 + DATEPART(mi,s.WorkEnd)
,d.BreakEndMi = case when  DATEPART(hh,s.WorkStart) >  DATEPART(hh,s.BreakEnd) then  1440 else 0 end +  DATEPART(hh,s.BreakEnd) * 60 + DATEPART(mi,s.BreakEnd)
,d.BreakStartMi = case when  DATEPART(hh,s.WorkStart) >  DATEPART(hh,s.BreakStart) then  1440 else 0 end +  DATEPART(hh,s.BreakStart) * 60 + DATEPART(mi,s.BreakStart)
from #tblShiftDetectorMatched d
 inner join tblShiftSetting s on d.ShiftID = s.ShiftID
 where (DATEPART(hh,s.WorkStart) <>  DATEPART(hh,d.WorkStart) or DATEPART(hh,s.WorkEnd) <>  DATEPART(hh,d.WorkEnd))
update d set ShiftID = s.ShiftID
from #tblShiftDetectorMatched d
inner join #tblShiftSetting s on d.ShiftCode = s.ShiftCode
where d.ShiftID is null-- and s.ShiftID is not null


-- process duplicate shift code
-- uu tien ca hom qua giong hom nay, sau roi den do dai cua ca, roi de thu tu cua ca
-- Set priority for the same ShiftCode as Yesterday code, then for the long of working shift, final is Shift order number
-- khong hieu doian nay dung de lam gi,khi ma viec nhan dang ca da xong roi

update m set RatioMatch = 100001 + Case when ShiftCode = ShiftCodeYesterday then 1000 else 0 end + isnull(StdWorkingTimeMi,0) + ISNULL(ShiftID,0)
from #tblShiftDetectorMatched m where exists (
select 1 from #tblShiftDetectorMatched d where m.EmployeeId = d.EmployeeId and m.ScheduleDate = d.ScheduleDate group by d.EmployeeId, d.ScheduleDate having COUNT(1) > 1 )
delete m from #tblShiftDetectorMatched m where Exists (select 1 from #tblShiftDetectorMatched d where d.RatioMatch > 100000 and m.EmployeeId = d.EmployeeId and m.ScheduleDate = d.ScheduleDate and d.RatioMatch > m.RatioMatch)



insert into #tblWschedule(EmployeeID,ScheduleDate,ShiftID,HolidayStatus,DateStatus,Approved)
 select * from(
insert into tblWSchedule(EmployeeID,ScheduleDate,ShiftID,HolidayStatus,DateStatus,Approved) output inserted.EmployeeID,inserted.ScheduleDate,inserted.ShiftID,inserted.HolidayStatus
,inserted.DateStatus,inserted.Approved
select distinct EmployeeID,ScheduleDate,ShiftID,HolidayStatus,1,0
 from #tblShiftDetectorMatched a
where a.ScheduleDate between @FromDate and @ToDate
and not exists(select 1 from #tblWSchedule b where a.EmployeeID = b.EmployeeID and a.ScheduleDate = b.ScheduleDate)
) t



-- xoa nhung record lo vao roi ma ket ko ra dc
delete tblWschedule from tblWschedule ws
where ws.ScheduleDate between @FromDate and @ToDate
and exists (select 1 from #tblEmployeeList te where ws.EmployeeID = te.EmployeeID)
and not exists(select 1 from #tblWschedule tmp where ws.EmployeeID = tmp.EmployeeID and ws.ScheduleDate = tmp.ScheduleDate)
and (ISNULL(ws.Approved,0) = 0 and ws.DateStatus <> 3)

update #tblShiftDetectorMatched set AttEnd = null, AttEndMi = null, WorkingTimeMi = 0
where AttEndMi - AttStartMi < INOUT_MINIMUM and AttStartMi is not null and AttEndMi is not null

 if(OBJECT_ID('sp_ShiftDetector_BeforeUpdatetblWSchedule' )is null)
 begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_BeforeUpdatetblWSchedule
(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)

as
begin
 SET NOCOUNT ON;
end')
end
 set @StopUpdate = 0
-- Goi thu thu thuc customize import de ap dung cho tung khach hang rieng biet

 exec sp_ShiftDetector_BeforeUpdatetblWSchedule @StopUpdate output ,@LoginID,@FromDate,@ToDate


update tblWSchedule set ShiftID = ISNULL(m.ShiftID,0) ,HolidayStatus = m.HolidayStatus
from tblWSchedule ws
inner join #tblShiftDetectorMatched m on ws.EmployeeID = m.EmployeeId and ws.ScheduleDate = m.ScheduleDate
where (ws.Approved is null or ws.Approved = 0)
-- Nguoi dung da confirm
-- ngay hom do co nghi
-- thai san



UPDATE #tblShiftDetectorMatched SET AttStart = null, AttEnd = NULL, FixedAtt = 0
from #tblShiftDetectorMatched m inner join (
 select EmployeeId,LeaveDate,Max(LeaveStatus) LeaveStatus, sum(lvAmount) lvAmount from #tblLvHistory where LeaveCategory = 1 group by EmployeeID,LeaveDate
) lv on m.EmployeeId = lv.EmployeeID and m.ScheduleDate = lv.LeaveDate
where lv.LvAmount >= 8 and m.HolidayStatus = 0 and m.EmployeeId in (select EmployeeID from #tblEmployeeList where NotCheckTA = 1)
and m.AttStartMi = m.WorkStartMi and m.AttEndMi = m.WorkEndMi

update #tblShiftDetectorMatched
set
AttStart = case when AttStart is null or AttStartMi > WorkStartMi then DATEADD(mi, case when lv.lvAmount > 0 and lv.LeaveStatus in(1,4) then WorkStartMi + (lv.lvAmount*60) else WorkStartMi end, ScheduleDate) else AttStart end
,AttEnd = case when AttEnd is null or AttEndMi < WorkEndMi then DATEADD(mi,case when lv.lvAmount > 0 and lv.LeaveStatus in(2,5) then WorkEndMi - (lv.lvAmount*60) else WorkEndMi end, ScheduleDate) else AttEnd end
--,StdWorkingTimeMi = BreakStartMi - WorkStartMi + (WorkEndMi-BreakEndMi)
from #tblShiftDetectorMatched m left join
 (select EmployeeId,LeaveDate,Max(LeaveStatus) LeaveStatus, sum(lvAmount) lvAmount from #tblLvHistory where LeaveCategory = 1 group by EmployeeID,LeaveDate) lv
 on m.EmployeeId = lv.EmployeeID and m.ScheduleDate = lv.LeaveDate
where HolidayStatus = 0 and exists(select 1 from #tblEmployeeList te where NotCheckTA = 1 AND m.EmployeeID = te.EmployeeID)
and (lv.EmployeeID is null or lv.lvAmount < 8)

update m set AttEnd = tmp.AttTime from #tblShiftDetectorMatched m inner join (
 SELECT m.EmployeeId, m.ScheduleDate, max(t.AttTime) AttTime
 from #tblShiftDetectorMatched m
 inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where ((t.AttTime > m.AttEnd and t.AttTime < m.TIMEOUTAFTER )or m.AttEnd is null) and t.AttTime < m.AttStartTomorrow
 and t.AttTime > m.AttEndYesterday
 and (t.AttTime > m.AttStart or m.AttStart is null)
 and (t.AttTime >= dateadd(mi, INOUT_MINIMUM, m.AttStart))
 group by m.EmployeeId,m.ScheduleDate
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate

 --hom truoc thieu du lieu cong ma gio vao trung voi gio vao hom sau
 update m1 set AttEnd = null from #tblShiftDetectorMatched m1 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate+1 = m2.ScheduleDate
 where m1.AttStart is null and m1.AttEnd = m2.AttStart
 -- hom sau thieu du lieu cong ma gio vao trung voi gio ra hom truoc
 update m2 set AttStart = null from #tblShiftDetectorMatched m1 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate = m2.ScheduleDate - 1
 where m1.AttStart is not null and m2.AttEnd is null and m1.AttEnd = m2.AttStart

----------- dua vao bang tblhasTA-------------------------
----------- dua vào b?ng tblhasTA-------------------------



set @RepeatTime = 0

select ta.*,s.AttEndYesterday as MinTimeIn,s.AttEndYesterday as MaxTimeIn,s.AttEndYesterday as MinTimeOut,s.AttEndYesterday as MaxTimeOut ,s.AttEndYesterday, s.AttStartTomorrow, s.TIMEINBEFORE, s.TIMEOUTAFTER,s.INOUT_MINIMUM, s.StdWorkingTimeMi, s.StdWorkingTimeMi as STDWorkingTime_SS
,s.WorkstartMi,s.WorkendMi,s.AttStartMi,s.AttEndMi,s.BreakEndMi,s.BreakStartMi,s.Early_Permit,s.Late_Permit
,s.ShiftID
into #tblHasTA_insert
from #tblHasTA ta
inner join #tblShiftDetectorMatched s on ta.EmployeeID = s.EmployeeId and ta.AttDate = s.ScheduleDate where 1=0
-- Option 0: xóa gi? vào ra n?u có ngh? c? ngày
-- Option 1: xóa ngh? c? ngày n?u có gi? vào, gi? ra
-- Option 2: Xóa gi? vào ra n?u ngh? c? ngày và workingtimeMi < 120
-- Option 3: Xóa ngh? c? ngày n?u có gi? vào ra và WorkingTimeMi > 240
-- Option 4: van giu gio cong va leave
update m set AttEnd = null,AttStart = null, WorkingTimeMi = 0 from #tblShiftDetectorMatched m where m.HolidayStatus = 0 and @LEAVEFULLDAYSTILLHASATTTIME = 0 and IsLeaveStatus3 = 1
update m set AttEnd = null,AttStart = null, WorkingTimeMi = 0 from #tblShiftDetectorMatched m where m.HolidayStatus = 0 and @LEAVEFULLDAYSTILLHASATTTIME = 2 and IsLeaveStatus3 = 1 and WorkingTimeMi < 120



delete tblLvHistory from tblLvHistory lv inner join #tblShiftDetectorMatched m on lv.EmployeeID = m.EmployeeId and lv.LeaveDate = m.ScheduleDate and lv.LeaveStatus = 3 and m.IsLeaveStatus3 = 1
where m.HolidayStatus = 0 and @LEAVEFULLDAYSTILLHASATTTIME = 1 and m.AttStart is not null and m.AttEnd is not null

delete tblLvHistory from tblLvHistory lv inner join #tblShiftDetectorMatched m on lv.EmployeeID = m.EmployeeId and lv.LeaveDate = m.ScheduleDate and lv.LeaveStatus = 3 and m.IsLeaveStatus3 = 1
where m.HolidayStatus = 0 and @LEAVEFULLDAYSTILLHASATTTIME = 1 and m.AttStart is not null and m.AttEnd is not null and m.WorkingTimeMi > 240


select @TA_IO_SWIPE_OPTION= CAST(Value as float) from tblParameter where Code = 'TA_IO_SWIPE_OPTION'
/*
0 B?m t? do
1 Vào làm b?m công, v? b?m công
2 B?m gi? công 2 l?n d?u ca cu?i ca, tang ca b?m riêng
3 Sáng b?m, trua b?m, chi?u b?m và tang ca b?m công
4 Theo t?ng ca c? th?

*/

update ta1 set TIMEOUTAFTER = ta2.TIMEINBEFORE
from #tblShiftDetectorMatched ta1
inner join #tblShiftDetectorMatched ta2 on ta1.EmployeeId = ta2.EmployeeId and ta1.ScheduleDate= ta2.ScheduleDate -1
where ta2.AttStart is not null and ta2.AttEnd is not null

update #tblShiftDetectorMatched set TIMEOUTAFTER = DATEADD(HOUR,24,WorkStart) where TIMEOUTAFTER <= WorkStart


set @TA_IO_SWIPE_OPTION = ISNULL(@TA_IO_SWIPE_OPTION,1)
if @TA_IO_SWIPE_OPTION = 0 -- b?m t? do
begin
 update #tblShiftDetectorMatched set AttEndYesterday = dateadd(mi,-20,AttStart) where AttEndYesterday is null  and AttStart is not null
 update #tblShiftDetectorMatched set AttStartTomorrow = dateadd(mi,20,AttEnd) where AttStartTomorrow is null and AttEnd is not null
 update #tblShiftDetectorMatched set AttEndYesterday = dateadd(mi,10,AttEndYesterday),AttStartTomorrow= dateadd(mi,-10,AttStartTomorrow)
  where @IN_OUT_TA_SEPARATE = 0
 RepeatInsertHasTAOption0:


 --EmployeeID,AttDate,Period,AttStart,AttEnd,WorkingTime,TAStatus
 insert into #tblHasTA_insert(EmployeeID,AttDate,Period,TAStatus,WorkingTime,StdWorkingTimeMi,BreakStartMi,BreakEndMi,WorkStart,WorkEnd,AttEndYesterday,AttStartTomorrow)
 select EmployeeID,ScheduleDate,@RepeatTime,0,WorkingTimeMi/60.0,StdWorkingTimeMi,BreakStartMi,BreakEndMi ,WorkStart,WorkEnd,AttEndYesterday,AttStartTomorrow
 from #tblShiftDetectorMatched where ScheduleDate between @FromDate and @ToDate


 -- Nh?ng anh em dã du?c ngu?i dùng xác nh?n gi? vào ra r?i thì không d?ng vào
 update #tblHasTA_insert set TAStatus= a.TAStatus,AttStart = a.AttStart, AttEnd = a.AttEnd
 from #tblHasTA_insert ta inner join #tblHasTA a on ta.EmployeeID = a.EmployeeID and ta.AttDate = a.AttDate and ta.Period = a.Period
 where a.TAStatus = 3 and a.AttDate between @FromDate and @ToDate

 update #tblHasTA_insert set TAStatus= a.TAStatus, AttEnd = a.AttEnd
 from #tblHasTA_insert ta inner join #tblHasTA a on ta.EmployeeID = a.EmployeeID and ta.AttDate = a.AttDate and ta.Period = a.Period
 where a.TAStatus = 2 and a.AttDate between @FromDate and @ToDate
  update #tblHasTA_insert set TAStatus= a.TAStatus,AttStart = a.AttStart
 from #tblHasTA_insert ta inner join #tblHasTA a on ta.EmployeeID = a.EmployeeID and ta.AttDate = a.AttDate and ta.Period = a.Period
 where a.TAStatus = 1 and a.AttDate between @FromDate and @ToDate

 -- AttStart
 update #tblHasTA_insert set AttStart = tmp.AttTime from #tblHasTA_insert ta inner join (
  select ta.EmployeeID,ta.AttDate, min(att.AttTime) AttTime
from #tblHasTA_insert ta
  inner join #tblShiftDetectorMatched m on ta.EmployeeID = m.EmployeeId and ta.AttDate = m.ScheduleDate
  inner join #tblTmpAttend att on ta.EmployeeID = att.EmployeeID and att.AttTime > m.AttEndYesterday and att.AttTime< m.AttStartTomorrow
   and (ta.Period >0 or (att.AttTime< m.AttEnd or m.AttEnd is null))

  where ta.Period = @RepeatTime and ta.TAStatus in(2, 0)  and (m.AttStart is not null or m.AttEnd is not null) and att.AttTime>= CASE WHEN @RepeatTime =0 THEN ISNULL(m.AttStart,AttTime) ELSE m.AttStart end
  and datediff(mi,m.WorkStart,att.AttTime) < 1320
  group by ta.EmployeeID,ta.AttDate
 ) tmp on ta.EmployeeID = tmp.EmployeeID and ta.AttDate = tmp.AttDate
 and ta.Period = @RepeatTime and ta.TAStatus in(2, 0)

 -- s?a l?i cho nhung gi? n?m trong kho?ng gi? ngh? trua
 --update ta set AttStart = att.AttTime
 update #tblHasTA_insert set AttStart = t.AttTime from #tblHasTA_insert ta inner join (
 select ta.EmployeeID, ta.Attdate,ta.Period, max(att.AttTime) AttTime
 from #tblHasTA_insert ta
 inner join #tblTmpAttend att on ta.EmployeeID = att.EmployeeID and att.AttTime > ta.AttStart and att.AttTime < DATEADD(mi,ta.BreakEndMi + 15,ta.Attdate)
 where ta.Period = @RepeatTime and DATEPART(hh, ta.AttStart) *60+DATEPART(mi,ta.Attstart) between ta.BreakStartMi and ta.BreakEndMi
 group by ta.EmployeeID, ta.Attdate,ta.Period
 ) t on ta.EmployeeID = t.EmployeeID and ta.Attdate = t.Attdate and ta.Period = t.Period

 -- s?a l?i nh?ng gi? vào quá s?m mà l?i ko có tang ca tru?c gi? làm

 delete att
 from #tblTmpAttend att
 where Exists (select 1 from #tblHasTA_insert ta where ta.Period = @RepeatTime and att.EmployeeID = ta.EmployeeID and att.AttTime = ta.AttStart)

 -- AttEnd
 update #tblHasTA_insert set AttEnd = tmp.AttTime
 from #tblHasTA_insert ta inner join (
  select ta.EmployeeID,ta.AttDate, min(att.AttTime) AttTime
  from #tblHasTA_insert ta
  inner join #tblShiftDetectorMatched m on ta.EmployeeID = m.EmployeeId and ta.AttDate = m.ScheduleDate
  inner join #tblTmpAttend att on ta.EmployeeID = att.EmployeeID and ta.AttStart < att.AttTime and (datediff(mi,ta.AttStart,att.AttTime) >= isnull(m.INOUT_MINIMUM,1) or (ta.AttStart is null and att.AttTime > m.AttEndYesterday)) and att.AttTime< m.AttStartTomorrow
   and not exists(select 1 from #tblTmpAttend att1 where ta.EmployeeID = att1.EmployeeID and att.AttState = att1.AttState and att1.Atttime > dateadd(mi,5,att.AttTime) and att1.AttTime < att.AttTime)
  inner join #tblShiftSetting ss on m.ShiftCode = ss.ShiftCode
  where ta.Period = @RepeatTime and ta.TAStatus in (1, 0)
   and att.AttTime < isnull(m.TIMEOUTAFTER,m.AttEnd) and att.AttTime > m.WorkStart
   and datediff(mi,isnull(ta.AttStart,m.WorkStart),att.AttTime) >= isnull(m.INOUT_MINIMUM,0)
  group by ta.EmployeeID,ta.AttDate
 ) tmp on ta.EmployeeID = tmp.EmployeeID and ta.AttDate = tmp.AttDate
 and ta.Period = @RepeatTime and ta.TAStatus in (1, 0)


 -- n?u không l?y du?c gi? ra thì l?y gi? ra cu?i ngày
  update #tblHasTA_insert set AttEnd = m.AttEnd
from #tblHasTA_insert ta
 inner join #tblShiftDetectorMatched m on ta.EmployeeId = m.EmployeeID and ta.AttDate = m.ScheduleDate
 where ta.Period = @RepeatTime and ta.TAStatus in(1, 0) and ta.AttEnd is null
 and (ta.AttStart < m.AttEnd or (ta.AttStart is null and ta.Period = 0))



 -- period 0 ko lay dc gio vao thi lay trong #tblShiftDetectorMatched
 update #tblHasTA_insert set AttStart = m.AttStart
 from #tblHasTA_insert ta
 inner join #tblShiftDetectorMatched m on ta.EmployeeId = m.EmployeeID and ta.AttDate = m.ScheduleDate
 where ta.Period = 0 and ta.TAStatus in(0,2) and ta.AttStart is null
 and (ta.AttEnd > m.AttStart or ta.AttEnd is null)

 -- ngh? c? ngày mà b?m thi?u d?u thì b?
 update m set AttStart = null, AttEnd = null from #tblHasTA_insert m where ((m.AttStart is not null and m.AttEnd is null ) or (m.AttStart is null and m.AttEnd is not null))
 and exists (select 1 from #tblLvHistory lv where lv.LeaveCategory = 1 and lv.EmployeeID = m.EmployeeId and m.AttDate = lv.LeaveDate and lv.LeaveStatus = 3)


 -- lo?i b? nh?ng em dã xong vi?c
 delete m from #tblShiftDetectorMatched m where exists (select 1 from #tblHasTA_insert ta
 where ta.Period = @RepeatTime and ta.EmployeeID = m.EmployeeId and ta.AttDate = m.ScheduleDate and (ta.AttEnd >= m.AttEnd or (ta.AttStart = m.AttStart and m.AttEnd is null)))
  or (m.AttStart is null and m.AttEnd is null)
DELETE m from #tblShiftDetectorMatched m where exists (select 1 from #tblHasTA_insert ta
 where ta.Period = @RepeatTime and ta.EmployeeID = m.EmployeeId and ta.AttDate = m.ScheduleDate and (ta.AttStart >= m.AttEnd))

 if exists (select 1 from #tblShiftDetectorMatched) and @RepeatTime < 7
 begin
  update m set AttEndYesterday = ta.AttEnd
  from #tblShiftDetectorMatched m
  inner join #tblHasTA_insert ta on m.EmployeeId = ta.EmployeeID and m.ScheduleDate = ta.AttDate where ta.Period = @RepeatTime
  set @RepeatTime += 1
  goto RepeatInsertHasTAOption0
 end
end

delete from #tblHasTA_insert where AttStart is null and AttEnd is null and Period > 0
if @TA_IO_SWIPE_OPTION = 1 -- Ngày b?m 2 l?n Vào làm b?m công, v? b?m công
begin

-- vao thì lấy sớm nhất, ra thì lấy trễ nhất
 update #tblShiftDetectorMatched set AttEnd = tmp.AttTime from #tblShiftDetectorMatched m inner join (
 SELECT m.EmployeeId, m.ScheduleDate, max(t.AttTime) AttTime from #tblShiftDetectorMatched m inner join #tblTmpAttend_Org t on m.EmployeeId = t.EmployeeID
 where ((t.AttTime > m.AttEnd and t.AttTime < m.TIMEOUTAFTER )or m.AttEnd is null) and t.AttTime < m.AttStartTomorrow
 and t.AttTime > m.AttEndYesterday
 and (t.AttTime > m.AttStart or m.AttStart is null)
 and (t.AttTime >= dateadd(mi, @TA_INOUT_MINIMUM, m.AttStart))
 AND DATEDIFF(hh,m.WorkEnd,t.AttTime) <= 6 --wtc: giờ ra k đc cách quá xa so với giờ kết thúc ca
 group by m.EmployeeId,m.ScheduleDate
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate


 update #tblShiftDetectorMatched set AttStart = tmp.AttTime from #tblShiftDetectorMatched m inner join (
 SELECT m.EmployeeId, m.ScheduleDate, min(t.AttTime) AttTime from #tblShiftDetectorMatched m
 INNER join #tblTmpAttend_Org t on m.EmployeeId = t.EmployeeID
 where ((t.AttTime < m.AttStart and t.AttTime > m.TIMEINBEFORE) or AttStart is null)
 and t.AttTime > m.AttEndYesterday and t.atttime < dateadd(mi,-30,m.AttStartTomorrow)
 and t.AttTime < m.AttEnd
 AND DATEDIFF(hh,t.AttTime,m.WorkStart) <= 6 --wtc:gio vào k được cách quá xa so với giờ bắt đầu ca
 group by m.EmployeeId,m.ScheduleDate
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate




 DELETE tblHasTA FROM tblHasTA TA WHERE TA.Period > 0
 AND EXISTS (SELECT 1 FROM #tblShiftDetectorMatched M WHERE TA.EmployeeID = M.EmployeeId and ta.AttDate = m.ScheduleDate AND M.ScheduleDate between @FromDate and @ToDate)
  and isnull(ta.TAStatus,0) <> 3
 and not exists(select 1 from #tblWSchedule ws where ta.EmployeeID = ws.EmployeeID and ta.AttDate = ws.ScheduleDate and ws.DateStatus = 3)

 insert into #tblHasTA_insert(EmployeeID,AttDate,Period,TAStatus
 ,WorkingTime,StdWorkingTimeMi)
 select EmployeeID,ScheduleDate,@RepeatTime,0
 ,case when HolidayStatus = 0 then WorkingTimeMi/60.0 else (AttEndMi - AttStartMi)/60.0 end , StdWorkingTimeMi from #tblShiftDetectorMatched where ScheduleDate between @FromDate and @ToDate



 -- Nh?ng anh em dã du?c ngu?i dùng xác nh?n gi? vào ra r?i thì không d?ng vào
 update #tblHasTA_insert set TAStatus= a.TAStatus,AttStart = a.AttStart, AttEnd = a.AttEnd from #tblHasTA_insert ta inner join #tblHasTA a on ta.EmployeeID = a.EmployeeID and ta.AttDate = a.AttDate and ta.Period = a.Period
 where a.TAStatus = 3 and a.AttDate between @FromDate and @ToDate

 update #tblHasTA_insert set AttStart = m.AttStart, AttEnd = m.AttEnd from #tblHasTA_insert ta inner join #tblShiftDetectorMatched m on ta.EmployeeId = m.EmployeeID and ta.AttDate = m.ScheduleDate
 where ta.Period = @RepeatTime and ta.TAStatus = 0

 -- ngh? c? ngày mà b?m thi?u d?u thì b?
 update m set AttStart = null, AttEnd = null from #tblHasTA_insert m where ((m.AttStart is not null and m.AttEnd is null ) or (m.AttStart is null and m.AttEnd is not null))
 and exists (select 1 from #tblLvHistory lv where lv.LeaveCategory = 1 and lv.EmployeeID = m.EmployeeId and m.AttDate = lv.LeaveDate and lv.LeaveStatus = 3)

end


if @TA_IO_SWIPE_OPTION = 2 --Sang bam, trua bam, chieu bam, tang ca bam

BEGIN
--1. xử lý giống Bấm tự do
 update #tblShiftDetectorMatched set AttEndYesterday = dateadd(mi,10,AttEndYesterday),AttStartTomorrow= dateadd(mi,-10,AttStartTomorrow)
 RepeatInsertHasTAOption2:
 --EmployeeID,AttDate,Period,AttStart,AttEnd,WorkingTime,TAStatus
 insert into #tblHasTA_insert(EmployeeID,AttDate,Period,TAStatus,WorkingTime,StdWorkingTimeMi,BreakStartMi,BreakEndMi,WorkStartMi,WorkEndMi)
 select EmployeeID,ScheduleDate,@RepeatTime,0,WorkingTimeMi/60.0,StdWorkingTimeMi,BreakStartMi,BreakEndMi, WorkStartMi,WorkEndMi from #tblShiftDetectorMatched where ScheduleDate between @FromDate and @ToDate
 -- Nh?ng anh em dã du?c ngu?i dùng xác nh?n gi? vào ra r?i thì không d?ng vào
 update #tblHasTA_insert set TAStatus= a.TAStatus,AttStart = a.AttStart, AttEnd = a.AttEnd from #tblHasTA_insert ta inner join #tblHasTA a on ta.EmployeeID = a.EmployeeID and ta.AttDate = a.AttDate and ta.Period = a.Period
 where a.TAStatus = 3 and a.AttDate between @FromDate and @ToDate
-- AttStart
 update #tblHasTA_insert set AttStart = tmp.AttTime from #tblHasTA_insert ta inner join (
  select ta.EmployeeID,ta.AttDate, min(att.AttTime) AttTime
  from #tblHasTA_insert ta
  inner join #tblShiftDetectorMatched m on ta.EmployeeID = m.EmployeeId and ta.AttDate = m.ScheduleDate
  inner join #tblTmpAttend att on ta.EmployeeID = att.EmployeeID and att.AttTime > m.AttEndYesterday and att.AttTime< m.AttStartTomorrow
   and (Period >0 or (att.AttTime< m.AttEnd or m.AttEnd is null))
  --inner join #tblShiftSetting ss on m.ShiftCode = ss.ShiftCode
  where ta.Period = @RepeatTime and ta.TAStatus = 0 and att.AttTime>= CASE WHEN @RepeatTime =0 THEN ISNULL(m.AttStart,AttTime) ELSE m.AttStart end
  group by ta.EmployeeID,ta.AttDate
 ) tmp on ta.EmployeeID = tmp.EmployeeID and ta.AttDate = tmp.AttDate
 and ta.Period = @RepeatTime and ta.TAStatus = 0

 -- s?a l?i cho nhung gi? n?m trong kho?ng gi? ngh? trua
 --update ta set AttStart = att.AttTime
 update #tblHasTA_insert set AttStart = t.AttTime from #tblHasTA_insert ta inner join (
 select ta.EmployeeID, ta.Attdate,ta.Period, max(att.AttTime) AttTime
 from #tblHasTA_insert ta
 inner join #tblTmpAttend att on ta.EmployeeID = att.EmployeeID and att.AttTime > ta.AttStart and att.AttTime < DATEADD(mi,ta.BreakEndMi + 15,ta.Attdate)
 where ta.Period = @RepeatTime and DATEPART(hh, ta.AttStart) *60+DATEPART(mi,ta.Attstart) between ta.BreakStartMi and ta.BreakEndMi
 group by ta.EmployeeID, ta.Attdate,ta.Period
 ) t on ta.EmployeeID = t.EmployeeID and ta.Attdate = t.Attdate and ta.Period = t.Period
 -- s?a l?i nh?ng gi? vào quá s?m mà l?i ko có tang ca tru?c gi? làm
 --delete att
 ----select att.*
 --from #tblHasTA_insert ta
 --inner join #tblShiftDetectorMatched m on ta.EmployeeID = ta.EmployeeID and ta.Attdate = m.ScheduleDate and (m.OTBeforeStart = m.OTBeforeEnd)
 --inner join #tblTmpAttend att on ta.EmployeeID = att.EmployeeID
 --where ta.Period = @RepeatTime and att.AttTime < m.WorkStart and att.AttTime > ta.AttStart

 delete att
 from #tblTmpAttend att
 where Exists (select 1 from #tblHasTA_insert ta where ta.Period = @RepeatTime and att.EmployeeID = ta.EmployeeID and att.AttTime = ta.AttStart)
 -- AttEnd
 update #tblHasTA_insert set AttEnd = tmp.AttTime
 from #tblHasTA_insert ta inner join (
  select ta.EmployeeID,ta.AttDate, min(att.AttTime) AttTime
  from #tblHasTA_insert ta
  inner join #tblShiftDetectorMatched m on ta.EmployeeID = m.EmployeeId and ta.AttDate = m.ScheduleDate
  inner join #tblTmpAttend att on ta.EmployeeID = att.EmployeeID and ta.AttStart < att.AttTime and (datediff(mi,ta.AttStart,att.AttTime) >= m.INOUT_MINIMUM or (ta.AttStart is null and att.AttTime > m.AttEndYesterday)) and att.AttTime< m.AttStartTomorrow
and not exists(select 1 from #tblTmpAttend att1 where ta.EmployeeID = att1.EmployeeID and att.AttState = att1.AttState and att1.Atttime > dateadd(mi,5,att.AttTime) and att1.AttTime < att.AttTime)
  inner join #tblShiftSetting ss on m.ShiftCode = ss.ShiftCode
  where ta.Period = @RepeatTime and ta.TAStatus = 0
   and att.AttTime < m.TIMEOUTAFTER
  group by ta.EmployeeID,ta.AttDate
 ) tmp on ta.EmployeeID = tmp.EmployeeID and ta.AttDate = tmp.AttDate
 and ta.Period = @RepeatTime and ta.TAStatus = 0


 --select DATEPART(hh, ta.AttStart) *60+DATEPART(mi,ta.Attstart),ta.BreakStartMi , ta.BreakEndMi,  * from #tblShiftDetectorMatched ta order by ScheduleDate
 --select DATEPART(hh, ta.AttStart) *60+DATEPART(mi,ta.Attstart),ta.BreakStartMi , ta.BreakEndMi,  * from #tblHasTA_insert ta order by EmployeeID, Attdate,Period

 -- n?u không l?y du?c gi? ra thì l?y gi? ra cu?i ngày
  update #tblHasTA_insert set AttEnd = m.AttEnd
 from #tblHasTA_insert ta
 inner join #tblShiftDetectorMatched m on ta.EmployeeId = m.EmployeeID and ta.AttDate = m.ScheduleDate
 where ta.Period = @RepeatTime and ta.TAStatus = 0 and ta.AttEnd is null
 and (ta.AttStart < m.AttEnd or (ta.AttStart is null and ta.Period = 0))
 -- period 0 ko lay dc gio vao thi lay trong #tblShiftDetectorMatched
 update #tblHasTA_insert set AttStart = m.AttStart
 from #tblHasTA_insert ta
 inner join #tblShiftDetectorMatched m on ta.EmployeeId = m.EmployeeID and ta.AttDate = m.ScheduleDate
 where ta.Period = 0 and ta.TAStatus = 0 and ta.AttStart is null
 and (ta.AttEnd > m.AttStart or ta.AttEnd is null)
 -- ngh? c? ngày mà b?m thi?u d?u thì b?
 update m set AttStart = null, AttEnd = null from #tblHasTA_insert m where ((m.AttStart is not null and m.AttEnd is null ) or (m.AttStart is null and m.AttEnd is not null))
 and exists (select 1 from #tblLvHistory lv where lv.LeaveCategory = 1 and lv.EmployeeID = m.EmployeeId and m.AttDate = lv.LeaveDate and lv.LeaveStatus = 3)
 -- lo?i b? nh?ng em dã xong vi?c
 delete m from #tblShiftDetectorMatched m where exists (select 1 from #tblHasTA_insert ta
 where ta.Period = @RepeatTime and ta.EmployeeID = m.EmployeeId and ta.AttDate = m.ScheduleDate and (ta.AttEnd >= m.AttEnd or (ta.AttStart = m.AttStart and m.AttEnd is null)))
  or (m.AttStart is null and m.AttEnd is null)

DELETE m from #tblShiftDetectorMatched m where exists (select 1 from #tblHasTA_insert ta
 where ta.Period = @RepeatTime and ta.EmployeeID = m.EmployeeId and ta.AttDate = m.ScheduleDate and (ta.AttStart >= m.AttEnd))
 if exists (select 1 from #tblShiftDetectorMatched) and @RepeatTime < 7
 begin
  update m set AttEndYesterday = ta.AttEnd
  from #tblShiftDetectorMatched m
  inner join #tblHasTA_insert ta on m.EmployeeId = ta.EmployeeID and m.ScheduleDate = ta.AttDate where ta.Period = @RepeatTime
  set @RepeatTime += 1
  goto RepeatInsertHasTAOption2
 END
 -- sửa lại giờ theo đúng các mốc vào ca, nghỉ giữa ca, ra ca
 update #tblHasTA_insert SET AttEnd = AttStart, AttStart = null WHERE Period = 1 and AttEnd IS NULL AND ABS(DATEPART(HOUR,AttStart)*60+DATEPART(MINUTE,AttStart) - WorkEndMi) < 240

 UPDATE i2 SET AttStart = i1.AttEnd FROM #tblHasTA_insert i2 INNER JOIN #tblHasTA_insert i1 ON i2.EmployeeID = i1.EmployeeID AND i2.Attdate = i1.Attdate AND i2.Period - 1 = i1.Period
 WHERE i2.Period = 1 AND i2.AttStart IS NULL AND i1.AttEnd IS NOT NULL
 -- gần mốc giờ vào nghỉ tra
 AND ABS(DATEPART(HOUR,i1.AttEnd)*60+DATEPART(MINUTE,i1.AttEnd) - i1.BreakEndMi) < 16
 UPDATE i1 SET i1.AttEnd = null FROM #tblHasTA_insert i2 INNER JOIN #tblHasTA_insert i1 ON i2.EmployeeID = i1.EmployeeID AND i2.Attdate = i1.Attdate AND i2.Period - 1 = i1.Period
 WHERE i2.Period = 1 AND i2.AttStart = i1.AttEnd
 -- gần mốc giờ vào nghỉ tra
 AND ABS(DATEPART(HOUR,i1.AttEnd)*60+DATEPART(MINUTE,i1.AttEnd) - i1.BreakEndMi) < 16

 -- gần mốc giờ ra nghỉ trưa
 update #tblHasTA_insert SET AttEnd = AttStart, AttStart = null WHERE Period = 0 AND AttEnd IS NULL AND ABS(DATEPART(HOUR,AttStart)*60+DATEPART(MINUTE,AttStart) - BreakStartMi) < 16

end
if @TA_IO_SWIPE_OPTION = 3 --Sáng b?m, trua b?m, chi?u b?m và tang ca b?m công, lo?i này c?n l?y chính xác gi? vào, ra c?a 2 m?c, bu?i sáng, bu?i chi?u, còn tang ca thì l?y t? do
begin
-- cap nhat lai OTAfter neu chua co

 update m set OTAfterStart = DATEADD(mi,ss.OTAfterStartMi,m.ScheduleDate) from #tblShiftDetectorMatched m inner join #tblShiftSetting ss on m.ShiftCode = ss.ShiftCode where OTAfterStart is null
 update m set OTAfterEnd = DATEADD(mi,ss.OTAfterEndMi,m.ScheduleDate) from #tblShiftDetectorMatched m inner join #tblShiftSetting ss on m.ShiftCode = ss.ShiftCode where OTAfterEnd is null

 update m set OTBeforeStart = DATEADD(mi,ss.OTBeforeStartMi,m.ScheduleDate) from #tblShiftDetectorMatched m inner join #tblShiftSetting ss on m.ShiftCode = ss.ShiftCode where OTBeforeStart is null
 update m set OTBeforeEnd = DATEADD(mi,ss.OTBeforeEndMi,m.ScheduleDate) from #tblShiftDetectorMatched m inner join #tblShiftSetting ss on m.ShiftCode = ss.ShiftCode where OTBeforeEnd is null
 --alter table #tblHasTA_insert add AttEndYesterday datetime,AttStartTomorrow datetime

 -- buoi sang
 insert into #tblHasTA_insert(EmployeeID,AttDate,Period,TAStatus,WorkStart,WorkEnd,AttEndYesterday,AttStartTomorrow, TIMEINBEFORE, TIMEOUTAFTER, INOUT_MINIMUM
  , MinTimeIn, MaxTimeIn
  ,MaxTimeOut
  ,WorkingTime, StdWorkingTimeMi)
 select EmployeeID,ScheduleDate,0,0,WorkStart,BreakStart, AttEndYesterday,AttStartTomorrow, TIMEINBEFORE, TIMEOUTAFTER, INOUT_MINIMUM
  ,dateadd(MI,-@TA_TIMEINBEFORE,WorkStart),dateadd(mi,-datediff(mi,WorkStart,BreakStart)/2,BreakStart)
  ,dateadd(mi,datediff(mi,BreakStart,BreakEnd)/2,BreakEnd)
  ,case when HolidayStatus = 0 then WorkingTimeMi/60.0 else (AttEndMi - AttStartMi)/60.0 end, StdWorkingTimeMi
 from #tblShiftDetectorMatched where ScheduleDate between @FromDate and @ToDate
 update #tblHasTA_insert set MinTimeOut = DATEADD(SECOND,1,MaxTimeIn)

 -- gio vao
 update #tblHasTA_insert set AttStart = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, MIN(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttStart is null and m.TAStatus = 0
   and t.AttTime < m.WorkEnd
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   and t.AttTime between m.MinTimeIn and m.maxtimein
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period

 -- gio ra
 update #tblHasTA_insert set AttEnd = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, max(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttEnd is null and m.TAStatus = 0
   and t.AttTime > m.WorkStart
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   and t.AttTime between m.MinTimeOut and m.WorkEnd
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period

 update #tblHasTA_insert set AttEnd = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, min(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttEnd is null and m.TAStatus = 0
 and t.AttTime > m.WorkStart
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   and t.AttTime between m.WorkEnd and m.MaxTimeOut
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period

 update #tblHasTA_insert set AttEnd = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, max(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttEnd is null and m.TAStatus = 0
   and t.AttTime > m.WorkStart
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   and t.AttTime > m.AttStart and t.AttTime < m.MaxTimeOut
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period

 update #tblHasTA_insert set AttStart = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, min(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttStart is null and m.TAStatus = 0
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   and t.AttTime < m.AttEnd and t.AttTime > m.MinTimeIn
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period


 -- buoi chieu
 insert into #tblHasTA_insert(EmployeeID,AttDate,Period,TAStatus,WorkStart,WorkEnd,AttEndYesterday,AttStartTomorrow, TIMEINBEFORE, TIMEOUTAFTER, INOUT_MINIMUM
, MinTimeIn, MaxTimeIn
  ,MaxTimeOut
  ,WorkingTime, StdWorkingTimeMi)
 select EmployeeID,ScheduleDate,1,0,BreakEnd,WorkEnd,AttEndYesterday,AttStartTomorrow, TIMEINBEFORE, TIMEOUTAFTER, INOUT_MINIMUM
  ,dateadd(mi,-@TA_TIMEINBEFORE,BreakEnd),dateadd(mi,-datediff(mi,BreakEnd,WorkEnd)/2,WorkEnd)
  ,dateadd(mi,datediff(mi,WorkEnd,OTAfterStart)/2,WorkEnd)
  ,case when HolidayStatus = 0 then WorkingTimeMi/60.0 else (AttEndMi - AttStartMi)/60.0 end, StdWorkingTimeMi
 from #tblShiftDetectorMatched where ScheduleDate between @FromDate and @ToDate
 update #tblHasTA_insert set MinTimeOut = DATEADD(SECOND,1,MaxTimeIn) where MinTimeOut is null
 update m1 set AttEndYesterday = m2.AttEnd from #tblHasTA_insert m1 inner join #tblHasTA_insert m2 on m1.EmployeeId = m2.EmployeeId and m1.AttDate = m2.AttDate and m1.Period = m2.Period+1 --where (m2.AttEnd is not null)
 update m1 set AttStartTomorrow = isnull(m2.AttStart,m2.workStart) from #tblHasTA_insert m1 inner join #tblHasTA_insert m2 on m1.EmployeeId = m2.EmployeeId and m1.AttDate = m2.AttDate and m1.Period = m2.Period-1

 -- gio vao
 update #tblHasTA_insert set AttStart = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, MIN(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttStart is null and m.TAStatus = 0
   and t.AttTime < m.WorkEnd



   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   AND T.AttTime > m.AttEndYesterday and T.AttTime < m.AttStartTomorrow
   and t.AttTime between m.MinTimeIn and m.maxtimein
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period
 -- gio ra
 update #tblHasTA_insert set AttEnd = tmp.AttTime from #tblHasTA_insert m inner join (
 SELECT m.EmployeeId, m.AttDate,m.Period, max(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttEnd is null and m.TAStatus = 0
   and t.AttTime > m.WorkStart
   AND T.AttTime > m.AttEndYesterday and T.AttTime < m.AttStartTomorrow
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   and t.AttTime between m.MinTimeOut and m.WorkEnd
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period

 update #tblHasTA_insert set AttEnd = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, max(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
where m.AttEnd is null and m.TAStatus = 0
   and t.AttTime > m.WorkStart
   AND T.AttTime > m.AttEndYesterday and T.AttTime < m.AttStartTomorrow
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   and t.AttTime between m.WorkEnd and m.MaxTimeOut
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period

 update #tblHasTA_insert set AttEnd = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, max(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttEnd is null and m.TAStatus = 0
 and t.AttTime > m.WorkStart
   AND T.AttTime > m.AttEndYesterday and T.AttTime < m.AttStartTomorrow
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   and t.AttTime > m.AttStart and t.AttTime < m.MaxTimeOut
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period

 update #tblHasTA_insert set AttStart = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, min(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttStart is null and m.TAStatus = 0
   AND T.AttTime > m.AttEndYesterday and T.AttTime < m.AttStartTomorrow
AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER

 and t.AttTime < m.AttEnd and t.AttTime > m.MinTimeIn
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period


 -- tang ca sau
 insert into #tblHasTA_insert(EmployeeID,AttDate,Period,TAStatus,WorkStart,WorkEnd,AttEndYesterday,AttStartTomorrow, TIMEINBEFORE, TIMEOUTAFTER, INOUT_MINIMUM
  , MinTimeIn, MaxTimeIn,MaxTimeOut)
 select EmployeeID,ScheduleDate,2,0,OTAfterStart,OTAfterEnd,AttEndYesterday,AttStartTomorrow, TIMEINBEFORE, TIMEOUTAFTER, INOUT_MINIMUM
  ,dateadd(hour,-1,OTAfterStart),dateadd(mi,-datediff(mi,OTAfterStart,OTAfterEnd)/2,OTAfterEnd),TIMEOUTAFTER
 from #tblShiftDetectorMatched where ScheduleDate between @FromDate and @ToDate
 update #tblHasTA_insert set MinTimeOut = DATEADD(SECOND,1,MaxTimeIn) where MinTimeOut is null
 update m1 set AttEndYesterday = m2.AttEnd from #tblHasTA_insert m1 inner join #tblHasTA_insert m2 on m1.EmployeeId = m2.EmployeeId and m1.AttDate = m2.AttDate and m1.Period = m2.Period+1 --where (m2.AttEnd is not null )
  and m1.Period = 2
 update m1 set AttStartTomorrow = isnull(m2.AttStart,m2.workStart) from #tblHasTA_insert m1 inner join #tblHasTA_insert m2 on m1.EmployeeId = m2.EmployeeId and m1.AttDate = m2.AttDate and m1.Period = m2.Period-1
  where m1.Period = 2

 -- gio vao
 update #tblHasTA_insert set AttStart = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, MIN(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttStart is null and m.TAStatus = 0
   and m.Period = 2
and t.AttTime < m.WorkEnd
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   AND T.AttTime > m.AttEndYesterday and T.AttTime < m.AttStartTomorrow
   and t.AttTime between m.MinTimeIn and m.maxtimein
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period

 update #tblHasTA_insert set AttStart = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, max(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttStart is null and m.TAStatus = 0
   and m.Period = 2
   and t.AttTime < m.WorkEnd
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   AND m.AttEndYesterday is null and T.AttTime < m.AttStartTomorrow
   and t.AttTime between m.MinTimeIn and m.maxtimein
 group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period

 -- gio ra
 update #tblHasTA_insert set AttEnd = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, max(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttEnd is null and m.TAStatus = 0
   and m.Period = 2
   and t.AttTime > m.WorkStart


 AND (T.AttTime > m.AttEndYesterday or m.AttEndYesterday is null) and T.AttTime < m.AttStartTomorrow
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   and t.AttTime between m.MinTimeOut and m.WorkEnd
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period

 update #tblHasTA_insert set AttEnd = tmp.AttTime from #tblHasTA_insert m inner join (

  SELECT m.EmployeeId, m.AttDate,m.Period, min(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttEnd is null and m.TAStatus = 0
   and m.Period = 2
   and t.AttTime > m.WorkStart
   AND (T.AttTime > m.AttEndYesterday or m.AttEndYesterday is null) and T.AttTime < m.AttStartTomorrow
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   and t.AttTime between m.WorkEnd and m.MaxTimeOut
  group by m.EmployeeId, m.AttDate,m.Period

 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period

 update #tblHasTA_insert set AttEnd = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, max(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttEnd is null and m.TAStatus = 0
   and m.Period = 2
   and t.AttTime > m.WorkStart
   AND (T.AttTime > m.AttEndYesterday or m.AttEndYesterday is null) and T.AttTime < m.AttStartTomorrow
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
   and t.AttTime > m.AttStart and t.AttTime < m.MaxTimeOut
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period

 update #tblHasTA_insert set AttStart = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, min(t.AttTime) AttTime
  FROM #tblHasTA_insert m inner join #tblTmpAttend_org t on m.EmployeeId = t.EmployeeID
  where m.AttStart is null and m.TAStatus = 0
   and m.Period = 2
   AND (T.AttTime > m.AttEndYesterday or m.AttEndYesterday is null) and T.AttTime < m.AttStartTomorrow
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER
and t.AttTime < m.AttEnd and t.AttTime > m.MinTimeIn
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period


 -- liet ke ra nhung record bao vao cua period sau lay nham sang bam ra cua period truoc
 update t set AttEnd = s.AttStart from #tblHasTA_insert t inner join #tblHasTA_insert s on t.EmployeeID = s.EmployeeID and t.AttDate = s.AttDate
  and t.Period = s.Period - 1
 where t.AttEnd is null and t.AttStart is not null and t.Period <= 1
  and s.AttEnd is not null and s.AttStart is not null
  and exists (select 1 from #tblTmpAttend_Org att where att.EmployeeID = t.EmployeeID and att.AttTime > s.AttStart and att.AttTime < s.AttEnd )
 update t set AttEnd = s.AttStart from #tblHasTA_insert t inner join #tblHasTA_insert s on t.EmployeeID = s.EmployeeID and t.AttDate = s.AttDate
  and t.Period = s.Period - 1
 where t.AttEnd is null and t.AttStart is not null and t.Period <= 1
  and s.AttEnd is not null and s.AttStart is not null
  and exists (select 1 from #tblTmpAttend_Org att where att.EmployeeID = t.EmployeeID and att.AttTime > s.AttStart and att.AttTime < s.AttEnd )
 update m1 set AttEndYesterday = m2.AttEnd from #tblHasTA_insert m1 inner join #tblHasTA_insert m2 on m1.EmployeeId = m2.EmployeeId and m1.AttDate = m2.AttDate and m1.Period = m2.Period+1 --where (m2.AttEnd is not null)



 update #tblHasTA_insert set AttStart = tmp.AttTime from #tblHasTA_insert m inner join (
  SELECT m.EmployeeId, m.AttDate,m.Period, min(t.AttTime) AttTime
FROM #tblHasTA_insert m inner join #tblTmpAttend_Org t on m.EmployeeId = t.EmployeeID
  where m.TAStatus = 0
   and m.Period > 0
   AND T.AttTime > m.AttEndYesterday and T.AttTime < m.AttStartTomorrow
   AND T.AttTime BETWEEN m.TIMEINBEFORE and m.TIMEOUTAFTER

   and t.AttTime < m.AttEnd and t.AttTime > m.MinTimeIn
  group by m.EmployeeId, m.AttDate,m.Period
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.AttDate = tmp.AttDate and m.Period = tmp.Period
 where m.AttEndYesterday = m.AttStart

 -- Nh?ng anh em dã du?c ngu?i dùng xác nh?n gi? vào ra r?i thì không d?ng vào
 update #tblHasTA_insert set TAStatus= a.TAStatus,AttStart = a.AttStart, AttEnd = a.AttEnd from #tblHasTA_insert ta inner join #tblHasTA a on ta.EmployeeID = a.EmployeeID and ta.AttDate = a.AttDate and ta.Period = a.Period
 where a.TAStatus = 3 and a.AttDate between @FromDate and @ToDate
 --- co gang la gio ra cho buoi chieu
 update #tblHasTA_insert set AttEnd = tmp.AttTime from #tblHasTA_insert i inner join (
  select i.EmployeeID, i.AttDate, i.Period, MIN(att.AttTime) AttTime from #tblHasTA_insert i inner join #tblHasTA_insert t on i.employeeId = t.EmployeeId and i.AttDate = t.AttDate and t.Period = 2 and i.Period = 1
  inner join #tblTmpAttend_Org att on i.employeeId = att.EmployeeId and att.AttTime < t.AttStart and att.AttTime > i.MinTimeOut
  where i.Period = 1 and i.AttEnd is null
and t.AttStart is not null
  group by i.EmployeeID, i.AttDate, i.Period
 ) tmp on i.EmployeeId = tmp.EmployeeId and i.AttDate = tmp.AttDate and i.Period = tmp.Period


 -- lam dep lai du lieu

 update i1 set AttEnd = i2.AttStart from #tblHasTA_insert i1 inner join #tblHasTA_insert i2 on i1.employeeID = i2.EmployeeID and i1.AttDate = i2.AttDate
 where i1.Period = i2.Period -1 and i1.AttEnd is null and i2.AttStart is not null and i2.AttEnd is null
 update i2 set AttStart = null from #tblHasTA_insert i1 inner join #tblHasTA_insert i2 on i1.employeeID = i2.EmployeeID and i1.AttDate = i2.AttDate
 where i1.Period = i2.Period -1 and i1.AttEnd = i2.AttStart and i2.AttEnd is null
 update j set AttStart = i.AttEnd from #tblHasTA_insert i inner join #tblHasTA_insert j on i.EmployeeId = j.EmployeeId and i.AttDate = j.AttDate and i.Period = j.Period - 1
 where i.AttStart is null and i.AttEnd is not null and j.AttStart is null and j.AttEnd is not null and j.AttEnd > dateadd(hour,-1,j.WorkEnd)

 update i set AttEnd = null from #tblHasTA_insert i inner join #tblHasTA_insert j on i.EmployeeId = j.EmployeeId and i.AttDate = j.AttDate and i.Period = j.Period - 1
 where i.AttStart is null and i.AttEnd = j.AttStart and j.AttEnd is not null and j.AttEnd > dateadd(hour,-1,j.WorkEnd)

 --- co gang la gio vao cho buoi chieu
 update #tblHasTA_insert set AttStart = tmp.AttTime from #tblHasTA_insert i inner join (
  select i.EmployeeID, i.AttDate, i.Period, min(att.AttTime) AttTime from #tblHasTA_insert i
  inner join #tblHasTA_insert t on i.employeeId = t.EmployeeId and i.AttDate = t.AttDate and t.Period = 0 and i.Period = 1
  inner join #tblTmpAttend_Org att on i.employeeId = att.EmployeeId and att.AttTime > isnull(t.AttStart,t.MinTimeOut)-- and att.AttTime < i.AttEnd
  where i.Period = 1 and i.AttStart is null and i.AttEnd is not null
  group by i.EmployeeID, i.AttDate, i.Period
 ) tmp on i.EmployeeId = tmp.EmployeeId and i.AttDate = tmp.AttDate and i.Period = tmp.Period
 update #tblHasTA_insert set AttStart = null where period = 1 and AttStart = AttEnd and AttStart > MaxTimeIn
 -- khong co tang ca thi bo di
 delete #tblHasTA_insert where Period =2 and AttStart is null and AttEnd is null


end

if @TA_IO_SWIPE_OPTION = 4 -- Vao bam, nghi giua ca bam, ve bam
begin

 update #tblShiftDetectorMatched set AttEnd = tmp.AttTime from #tblShiftDetectorMatched m inner join (
 SELECT m.EmployeeId, m.ScheduleDate, max(t.AttTime) AttTime from #tblShiftDetectorMatched m inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where ((t.AttTime > m.AttEnd and t.AttTime < m.TIMEOUTAFTER )or m.AttEnd is null) and t.AttTime < m.AttStartTomorrow
 and t.AttTime > m.AttEndYesterday
 and (t.AttTime > m.AttStart or m.AttStart is null)
 and (t.AttTime >= dateadd(mi, @TA_INOUT_MINIMUM, m.AttStart))
 group by m.EmployeeId,m.ScheduleDate
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate

 update #tblShiftDetectorMatched set AttStart = tmp.AttTime from #tblShiftDetectorMatched m inner join (
 SELECT m.EmployeeId, m.ScheduleDate, min(t.AttTime) AttTime from #tblShiftDetectorMatched m inner join #tblTmpAttend t on m.EmployeeId = t.EmployeeID
 where ((t.AttTime < m.AttStart and t.AttTime > m.TIMEINBEFORE) or AttStart is null)
 and t.AttTime > m.AttEndYesterday and t.atttime < dateadd(mi,-30,m.AttStartTomorrow)
 and t.AttTime < m.AttEnd
 group by m.EmployeeId,m.ScheduleDate
 ) tmp on m.EmployeeId = tmp.EmployeeId and m.ScheduleDate = tmp.ScheduleDate


 --hôm tru?c thi?u d? li?u công mà gi? v? trùng v?i gi? vào hôm sau
 update m1 set AttEnd = null from #tblShiftDetectorMatched m1 inner join #tblShiftDetectorMatched m2 on m1.EmployeeId = m2.EmployeeId and m1.ScheduleDate+1 = m2.ScheduleDate
 where m1.AttStart is null and m1.AttEnd = m2.AttStart


 DELETE tblHasTA FROM tblHasTA TA WHERE TA.Period > 0
 AND EXISTS (SELECT 1 FROM #tblShiftDetectorMatched M WHERE TA.EmployeeID = M.EmployeeId and ta.AttDate = m.ScheduleDate AND M.ScheduleDate between @FromDate and @ToDate)
 and isnull(ta.TAStatus,0) <> 3
 and not exists(select 1 from tblWSchedule ws where ta.EmployeeID = ws.EmployeeID and ta.AttDate = ws.ScheduleDate and ws.DateStatus = 3)

 insert into #tblHasTA_insert(EmployeeID,AttDate,Period,TAStatus
 ,WorkingTime,StdWorkingTimeMi,BreakStartMi,BreakEndMi)
 select EmployeeID,ScheduleDate,@RepeatTime,0
 ,case when HolidayStatus = 0 then WorkingTimeMi/60.0 else (AttEndMi - AttStartMi)/60.0 end , StdWorkingTimeMi,BreakStartMi,BreakEndMi from #tblShiftDetectorMatched where ScheduleDate between @FromDate and @ToDate

 -- Nh?ng anh em dã du?c ngu?i dùng xác nh?n gi? vào ra r?i thì không d?ng vào
 update #tblHasTA_insert set TAStatus= a.TAStatus,AttStart = a.AttStart, AttEnd = a.AttEnd from #tblHasTA_insert ta inner join #tblHasTA a on ta.EmployeeID = a.EmployeeID and ta.AttDate = a.AttDate and ta.Period = a.Period
where a.TAStatus = 3 and a.AttDate between @FromDate and @ToDate

 update #tblHasTA_insert set AttStart = m.AttStart, AttEnd = m.AttEnd from #tblHasTA_insert ta inner join #tblShiftDetectorMatched m on ta.EmployeeId = m.EmployeeID and ta.AttDate = m.ScheduleDate
 where ta.Period = @RepeatTime and ta.TAStatus = 0


 -- ngh? c? ngày mà b?m thi?u d?u thì b?
 update m set AttStart = null, AttEnd = null from #tblHasTA_insert m where ((m.AttStart is not null and m.AttEnd is null ) or (m.AttStart is null and m.AttEnd is not null))
 and exists (select 1 from #tblLvHistory lv where lv.LeaveCategory = 1 and lv.EmployeeID = m.EmployeeId and m.AttDate = lv.LeaveDate and lv.LeaveStatus = 3)

 UPDATE #tblHasTA_insert SET AttMiddle = tmp.AttTime
 FROM #tblHasTA_insert  t INNER JOIN
 (SELECT min (att.AttTime) AttTime, ta.EmployeeID, ta.Attdate FROM #tblHasTA_insert ta INNER JOIN #tblTmpAttend att ON ta.EmployeeID = att.EmployeeID  AND att.AttTime > ta.AttStart AND att.AttTime < ta.AttEnd AND DATEPART(HOUR,att.AttTime)*60+DATEPART(MINUTE,att.AttTime) BETWEEN ta.BreakStartMi AND ta.BreakEndMi GROUP BY ta.EmployeeID, ta.Attdate)
 tmp ON t.EmployeeID = tmp.EmployeeID AND t.Attdate = tmp.Attdate
  UPDATE #tblHasTA_insert SET AttMiddle = tmp.AttTime
 FROM #tblHasTA_insert  t INNER JOIN
 (SELECT min (att.AttTime) AttTime, ta.EmployeeID, ta.Attdate FROM  #tblHasTA_insert ta INNER JOIN #tblTmpAttend att ON ta.EmployeeID = att.EmployeeID AND att.AttTime > ta.AttStart AND att.AttTime < ta.AttEnd AND ta.AttMiddle IS NULL GROUP BY ta.EmployeeID, ta.Attdate)
 tmp ON t.EmployeeID = tmp.EmployeeID AND t.Attdate = tmp.Attdate

 update #tblHasTA_insert set AttMiddle = null where DATEDIFF(MI,Attstart,AttMiddle) < 60 or DATEDIFF(MI,AttMiddle,AttEnd) < 60

update #tblHasTA_insert set AttMiddle = null where DATEDIFF(MI,AttDate,AttMiddle) - AttStartMi < 60 or AttEndMi - DATEDIFF(MI,AttDate,AttMiddle) < 60
end


-- bo nhung du lieu ko hop le
DELETE I2 from #tblHasTA_insert i1 inner join #tblHasTA_insert i2 on i1.employeeID = i2.EmployeeID and i1.AttDate = i2.AttDate
 where i1.Period = i2.Period -1 and i1.AttEnd >= i2.AttStart

-- sua lai PeriodID cho nhung record đã fix
update ta SET Period = f.Period FROM #tblHasTA_insert ta INNER JOIN #tblHasTA_Fixed f ON ta.EmployeeID = f.EmployeeID  AND ta.Attdate = f.Attdate AND ta.AttStart = f.AttStart AND ta.Period <> f.Period

alter table #tblHasta_insert add WorkingTimeMi int,IsLeaveStatus3 int

update #tblHasTA_insert set IsLeaveStatus3 = 0
update ta1 set IsLeaveStatus3= case when lv.LeaveStatus = 3 then 1 else 0 end
from #tblHasTA_insert ta1
inner join tbllvhistory lv on ta1.EmployeeID = lv.EmployeeID and ta1.Attdate = lv.LeaveDate

--wtc:nghi FWC thi mac dinh them full ngay cong
/*
UPDATE ta SET AttStart = isnull(ta.AttStart,ta.Attdate + CAST(ss.WorkStart AS TIME))
, ta.AttEnd = isnull(ta.AttEnd,CASE WHEN ss.WorkStart > ss.WorkEnd THEN DATEADD(dd,1,ta.Attdate) + CAST(ss.WorkEnd AS TIME) ELSE ta.Attdate + CAST(ss.WorkEnd AS TIME) END)
 FROM #tblHasTA_insert ta
INNER JOIN tblWSchedule ws ON ta.EmployeeID = ws.EmployeeID AND ta.Attdate = ws.ScheduleDate
LEFT JOIN tblShiftSetting ss ON ss.ShiftID = ws.ShiftID
WHERE EXISTS(SELECT 1 FROM tblLvHistory lv WHERE ta.EmployeeID = lv.EmployeeID AND ta.Attdate = lv.LeaveDate AND lv.LeaveCode ='FWC')
AND (ta.AttStart IS NULL OR ta.AttEnd IS NULL)
*/
if(OBJECT_ID('sp_ShiftDetector_UpdateHasTA_ChangeAttTime' )is null)
begin
exec('CREATE PROCEDURE sp_ShiftDetector_UpdateHasTA_ChangeAttTime
(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUpdate = 0
exec sp_ShiftDetector_UpdateHasTA_ChangeAttTime @StopUpdate output ,@LoginID,@FromDate,@ToDate

IF @StopUpdate = 0
BEGIN
update ta1 set AttEndMi = datepart(hour,AttEnd)* 60 + datepart(mi,AttEnd) + CASE WHEN DATEPART(SECOND,AttEnd) >= 30 THEN 1 ELSE 0 END  --wtc:gio ve neu giây >=30 thì làm tròn phút lên
 ,AttStartMi = datepart(hour,AttStart )* 60 + datepart(mi,AttStart)
 ,WorkStartMi = datepart(hour,ss.WorkStart )* 60 + datepart(mi,ss.WorkStart)
 ,WorkEndMi = datepart(hour,ss.WorkEnd)* 60 + datepart(mi,ss.WorkEnd)
 ,BreakStartMi = datepart(hour,ss.BreakStart)* 60 + datepart(mi,ss.BreakStart)
 ,BreakEndMi = datepart(hour,ss.BreakEnd)* 60 + datepart(mi,ss.BreakEnd)
 ,ShiftCode = ss.ShiftCode
from #tblHasTA_insert ta1
inner join tblWSchedule ws on ta1.EmployeeID = ws.EmployeeID and ta1.AttDate = ws.ScheduleDate
inner join tblShiftSetting ss on ws.ShiftID = ss.ShiftID
END


update #tblHasTA_insert set BreakStartMi = 1440+BreakStartMi where BreakStartMi < WorkStartMi and WorkStartMi > WorkEndMi
update #tblHasTA_insert set BreakEndMi = 1440+BreakEndMi where BreakEndMi < WorkStartMi and WorkStartMi > WorkEndMi
update #tblHasTA_insert set WorkEndMi  += 1440 where WorkEndMi  < WorkStartMi
update #tblHasTA_insert set BreakEndMi += 1440 where BreakEndMi < BreakStartMi
update #tblHasTA_insert set AttStartMi += 1440 where AttStartMi < WorkStartMi and DATEDIFF(day,AttDate,AttStart) > 0
update #tblHasTA_insert set AttEndMi   += 1440 where AttEndMi   < AttStartMi

--làm vi?c xuyên màn dêm
update #tblHasTA_insert set AttEndMi += 1440 where AttEndMi - AttStartMi < 300 and DATEDIFF(day,AttStart,AttEnd) > 0 and AttEndMi < 1440

if @MATERNITY_LATE_EARLY_OPTION = 1
 update ta1 set AttStartMi = case when AttStartMi > WorkStartMi then case when AttStartMi - WorkStartMi <= 30 then WorkStartMi else AttStartMi - @MATERNITY_MUNITE end else AttStartMi end
 from #tblHasTA_insert ta1 where AttStartMi is not null and AttEndMi is not null and ta1.Period = 0
 and exists (select 1 from #tblPendingImportAttend p where ta1.EmployeeID = p.EmployeeID and ta1.AttDate = p.Date and p. EmployeeStatusID in (10,11))
else
if @MATERNITY_LATE_EARLY_OPTION = 2
 update ta1 set AttEndMi = case when AttEndMi < WorkEndMi then case when WorkEndMi - AttStartMi <= 30 then WorkEndMi else AttEndMi + @MATERNITY_MUNITE end else AttEndMi end
 from #tblHasTA_insert ta1 where AttStartMi is not null and AttEndMi is not null and ta1.Period = 0
 and exists (select 1 from #tblPendingImportAttend p where ta1.EmployeeID = p.EmployeeID and ta1.AttDate = p.Date and p. EmployeeStatusID in (10,11))
else
if @MATERNITY_LATE_EARLY_OPTION = 3
 update ta1 set AttEndMi = case when WorkEndMi- AttEndMi >= AttStartMi - WorkStartMi and AttEndMi < WorkEndMi then case when WorkEndMi- AttStartMi <= 30 then WorkEndMi else AttEndMi + @MATERNITY_MUNITE end else AttEndMi end
  ,AttStartMi = case when WorkEndMi- AttEndMi < AttStartMi - WorkStartMi and AttStartMi > WorkStartMi then case when AttStartMi - WorkStartMi <= 30 then WorkStartMi else AttStartMi - @MATERNITY_MUNITE end else AttStartMi end
 from #tblHasTA_insert ta1 where AttStartMi is not null and AttEndMi is not null and ta1.Period = 0
 and exists (select 1 from #tblPendingImportAttend p where ta1.EmployeeID = p.EmployeeID and ta1.AttDate = p.Date and p. EmployeeStatusID in (10,11))



-- UPDATE LATE_PERMIT AND EARLY_PERMIT

 -- update LATE_PERMIT,EARLY_PERMIT của bảng #tblHasTA_insert , Lần lượt trả về kết quả nếu tồn tại theo thứ tự Position,Section,Department,Division
 update sd
set sd.Late_Permit = COALESCE(p.LATE_PERMIT, sc.LATE_PERMIT, dp.LATE_PERMIT,d.LATE_PERMIT)
,sd.Early_Permit = COALESCE(p.Early_Permit, sc.Early_Permit, dp.Early_Permit,d.Early_Permit)
 from #tblHasTA_insert sd
 left join #tblEmployeeList s on s.EmployeeID = sd.EmployeeId
 left join tblDivision d on d.DivisionID = s.DivisionID
 left join tblDepartment dp on dp.DepartmentID = s.DepartmentID
 left join tblSection sc on sc.SectionID = s.SectionID
 left join tblPosition p on p.PositionID = s.PositionID

 -- Update #tblHasTA_insert
update hi
-- Dành tất cả cho AttStartMi .
set AttStartMi =
 -- Nếu là ca 1
 case when AttStartMi + Late_Permit <= BreakEndMi
 then
 -- DÙng WorkStartMi so sánh cho AttStartMi
 -- Nếu AttStartMi <= WorkStartMi + Late_Permit -> Trả về WorkStartMi ngược lại trả về AttStartMi
 case when AttStartMi BETWEEN WorkStartMi AND WorkStartMi + Late_Permit then WorkStartMi else AttStartMi end
 else
 -- Dùng BreakEndMi so sánh cho AttStartMi
 -- Nếu AttStartMi <= WorkStartMi + Late_Permit -> Trả về WorkStartMi ngược lại trả về AttStartMi
 case when AttStartMi BETWEEN BreakEndMi AND BreakEndMi + Late_Permit  then BreakEndMi else AttStartMi end
 end,
-- Dành tất cả cho AttEndMi
    AttEndMi =
 -- Nếu là ca 1
 case when AttEndMi + Early_Permit <= BreakEndMi
 then
 -- DÙng BreakStartMi so sánh cho AttEndMi ( Bởi hiện tại BreakStartMi đại diện cho giờ kết thúc ca 1 )
 -- Nếu AttEndtMi <= BreakStartMi - Early_Permit -> Trả về BreakStartMi ngược lại trả về AttEndMi
 case when AttEndMi BETWEEN BreakStartMi - Early_Permit AND BreakStartMi then  BreakStartMi else AttEndMi end
 else
 -- DÙng BreakStartMi so sánh cho AttEndMi ( Bởi hiện tại BreakStartMi đại diện cho giờ kết thúc ca 1 )
 -- Nếu AttEndtMi <= BreakStartMi - Early_Permit -> Trả về BreakStartMi ngược lại trả về AttEndMi
 case when AttEndMi BETWEEN WorkEndMi - Early_Permit AND WorkEndMi then case when AttEndMi < WorkEndMi then WorkEndMi else AttEndMi end else AttEndMi end
 end
from #tblHasTA_insert hi



update #tblHasTA_insert set WorkingTimeMi =
 case
 when AttEndMi >= WorkEndMi then WorkEndMi
 when AttEndMi >= BreakEndMi then AttEndMi

 when AttEndMi >= BreakStartMi then BreakStartMi
 when AttEndMi >= WorkStartMi then AttEndMi else WorkStartMi end
- case
 when AttStartMi <= WorkStartMi then WorkStartMi
 when AttStartMi < BreakStartMi then AttStartMi
 when AttStartMi <= BreakEndMi then BreakEndMi
 when AttStartMi <= WorkEndMi then AttStartMi else WorkEndMi end
,StdWorkingTimeMi = WorkEndMi - WorkStartMi - (BreakEndMi - BreakStartMi)
where AttStartMi is not null and AttEndMi is not null
--update m set StdWorkingTimeMi = StdWorkingTimeMi - lv.LvAmount*60.0
--from #tblHasTA_insert m
--inner join (select EmployeeID,LeaveDate, sum(LvAmount) LvAmount
--from #tblLvHistory where PaidRate > 0 group by EmployeeID,LeaveDate) lv on lv.EmployeeID = m.EmployeeId

--and m.attdate = lv.LeaveDate
--where StdWorkingTimeMi is not null and m.IsLeaveStatus3 <> 1


update #tblHasTA_insert set StdWorkingTimeMi = 480
where isnull(StdWorkingTimeMi,0) <= 0

UPDATE #tblHasTA_insert set WorkingTimeMi = WorkingTimeMi - (BreakEndMi - BreakStartMi)
WHERE BreakStartMi < BreakEndMi AND AttStartMi < BreakStartMi AND AttEndMi > BreakEndMi
and AttStartMi is not null and AttEndMi is not null

update #tblHasTA_insert set STDWorkingTime_SS = StdWorkingTimeMi
-- cập nhật lại STDWorkingTime_SS
 update #tblHasTA_insert set STDWorkingTime_SS = ss.Std_Hour_PerDays * 60
 from #tblHasTA_insert ta
 inner join tblShiftSetting ss on ta.ShiftCode = ss.ShiftCode and datepart(DW,ta.Attdate) = ss.WeekDays
 where ta.STDWorkingTime_SS <> ss.Std_Hour_PerDays * 60


 if @MATERNITY_LATE_EARLY_OPTION = 0
begin
update att set WorkingTimeMi = att.WorkingTimeMi + t.MATERNITY_MUNITE from #tblHasTA_insert att inner join
(
	select t.EmployeeID, t.AttDate,tmp.MATERNITY_MUNITE, max(t.Period) Period from #tblHasTA_insert t inner join (
	select d.EmployeeID, d.AttDate, Min(WorkingTimeMi) WorkingTimeMi,case when max(StdWorkingTimeMi) - sum(WorkingTimeMi) > @MATERNITY_MUNITE then @MATERNITY_MUNITE else max(StdWorkingTimeMi) - sum(WorkingTimeMi) end MATERNITY_MUNITE
		from #tblHasTA_insert d
		where
		--exists (select 1 from #tblHasTA_insert t where d.employeeID = t.EmployeeID and d.AttDate = t.AttDate group by t.EmployeeID, t.AttDate having sum (t.WorkingTimeMi) >= @MATERNITY_ADD_ATLEAST) and
		exists (select 1 from  #tblPendingImportAttend p where d.EmployeeID = p.EmployeeID and d.Attdate = p.[Date] and p.EmployeeStatusID in (10,11))
		group by d.employeeId, d.AttDate
		having sum (d.WorkingTimeMi) >= @MATERNITY_ADD_ATLEAST
		) tmp on t.EmployeeID = tmp.EmployeeId and t.AttDate = tmp.AttDate and t.WorkingTimeMi = tmp.WorkingTimeMi
		group by t.EmployeeID, t.AttDate,tmp.MATERNITY_MUNITE
) t on att.EmployeeId = t.EmployeeId and att.AttDate = t.AttDate and att.Period = t.Period

end


-- chinh lai STD_WT khi nguoi dung nhap trong ban thiet lap ca -- ca tu do thi ko tinh ty le nay

update ta set WorkingTimeMi = ta.WorkingTimeMi*ta.STDWorkingTime_SS/ta.StdWorkingTimeMi, StdWorkingTimeMi = ta.STDWorkingTime_SS
from #tblHasTA_insert ta
where (ta.STDWorkingTime_SS < 841 and ta.StdWorkingTimeMi < 841) and ta.STDWorkingTime_SS <> ta.StdWorkingTimeMi


-- truong hop di lam nua ngay ma vao som 5 hoăc 10 phut thi van tinh cong nua ngay
--UPDATE #tblHasTA_insert set WorkingTimeMi = 240 WHERE WorkingTimeMi BETWEEN 241 AND 249


if(OBJECT_ID('sp_ShiftDetector_ProcessWorkingTime' )is null)
begin
exec('CREATE PROCEDURE sp_ShiftDetector_ProcessWorkingTime
(
  @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUpdate = 0
-- Goi thu thu thuc customize import de ap dung cho tung khach hang rieng biet
exec sp_ShiftDetector_ProcessWorkingTime @StopUpdate output ,@LoginID,@FromDate,@ToDate

--System automatically insert leave

/*
--select *
update lv set LvAmount = LvAmount - case when tmp.WorkingTimeMi > tmp.StdWorkingTimeMi then tmp.StdWorkingTimeMi else tmp.WorkingTimeMi end/60.0
,LeaveStatus = 2
from tblLvHistory lv inner join (
select EmployeeID,AttDate,sum(WorkingTimeMi) WorkingTimeMi,max(StdWorkingTimeMi) StdWorkingTimeMi
 from #tblHasTA_insert ta
 where exists (select 1 from tblLvHistory lv where ta.employeeID = lv.EmployeeID and ta.AttDate = lv.LeaveDate and lv.Reason = N'System automatically insert leave')
 and ta.WorkingTimeMi > 0
  group by EmployeeID, AttDate
  ) tmp on lv.EmployeeID = tmp.EmployeeID and lv.LeaveDate = tmp.AttDate
  where lv.Reason = N'System automatically insert leave'
  */

if not exists(select 1 from tblParameter where Code = 'WORKINGTIME_DONOT_CARE_LEAVEAMOUNT' AND VALUE = '1')
BEGIN
 UPDATE #tblHasTA_insert SET WorkingTimeMi = StdWorkingTimeMi - ISNULL(SumLvAmount,0)
 from #tblHasTA_insert d inner join #tblPendingImportAttend p on d.EmployeeID = p.EmployeeID and d.Attdate = p.[Date]
 inner join (select EmployeeID, LeaveDate, SUM(LvAmount)*60 as SumLvAmount from #tblLvHistory lv where lv.LeaveCategory = 1 and isnull(lv.Reason,'') <> N'System automatically insert leave' group by EmployeeID, LeaveDate) lv
  on d.EmployeeID = lv.EmployeeID and d.Attdate = lv.LeaveDate
 where AttStartMi is not null and AttEndMi is not null and ISNULL(WorkingTimeMi,0) + ISNULL(lv.SumLvAmount,0) > StdWorkingTimeMi
end



--sửa chữa chỗ này tí thêm cái tỉ lệ vào cho nó máu
if not exists(select 1 from tblParameter where Code ='DONOT_USE_WORKINGTIME_RATE' AND VALUE ='1')
 UPDATE ta1 set WorkingTimeMi = case when (ta1.STDWorkingTimeMi - isnull(lv.lvAmount *60,0)) <=0 then 0 when
  cast(case when ta1.WorkingTimeMi > (ta1.STDWorkingTimeMi - isnull(lv.lvAmount *60,0)) then (ta1.STDWorkingTimeMi - isnull(lv.lvAmount *60,0)) else ta1.WorkingTimeMi end as float)/(ta1.STDWorkingTimeMi - isnull(lv.lvAmount *60,0)) *(isnull(ta2.Std_Hour_PerDays,8)*60 - isnull(lv.lvAmount *60,0)) >= (isnull(ta2.Std_Hour_PerDays,8)*60 - isnull(lv.lvAmount *60,0)) then (isnull(ta2.Std_Hour_PerDays,8)*60 - isnull(lv.lvAmount *60,0))
  else cast(case when WorkingTimeMi > (ta1.STDWorkingTimeMi - isnull(lv.lvAmount *60,0)) then (ta1.STDWorkingTimeMi - isnull(lv.lvAmount *60,0)) else ta1.WorkingTimeMi end as float)/(ta1.STDWorkingTimeMi - isnull(lv.lvAmount *60,0)) *(isnull(ta2.Std_Hour_PerDays,8)*60 - isnull(lv.lvAmount *60,0))
  end
 from #tblHasTA_insert ta1
 inner join tblShiftSetting ta2 on ta1.ShiftID = ta2.ShiftID
 inner join tblLvhistory lv on ta1.employeeId= lv.EmployeeId and ta1.Attdate = lv.LeaveDate
 where
 ta1.Workingtimemi >0
 and lv.LeaveCode in (select LeaveCode from tblLeaveType where LeaveCategory= 1)

 -- x? lý tru?ng h?p ngày phía tru?c ho?c phía sau dã duy?t gi? vào ra, thì ngày hi?n t?i không du?c sát v?i gi? vao ra cua nhung ngay
 --select ta.AttStart, ta1.AttEnd, ta.Attdate ,DATEDIFF(mi,ta1.AttEnd,ta.AttStart)
 update ta set AttStart = null,WorkingTime = null,WorkingTimeMi = null
 from #tblHasta_insert ta
 inner join #tblHasta_insert ta1 on ta.EmployeeID = ta1.EmployeeID and ta.Attdate = ta1.Attdate + 1
 where ta.TAStatus = 0 and ta1.TAStatus in(2,3)
 and DATEDIFF(mi,ta1.AttEnd,ta.AttStart) < 61 -- gi? vào ph?i l?n 60 phút so v?i gi? ra hôm tru?c
 --select ta.AttEnd, ta1.AttStart, ta.Attdate ,DATEDIFF(mi,ta1.AttStart,ta.AttEnd)


 update ta set AttEnd = null,WorkingTime = null,WorkingTimeMi = null
 from #tblHasta_insert ta inner join #tblHasta_insert ta1 on ta.EmployeeID = ta1.EmployeeID and ta.Attdate = ta1.Attdate - 1
 where ta.TAStatus = 0 and ta1.TAStatus in(1,3)

 and DATEDIFF(mi,ta.AttEnd,ta1.AttStart) < 61 -- gio ra phai nho hon 60 phút so voi gio vào hôm sau


  ALTER TABLE #tblShiftSetting ADD isFreeShift bit
  --wtc:tao them 2 column de tinh lai workingtime
--ALTER TABLE #tblHasta_insert ADD STD_WD_Custom money,LeaveAmount money

if(OBJECT_ID('sp_ShiftDetector_UpdateHasTA' )is null)
begin
exec('create proc sp_ShiftDetector_UpdateHasTA
(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
)
as
begin
 SET NOCOUNT ON;
 --WILLTECH : Tinh toan lai gio cong theo quy tac cua client
end')
end
set @StopUpdate = 0
-- Goi thu thu thuc customize import de ap dung cho tung khach hang rieng biet
exec sp_ShiftDetector_UpdateHasTA @StopUpdate output ,@LoginID,@FromDate,@ToDate
if @StopUpdate = 0
begin
--xu ly goi lam viec cho ca tu do

 UPDATE #tblShiftSetting  SET isFreeShift = 1
 WHERE WorkEndMi - WorkStartMi > 810
  UPDATE #tblShiftSetting SET STDWorkingTime_SS = (case when  ISNUMERIC(ss.Std_Hour_PerDays) = 1  then ss.Std_Hour_PerDays else @WORK_HOURS end)* 60
FROM #tblShiftSetting ts
 INNER JOIN tblShiftSetting ss on ss.ShiftID = ts.ShiftID AND ISNULL(ts.isFreeShift,0) = 1


    UPDATE #tblHasTA_insert SET WorkingTime = WorkingTimeMi /60.0

 UPDATE #tblHasTA_insert SET IsNightShift = s.IsNightShift from #tblHasTA_insert ta inner join #tblShiftSetting s on ta.ShiftCode = s.ShiftCode


 END


 -- bo nhung du lieu ko hop le
  delete i1
 from tblHasTA i1 /*WITH(IGNORE_TRIGGERS)*/
 where exists(select 1 from #tblPendingImportAttend te where i1.EmployeeID = te.EmployeeID and i1.AttDate = te.Date)
 and isnull(i1.TAStatus,0) <> 3
 and exists(select 1 from #tblHasTA_insert te where i1.EmployeeID = te.EmployeeID and i1.AttDate = te.AttDate)
 and not exists(select 1 from #tblHasTA_insert te where i1.EmployeeID = te.EmployeeID and i1.AttDate = te.AttDate and i1.Period = te.Period)
 and not exists(select 1 from #tblWSchedule ws where i1.EmployeeID = ws.EmployeeID and i1.AttDate = ws.ScheduleDate and ws.DateStatus = 3)

 DELETE i1
 from tblHasTA i1 /*WITH(IGNORE_TRIGGERS)*/ inner join tblHasTA i2 on i1.employeeID = i2.EmployeeID and i1.AttDate = i2.AttDate - 1
 where isnull(i1.TAStatus,0) <> 3 and isnull(i1.AttEnd,i1.AttStart) >= ISNULL(i2.AttStart,I2.AttEnd)
 and exists(select 1 from #tblPendingImportAttend te where i1.EmployeeID = te.EmployeeID and i1.AttDate = te.Date)
 and not exists(select 1 from #tblWSchedule ws where i1.EmployeeID = ws.EmployeeID and i1.AttDate = ws.ScheduleDate and ws.DateStatus = 3)

DELETE I2
from tblHasTA i1 inner join tblHasTA i2 /*WITH(IGNORE_TRIGGERS)*/ on i1.employeeID = i2.EmployeeID and i1.AttDate = i2.AttDate
 where isnull(i1.TAStatus,0) <> 3 and i1.Period = i2.Period -1 and isnull(i1.AttEnd,i1.AttStart) >= ISNULL(i2.AttStart,I2.AttEnd)
 and exists(select 1 from #tblPendingImportAttend te where i1.EmployeeID = te.EmployeeID and i1.AttDate = te.Date)
 and not exists(select 1 from #tblWSchedule ws where i1.EmployeeID = ws.EmployeeID and i1.AttDate = ws.ScheduleDate and ws.DateStatus = 3)

 insert into tblHasTA /*WITH(IGNORE_TRIGGERS)*/ (EmployeeID, AttDate, Period, AttStart,AttMiddle, AttEnd, Approve,WorkingTime)
 select distinct a.EmployeeID, a.AttDate, a.Period,a.AttStart,a.AttMiddle,a.AttEnd,0, a.WorkingTime
 from #tblHasTA_insert a
 where not exists(select 1 from tblHasTA b where a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = b.Period)


 UPDATE tblHasTA /*WITH(IGNORE_TRIGGERS)*/ SET AttStart = b.AttStart, AttEnd = b.AttEnd,AttMiddle = b.AttMiddle
 from tblHasTA a
 inner join #tblHasTA_insert b on a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = b.Period
 where isnull(a.TAStatus,0) <> 3
 --and (a.AttStart is null or a.AttEnd is null or a.AttStart <> b.AttStart or a.AttEnd <> b.AttEnd)
 and not exists(select 1 from #tblWSchedule ws where a.EmployeeID = ws.EmployeeID and a.AttDate = ws.ScheduleDate and ws.DateStatus = 3)

 UPDATE tblHasTA /*WITH(IGNORE_TRIGGERS)*/ SET AttStart = b.AttStart
 from tblHasTA a
 inner join #tblHasTA b on a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = b.Period
 where b.TAStatus = 1 and b.AttStart is not null


 UPDATE tblHasTA /*WITH(IGNORE_TRIGGERS)*/ SET AttEnd = b.AttEnd
 from tblHasTA a
 inner join #tblHasTA b on a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = b.Period
 where b.TAStatus = 2 and b.AttEnd is not null


 UPDATE tblHasTA SET WorkingTime = --case when round(b.WorkingTime,3) > 0 then round(b.WorkingTime,3) else NULL end
 CASE WHEN ROUND(((b.WorkingTime+0.5)/0.5)-0.5,0)*0.5-0.5 > 0 THEN ROUND(((b.WorkingTime+0.5)/0.5)-0.5,0)*0.5-0.5  ELSE NULL END --wtc:làm tròn xuống 0.5
 from tblHasTA a inner join #tblHasTA_insert b
 on a.EmployeeID = b.EmployeeID and a.AttDate = b.AttDate and a.Period = b.Period
 where (isnull(a.WorkingTimeApproved,0) = 0 or a.WorkingTime is null)
 -- and (isnull(a.WorkingTime,-1) <> round(b.WorkingTime,3))
 AND a.AttDate BETWEEN DATEADD(dd,1,@FromDate) AND @ToDate



if(OBJECT_ID('sp_ShiftDetector_FinishUpdateHasTA' )is null)
begin
exec('CREATE PROCEDURE dbo.sp_ShiftDetector_FinishUpdateHasTA
(
 @StopUpdate bit output
 ,@LoginID int
 ,@FromDate datetime
 ,@ToDate datetime
 ,@EmployeeID varchar(20) = ''-1''
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUpdate = 0
-- Goi thu thu thuc customize import de ap dung cho tung khach hang rieng biet
exec sp_ShiftDetector_FinishUpdateHasTA @StopUpdate output ,@LoginID,@FromDate,@ToDate, @EmployeeID = @EmployeeID

FinishedShiftDetector:
/*
update tblWSchedule set ShiftID = 0 from tblWSchedule ws
where isnull(Approved,0) = 0 and ws.ScheduleDate between @FromDate and @ToDate
 and EmployeeID not in (select EmployeeID from tblShiftGroupByEmployee)
 and ws.HolidayStatus > 0
 and not exists(select 1 from tblAtt_Lock al where ws.EmployeeID =al.EmployeeID and ws.ScheduleDate = al.[Date])
 and not exists(select 1 from tblHasTA ta where ws.EmployeeID = ta.EmployeeId and ws.ScheduleDate = ta.AttDate and (ta.AttStart is not null or ta.AttEnd is not null or isnull(WorkingTime ,0) =8))
 and exists (select 1 from #tblEmployeeList e where ws.EmployeeID = e.EmployeeID)
 and EmployeeID not in (select EmployeeID from #tblShiftGroupCode sgc group by EmployeeID having count(1) = 1)
 */

delete tblPendingImportAttend from tblPendingImportAttend d
WHERE ISNULL(LoginID,-999) = ISNULL(@LoginID,-999) and
EXISTS (select distinct 1 from #tblEmployeeList te WHERE d.EmployeeID = te.EmployeeID)
and [Date] between @fromdate and @todate


	
--delete d from tblPendingImportAttend d
--where exists(select 1 from #tblPendingImportAttend att where d.employeeID = att.EmployeeID and d.Date = att.Date)
--or exists(select 1 from #tblHasTA_insert att where d.employeeID = att.EmployeeID and d.Date = att.attdate)
--update tblParameter set Value = '0' where Code = 'StopRuning_NoneStopProc'

--exec ('Enable trigger all on tblWSchedule')
--exec ('Enable trigger all on tblHasTA')
--exec ('Enable trigger all on tblLvhistory')

--EXEC sp_InsertPendingProcessAttendanceData 3,'20200601','20200630','-1',1,0
print 'eof'
END
GO