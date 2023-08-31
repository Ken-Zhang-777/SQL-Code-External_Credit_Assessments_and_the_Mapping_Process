CREATE TABLE `Bond_Jan_2020` (
    `ID_CUSIP` TEXT,
    `ID_ISIN` TEXT,
    `Issuer` TEXT,
    `PARENT_COMP_NAME` TEXT,
    `CRNCY` TEXT,
    `Maturity` TEXT,
    `PX_LAST` TEXT,
    `MARKET_SECTOR_DES` TEXT,
    `ISSUER_INDUSTRY` TEXT,
    `INDUSTRY_SECTOR` TEXT,
    `Industry_Group` TEXT,
    `Industry_Subgroup` TEXT,
    `COLLAT_TYP` TEXT,
    `RTG_MOODY` TEXT,
    `RTG_SP` TEXT,
    `RTG_DBRS` TEXT,
    `RTG_FITCH` TEXT,
    `RTG_MDY_ISSUER` TEXT,
    `RTG_SP_LT_LC_ISSUER_CREDIT` TEXT,
    `RTG_DBRS_LT_ISSUER_RATING` TEXT,
    `RTG_FITCH_SEN_UNSECURED` TEXT,
    `Callable` TEXT,
    `Is_Subordinated` TEXT,
    `PRVT_PLACE` TEXT,
    `SERIES` TEXT,
    `GUARANTOR_TYPE` TEXT,
    `CNTRY_OF_INCORPORATION` TEXT,
    `CNTRY_OF_DOMICILE` TEXT,
    `Security_Type` TEXT
);


CREATE TABLE `IG_to_Rating` (
    `IG` TEXT,
    `RTG_FINAL` TEXT
);


CREATE TABLE `LT_Rating_to_IG` (
    `RTG_MOODY` TEXT,
    `RTG_SP` TEXT,
    `RTG_DBRS` TEXT,
    `RTG_FITCH` TEXT,
    `IG` TEXT
);


--step 1: add 4 column of grade to Bond_Jan_2020, corresponding to rating from each different agency 
create table bond_grade as
select *,
        b.IG as moody_ig,
        c.IG as sp_ig,
        d.IG as dbrs_ig,
        e.IG as fitch_ig
from Bond_Jan_2020 a
left join LT_Rating_to_IG b on a.RTG_MOODY=b.RTG_MOODY
left join LT_Rating_to_IG c on a.RTG_SP=c.RTG_SP
left join LT_Rating_to_IG d on a.RTG_DBRS=d.RTG_DBRS
left join LT_Rating_to_IG e on a.RTG_FITCH=e.RTG_FITCH
;


--step 2: create a new table， where Each ID corresponds to an external rating 
create table id_external as
select ID_CUSIP, moody_ig as grade
from bond_grade
where grade is not Null

union 

select ID_CUSIP, sp_ig as grade
from bond_grade
where grade is not Null

union 

select ID_CUSIP, dbrs_ig as grade
from bond_grade
where grade is not Null

union 

select ID_CUSIP, fitch_ig as grade
from bond_grade
where grade is not Null

order by ID_CUSIP, grade
;

--step 3: count the number of external 
create table id_external_num as 
select *,
        (
        select count(*)
        from id_external b
        where a.ID_CUSIP=b.ID_CUSIP
        ) as num_ex
from id_external a
;

--step 4: according to the number of each ID_CUSIP and the rule for getting internal grade, return the final internal grade for each ID_CUSIP.
create table internal_grade as
select
        distinct a.ID_CUSIP,
        (
        select b.grade
        from id_external_num b 
        where a.num_ex>1
        limit 1,1
        ) as final_grade
from id_external_num a
where final_grade is not Null
union 

select ID_CUSIP, grade as final_grade
from id_external_num
where num_ex=1
;

--step 5: get the corresponding internal rate by their internal grade
create table internal_rate as
select a.*,
        b.RTG_FINAL
from internal_grade a
left join   IG_to_Rating b on a.final_grade=b.IG
;

--step 6: join this internal_rate to Bond_Jan_2020
create table bond_rudiment as
select a.*,
        coalesce(b.RTG_FINAL, 'N/A') as rudiment
from Bond_Jan_2020 a
left join  internal_rate b on a.ID_CUSIP=b.ID_CUSIP
;

--step 7: consider the goverment bond......
create table  case_2_final_result as
select ID_CUSIP,
        case
            when CNTRY_OF_INCORPORATION in ('US', 'CA')
                and INDUSTRY_SECTOR = 'Government'
                and rudiment='N/A' then 'AAA'
            when CNTRY_OF_INCORPORATION not in ('US', 'CA')
                and INDUSTRY_SECTOR = 'Government'
                and rudiment='N/A' then 'A'
            else rudiment
        end as internal_rate
from bond_rudiment
;
