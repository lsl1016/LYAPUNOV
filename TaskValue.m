classdef TaskValue < handle
    % TaskValue 任务价值结构体（用于01背包算法）
    
    properties
        TaskType  % 任务类型
        Value     % 价值
        Weight    % 权重
    end
    
    methods
        function obj = TaskValue(taskType, value, weight)
            % 构造函数
            obj.TaskType = taskType;
            obj.Value = value;
            obj.Weight = weight;
        end
    end
end
