classdef LyapunovManager < handle
    % LyapunovManager 李雅普诺夫队列管理器
    
    properties
        Queues % 每个任务类型对应一个队列 (containers.Map)
    end
    
    methods
        function obj = LyapunovManager()
            % 构造函数
            obj.Queues = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            
            % 为每个任务类型初始化队列
            K = constants.K();
            for i = 1:K
                obj.Queues(i) = LyapunovQueue(i);
            end
        end
        
        function updateQueue(obj, taskType, bk, droppedCount, newArrivals)
            % 更新李雅普诺夫队列
            % Qk(t+1) = max{Qk(t) - bk(t) - 丢弃的任务数量, 0} + ak(t)
            queue = obj.Queues(taskType);
            
            % 保存前一时隙的队列长度
            queue.PreviousLength = queue.QueueLength;
            
            newLength = max(queue.QueueLength - bk - droppedCount, 0) + newArrivals;

            queue.QueueLength = newLength;
        end
        
        function queueLength = getQueueLength(obj, taskType)
            % 获取指定任务类型的队列长度
            if obj.Queues.isKey(taskType)
                queue = obj.Queues(taskType);
                queueLength = queue.QueueLength;
            else
                queueLength = 0;
            end
        end
        
        function lengths = getAllQueueLengths(obj)
            % 获取所有队列长度
            lengths = containers.Map('KeyType', 'int32', 'ValueType', 'double');
            keys = cell2mat(obj.Queues.keys);
            for i = 1:length(keys)
                taskType = keys(i);
                queue = obj.Queues(taskType);
                lengths(taskType) = queue.QueueLength;
            end
        end
        
        function drift = calculateLyapunovDrift(obj)
            % 计算李雅普诺夫漂移
            % L(t) = 1/2 * sum(Qk(t)^2)
            drift = 0;
            keys = cell2mat(obj.Queues.keys);
            for i = 1:length(keys)
                queue = obj.Queues(keys(i));
                drift = drift + 0.5 * (queue.QueueLength^2);
            end
        end
    end
end
