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
        
        % TODO：需要修正下面这个函数，以及相关接口参数：Qk(t+1) = max{Qk(t) - bk(t) - 当前类型丢弃的任务数量*wkr, 0} + ak(t)*wkr
        function updateQueue(obj, taskType, bk, droppedCount, ak, taskManager)
            % 更新队列
            % bk: 本时隙完成的任务数
            % droppedCount: 本时隙丢弃的任务数
            % ak: 本时隙新到达的任务数
            
            if obj.Queues.isKey(taskType) && taskManager.TaskTypes.isKey(taskType)
                q = obj.Queues(taskType);
                tt = taskManager.TaskTypes(taskType);
                
                % 使用一个代表性的mkr（平均值）来计算wkr
                avg_mkr = (constants.MIN_MKR + constants.MAX_MKR) / 2;
                wkr = TaskManager.calculateWKR(avg_mkr, tt.Ck);

                % 根据TODO修正公式
                % Qk(t+1) = max{Qk(t) - bk(t) - droppedCount*wkr, 0} + ak*wkr
                newLength = max(q.QueueLength - bk - droppedCount * wkr, 0) + ak * wkr;
                
                q.QueueLength = newLength;
            end
        end
        
        function length = getQueueLength(obj, taskType)
            % 获取指定任务类型的队列长度
            if obj.Queues.isKey(taskType)
                q = obj.Queues(taskType);
                length = q.QueueLength;
            else
                length = 0;
            end
        end
        
        function lengths = getAllQueueLengths(obj)
            % 获取所有队列的长度
            K = constants.K();
            lengths = zeros(1, K);
            keys = cell2mat(obj.Queues.keys);
            for i = 1:length(keys)
                q = obj.Queues(keys(i));
                lengths(keys(i)) = q.QueueLength;
            end
        end

        function drift = calculateDrift(obj)
            % 计算李雅普诺夫漂移
            drift = 0;
            keys = cell2mat(obj.Queues.keys);
            for i = 1:length(keys)
                q = obj.Queues(keys(i));
                drift = drift + 0.5 * (q.QueueLength^2);
            end
        end

    end
end
