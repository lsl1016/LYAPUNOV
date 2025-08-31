classdef TaskValue2 < handle
    % TaskValue2 任务价值结构体（用于调度）
    
    properties
        TaskType      % 任务类型
        Priority      % 优先级
        AccessFreq    % 访问频率
        Value         % 价值 (访问频率 * 优先级)
        BacklogCount  % 积压数量
        LyapunovQueue % 李雅普诺夫队列长度
    end
    
    methods
        function obj = TaskValue2(taskType, priority, accessFreq, backlogCount, lyapunovQueue)
            % 构造函数
            obj.TaskType = taskType;
            obj.Priority = priority;
            obj.AccessFreq = accessFreq;
            obj.Value = accessFreq * priority;
            obj.BacklogCount = backlogCount;
            obj.LyapunovQueue = lyapunovQueue;
        end
    end
end
