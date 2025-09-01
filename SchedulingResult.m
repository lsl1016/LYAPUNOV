classdef SchedulingResult < handle
    % SchedulingResult 调度结果
    %[任务类型, 虚拟节点ID, 匹配代价, 因调度而完成的积压任务数量]
    properties
        TaskType       % 任务类型
        NodeID         % 分配的虚拟节点ID
        MatchCost      % 匹配代价
        CompletedTasks % 改为时间槽增益数
    end
    
    methods
        function obj = SchedulingResult(taskType, nodeID, matchCost, completedTasks)
            % 构造函数
            obj.TaskType = taskType;
            obj.NodeID = nodeID;
            obj.MatchCost = matchCost;
            obj.CompletedTasks = completedTasks;
        end
    end
end
