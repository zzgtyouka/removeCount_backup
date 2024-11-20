-- rewrite by hewz at 2024-11-20
-- 定义 CTE
WITH cte AS (
    -- 提取基本测点信息，包括工单、设备、测点值、记录时间等
    SELECT 
        sm.MO_CODE, 
        eopl.EQUIPMENT_CODE,  -- 设备信息
        eopl.RESULT_VALUE,    -- 测点值
        eopl.DATETIME_SERVER, -- 测点记录时间
        eo.START_TIME,        -- 设备启动时间
        sm.DATETIME_START,    -- 工单开工时间
        sm.DATETIME_OFFLINE   -- 工单下线时间
    FROM eam_online_point_log eopl 
    JOIN sfc_schedule_equipment sse 
        ON eopl.EQUIPMENT_CODE = sse.EQUIPMENT_CODE 
        AND eopl.STATE = 'A'  -- 测点状态为有效
        AND eopl.POINT_CODE = 'removeCount' -- 过滤指定的测点代码
    JOIN sfc_schedule ss 
        ON sse.SCHEDULE_ID = ss.ID 
        AND ss.STATE = 'A'    -- 排程状态为有效
    JOIN sfc_mo sm 
        ON ss.MO_CODE = sm.MO_CODE
    LEFT JOIN eam_oee eo 
        ON sm.MO_CODE = eo.MO_CODE 
        AND eo.STATE = 'A'    -- 设备状态为有效
    WHERE DATE_FORMAT(sm.SCHE_DATE, '%Y-%m-%d') BETWEEN 
          DATE_SUB(DATE_FORMAT(NOW(), '%Y-%m-%d'), INTERVAL 1 DAY) -- 当前日期前一天
          AND DATE_ADD(DATE_FORMAT(NOW(), '%Y-%m-%d'), INTERVAL 1 DAY) -- 当前日期后一天
      AND sm.SECTION IN ('FILL_SECTION,PACK_SECTION', 'FILL_SECTION', ',PACK_SECTION') -- 限制工单所属区域
      AND ss.STATUS = 'RUNNING' -- 排程状态为运行中
),
cte_device_diff_start AS (
    -- 计算每个设备在开工前的剔除差值
    SELECT 
        MO_CODE, 
        EQUIPMENT_CODE, 
        (MAX(CONVERT(RESULT_VALUE, DECIMAL(10, 0))) - MIN(CONVERT(RESULT_VALUE, DECIMAL(10, 0)))) AS DEVICE_DIFF -- 差值计算
    FROM cte
    WHERE DATETIME_SERVER >= START_TIME AND DATETIME_SERVER < DATETIME_START -- 测点记录时间在启动后开工前
    GROUP BY MO_CODE, EQUIPMENT_CODE
),
cte_device_diff_end AS (
    -- 计算每个设备在开工后的剔除差值
    SELECT 
        MO_CODE, 
        EQUIPMENT_CODE, 
        (MAX(CONVERT(RESULT_VALUE, DECIMAL(10, 0))) - MIN(CONVERT(RESULT_VALUE, DECIMAL(10, 0)))) AS DEVICE_DIFF -- 差值计算
    FROM cte
    WHERE DATETIME_SERVER >= DATETIME_START 
        AND DATETIME_SERVER <= CASE WHEN DATETIME_OFFLINE IS NULL THEN NOW() ELSE DATETIME_OFFLINE END -- 测点记录时间在开工到下线之间
    GROUP BY MO_CODE, EQUIPMENT_CODE
),
cte_final AS (
    -- 汇总剔除差值并标注剔除类型
    SELECT 
        MO_CODE, 
        SUM(DEVICE_DIFF) + 1 AS '剔除差', -- 累加设备差值并加 1
        '开工前剔除' AS '类型'
    FROM cte_device_diff_start
    GROUP BY MO_CODE
    UNION ALL
    SELECT 
        MO_CODE, 
        SUM(DEVICE_DIFF) + 1 AS '剔除差', -- 累加设备差值并加 1
        '开工后剔除' AS '类型'
    FROM cte_device_diff_end
    GROUP BY MO_CODE
)
-- 主查询
SELECT 
    sm.MO_CODE '工单', -- 工单号
    ss.WORKCENTER_CODE '产线', -- 产线编码
    IFNULL(temp1.剔除差, 0) '剔除数', -- 剔除数量（若无剔除记录则为 0）
    IFNULL(temp1.类型, '') 类型 -- 剔除类型（开工前或开工后）
FROM sfc_mo sm 
JOIN sfc_schedule ss 
    ON ss.MO_CODE = sm.MO_CODE 
    AND ss.STATE = 'A' -- 排程状态为有效
LEFT JOIN cte_final temp1 
    ON ss.MO_CODE = temp1.MO_CODE -- 关联剔除差数据
WHERE DATE_FORMAT(sm.SCHE_DATE, '%Y-%m-%d') BETWEEN 
      DATE_SUB(DATE_FORMAT(NOW(), '%Y-%m-%d'), INTERVAL 1 DAY) -- 当前日期前一天
      AND DATE_ADD(DATE_FORMAT(NOW(), '%Y-%m-%d'), INTERVAL 1 DAY) -- 当前日期后一天
  AND sm.SECTION IN ('FILL_SECTION,PACK_SECTION', 'FILL_SECTION', ',PACK_SECTION') -- 限制工单所属区域
  AND ss.STATUS = 'RUNNING' -- 排程状态为运行中
  AND temp1.剔除差 > 0 -- 仅查询有剔除差的记录
ORDER BY ss.WORKCENTER_CODE ASC -- 按产线升序排序
