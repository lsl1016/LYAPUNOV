classdef AccessRecord < handle
    % AccessRecord 访问记录
    
    properties
        TaskType       % 任务类型
        LastAccessTime % 最后访问时隙
        AccessTimes    % 最近访问时隙列表（用于LRU）
    end
    
    methods
        function obj = AccessRecord(taskType, lastAccessTime)
            % 构造函数
            obj.TaskType = taskType;
            obj.LastAccessTime = lastAccessTime;
            obj.AccessTimes = [];
        end
    end
end
