-- 已看 by hewz on 20240611
select sm.MO_CODE '工单',ss.WORKCENTER_CODE '产线', ifnull(temp1.剔除差,0) '剔除数' ,ifnull(temp1.类型,'') 类型
from sfc_mo sm 
join sfc_schedule ss on ss.MO_CODE = sm.MO_CODE and ss.STATE ='A'
left join (WITH cte AS (
    SELECT 
        sm.MO_CODE, 
        eopl.RESULT_VALUE, 
        eopl.DATETIME_SERVER, 
        eo.START_TIME, 
        sm.DATETIME_START, 
        sm.DATETIME_OFFLINE
    FROM eam_online_point_log eopl 
    JOIN sfc_schedule_equipment sse ON eopl.EQUIPMENT_CODE = sse.EQUIPMENT_CODE AND eopl.STATE = 'A' AND eopl.POINT_CODE = 'removeCount'
    JOIN sfc_schedule ss ON sse.SCHEDULE_ID = ss.ID AND ss.STATE = 'A'
    JOIN sfc_mo sm ON ss.MO_CODE = sm.MO_CODE
    LEFT JOIN eam_oee eo ON sm.MO_CODE = eo.MO_CODE AND eo.STATE = 'A'
    where DATE_FORMAT (sm.SCHE_DATE,'%Y-%m-%d') between DATE_SUB(DATE_FORMAT(now() ,'%Y-%m-%d'), INTERVAL 1 DAY) 
	and DATE_ADD(DATE_FORMAT(now() ,'%Y-%m-%d'), INTERVAL 1 DAY) 
	and  sm.SECTION in  ('FILL_SECTION,PACK_SECTION','FILL_SECTION',',PACK_SECTION') 
	and ss.STATUS = ('RUNNING')
)
SELECT 
       MO_CODE, 
    ((MAX(CONVERT(RESULT_VALUE, DECIMAL(10, 0))) - MIN(CONVERT(RESULT_VALUE, DECIMAL(10, 0))))+1)    '剔除差', 
    '开工前剔除' AS '类型'
FROM cte
WHERE DATETIME_SERVER >= START_TIME AND DATETIME_SERVER < DATETIME_START
GROUP BY MO_CODE
UNION ALL
SELECT 
      MO_CODE, 
    ((MAX(CONVERT(RESULT_VALUE, DECIMAL(10, 0))) - MIN(CONVERT(RESULT_VALUE, DECIMAL(10, 0))))+1)    '剔除差', 
    '开工后剔除' AS '类型'
FROM cte
WHERE DATETIME_SERVER >= DATETIME_START AND DATETIME_SERVER <= case when DATETIME_OFFLINE is null then now() end 
GROUP BY MO_CODE  ) temp1 on ss.MO_CODE =temp1.MO_CODE 
where  DATE_FORMAT (sm.SCHE_DATE,'%Y-%m-%d') between DATE_SUB(DATE_FORMAT(now() ,'%Y-%m-%d'), INTERVAL 1 DAY) 
	and DATE_ADD(DATE_FORMAT(now() ,'%Y-%m-%d'), INTERVAL 1 DAY) 
and  sm.SECTION in  ('FILL_SECTION,PACK_SECTION','FILL_SECTION',',PACK_SECTION') 
and ss.STATUS = ('RUNNING')
and temp1.剔除差 > 0
order by ss.WORKCENTER_CODE asc 
