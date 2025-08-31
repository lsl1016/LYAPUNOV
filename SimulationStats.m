classdef SimulationStats < handle
    % SimulationStats 仿真统计信息
    
    properties
        TotalTasksGenerated % 总生成任务数
        TotalTasksCompleted % 总完成任务数
        TotalTasksDropped   % 总丢弃任务数

        CacheHitCount       % 缓存命中次数
        TotalCacheAccess    % 总缓存访问次数
        
        AverageLyapunovQueueLength % 李雅普诺夫队列平均长度
        AverageBacklogQueueLength  % 挤压队列平均长度

        TaskTypeStats       % 各任务类型统计 (containers.Map)
    end
    
    methods
        function obj = SimulationStats()
            % 构造函数
            obj.TotalTasksGenerated = 0;
            obj.TotalTasksCompleted = 0;
            obj.TotalTasksDropped = 0;
            obj.CacheHitCount = 0;
            obj.TotalCacheAccess = 0;
            obj.AverageLyapunovQueueLength = 0;
            obj.AverageBacklogQueueLength = 0;
            obj.TaskTypeStats = containers.Map('KeyType', 'int32', 'ValueType', 'any');
        end
    end
end
