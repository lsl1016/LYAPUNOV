classdef LyapunovQueue < handle
    % LyapunovQueue 李雅普诺夫队列
    
    properties
        TaskType       % 任务类型
        QueueLength    % 队列长度 Qk(t)
        PreviousLength % 上一时隙的队列长度 Qk(t-1)
    end
    
    methods
        function obj = LyapunovQueue(taskType)
            % 构造函数
            obj.TaskType = taskType;
            obj.QueueLength = 0; % Qk(0) = 0
            obj.PreviousLength = 0;
        end
    end
end
