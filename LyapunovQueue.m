classdef LyapunovQueue < handle
    % LyapunovQueue 李雅普诺夫队列
    
    properties
        TaskType         % 任务类型
        QueueLength      % 队列长度
        PreviousLength   % 前一时隙的队列长度
    end
    
    methods
        function obj = LyapunovQueue(taskType)
            % 构造函数
            obj.TaskType = taskType;
            obj.QueueLength = 0;
            obj.PreviousLength = 0;
        end
    end
end
