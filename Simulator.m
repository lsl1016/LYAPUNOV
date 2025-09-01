classdef Simulator < handle
    % Simulator 仿真器
    
    properties
        MEC             % MEC实例
        TaskManager     % 任务管理器
        LyapunovManager % 李雅普诺夫队列管理器
        Scheduler       % 调度器
        CurrentTimeSlot % 当前时隙
        TotalTimeSlots  % 总时隙数
        Statistics      % 仿真统计
    end
    
    methods
        function obj = Simulator(totalTimeSlots)
            % 构造函数
            if nargin < 1
                totalTimeSlots = 1000;
            end
            
            obj.MEC = MEC();
            obj.TaskManager = TaskManager();
            obj.LyapunovManager = LyapunovManager();
            obj.Scheduler = Scheduler(constants.GreedySchedule, constants.VV_DEFAULT); % 默认使用贪心调度
            obj.CurrentTimeSlot = 0;
            obj.TotalTimeSlots = totalTimeSlots;
            obj.Statistics = SimulationStats();
            
            % 初始化任务类型统计
            K = constants.K();
            for i = 1:K
                obj.Statistics.TaskTypeStats(i) = TaskTypeStat();
            end
        end
        
        function setCacheStrategy(obj, strategy)
            % 设置缓存策略
            obj.MEC.setCacheStrategy(strategy);
        end
        
        function setScheduleStrategy(obj, algorithm, vv)
            % 设置调度策略 和 李雅普诺夫漂移参数
            if nargin < 3
                vv = constants.VV_DEFAULT;
            end
            obj.Scheduler = Scheduler(algorithm, vv);
        end
        
        function runSimulation(obj)
            % 运行仿真
            fprintf('开始仿真，总时隙数: %d\n', obj.TotalTimeSlots);
            
            for t = 0:(obj.TotalTimeSlots-1)
                obj.CurrentTimeSlot = t;
                obj.runTimeSlot();
                
                % 每100个时隙输出一次进度
                if mod(t+1, 100) == 0
                    fprintf('时隙进度: %d/%d\n', t+1, obj.TotalTimeSlots);
                end
            end
            
            obj.printStatistics();
        end
        
        function runTimeSlot(obj)
            % 运行单个时隙
            % 更新MEC的当前时隙
            obj.MEC.updateTimeSlot(obj.CurrentTimeSlot);
            
            % 用于当前时隙收益计算的数据
            scheduledTasks = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            completedTasks = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            cacheHitTasks = containers.Map('KeyType', 'int32', 'ValueType', 'any');

            % 1. 生成新任务并处理过期任务
            newTasks = obj.TaskManager.generateRandomTasks(obj.CurrentTimeSlot);
            obj.Statistics.TotalTasksGenerated = obj.Statistics.TotalTasksGenerated + length(newTasks);
            
            % 更新任务类型生成统计和访问统计
            for i = 1:length(newTasks)
                task = newTasks{i};
                stat = obj.Statistics.TaskTypeStats(task.TaskType);
                stat.Generated = stat.Generated + 1;
                % 记录任务访问（正确的访问统计方式）
                obj.MEC.recordTaskAccess(task.TaskType);
            end
            
            % 移除过期任务
            expiredCounts = obj.TaskManager.removeExpiredTasks(obj.CurrentTimeSlot);
            keys = cell2mat(expiredCounts.keys);
            for i = 1:length(keys)
                taskType = keys(i);
                count = expiredCounts(taskType);
                obj.Statistics.TotalTasksDropped = obj.Statistics.TotalTasksDropped + count;
                stat = obj.Statistics.TaskTypeStats(taskType);
                stat.Dropped = stat.Dropped + count;
            end
            
            % 2. 统一处理：先把所有新生成的任务都放到积压队列中
            for i = 1:length(newTasks)
                task = newTasks{i};
                obj.TaskManager.addToBacklog(task);
                obj.Statistics.TotalCacheAccess = obj.Statistics.TotalCacheAccess + 1;
            end
            
            % 3. 时隙开始检查：如果任务类型缓存命中，清空该类型积压队列
            K = constants.K();
            for taskType = 1:K
                backlogCount = obj.TaskManager.getBacklogCount(taskType);
                if backlogCount > 0
                    if obj.MEC.isCacheHit(taskType)
                        % 缓存命中，该类型所有积压任务直接完成
                        obj.Statistics.CacheHitCount = obj.Statistics.CacheHitCount + backlogCount;
                        obj.Statistics.TotalTasksCompleted = obj.Statistics.TotalTasksCompleted + backlogCount;
                        stat = obj.Statistics.TaskTypeStats(taskType);
                        stat.CacheHits = stat.CacheHits + backlogCount;
                        stat.Completed = stat.Completed + backlogCount;
                        
                        % 记录缓存命中任务的总优先级
                        if obj.TaskManager.TaskTypes.isKey(taskType)
                            tt = obj.TaskManager.TaskTypes(taskType);
                            stat.CacheHitPrioritySum = stat.CacheHitPrioritySum + (backlogCount * tt.Priority);
                            
                            % 记录用于收益计算
                            hitInfo.backlogCount = backlogCount;
                            hitInfo.metaK = tt.MetaK;
                            cacheHitTasks(taskType) = hitInfo;
                        end
                        
                        obj.TaskManager.removeTasksFromBacklog(taskType, backlogCount);
                    end
                end
            end
            
            % 4. 调度积压队列中的任务
            schedulingResults = obj.Scheduler.scheduleTasks(obj.MEC, obj.TaskManager, obj.LyapunovManager);
            for i = 1:length(schedulingResults)
                res = schedulingResults{i};
                % 记录用于收益计算
                if obj.TaskManager.TaskTypes.isKey(res.TaskType) && res.NodeID > 0
                    tt = obj.TaskManager.TaskTypes(res.TaskType);
                    taskInfo.node = obj.MEC.VirtualNodes{res.NodeID};
                    taskInfo.mkr = res.MKR;
                    taskInfo.ck = tt.Ck;
                    taskInfo.backlogCount = res.CompletedTasks; % 假设调度一个任务就完成一个
                    scheduledTasks(res.TaskType) = taskInfo;
                end
            end
                  
            % 5. 更新虚拟节点状态
            completedTaskTypesMap = obj.MEC.updateNodes();
            completedTaskTypes = cell2mat(keys(completedTaskTypesMap));

            % 遍历所有类型积压队列，清空completedTaskTypes中存在的任务类型对应的积压队列
            % TotalTasksCompleted的统计应该等于对应的积压队列中的任务
            for i = 1:length(completedTaskTypes)
                taskType = completedTaskTypes(i);
                backlogCount = obj.TaskManager.getBacklogCount(taskType);
                
                if backlogCount > 0
                    obj.Statistics.TotalTasksCompleted = obj.Statistics.TotalTasksCompleted + backlogCount;
                    stat = obj.Statistics.TaskTypeStats(taskType);
                    stat.Completed = stat.Completed + backlogCount;
                    
                    % 记录用于收益计算
                    completedTasks(taskType) = backlogCount;

                    obj.TaskManager.removeTasksFromBacklog(taskType, backlogCount);
                end
            end
            
            % 更新任务类型完成统计 (这部分逻辑在上面处理积压队列时已完成)
            
            % 6. 缓存更新：完成的任务类型添加到缓存
            for i = 1:length(completedTaskTypes)
                taskType = completedTaskTypes(i);
                if obj.TaskManager.TaskTypes.isKey(taskType)
                    tt = obj.TaskManager.TaskTypes(taskType);
                    obj.MEC.addToCache(taskType, tt.MetaK, obj.TaskManager);
                end
            end
            
            % 7. 更新李雅普诺夫队列
            for taskType = 1:K
                % 计算bk(t) - 本时隙完成的该类型任务数
                bk = 0;
                for j = 1:length(schedulingResults)
                    if schedulingResults{j}.TaskType == taskType
                        bk = bk + schedulingResults{j}.CompletedTasks;
                    end
                end
                
                % 计算ak(t) - 本时隙新到达的该类型任务数
                ak = 0;
                for j = 1:length(newTasks)
                    if newTasks{j}.TaskType == taskType
                        ak = ak + 1;
                    end
                end
                
                % 计算丢弃的任务数
                droppedCount = 0;
                if expiredCounts.isKey(taskType)
                    droppedCount = expiredCounts(taskType);
                end
                
                obj.LyapunovManager.updateQueue(taskType, bk, droppedCount, ak, obj.TaskManager);
            end
            
            % 8. 更新收益
            obj.MEC.updateRevenue(obj.TaskManager, scheduledTasks, completedTasks, cacheHitTasks);
            obj.Statistics.TotalRevenue = obj.MEC.Revenue; % 直接使用MEC累计的总收益
            
            % 记录用于绘图的时序数据
            obj.Statistics.recordTimeseriesData(obj.CurrentTimeSlot + 1, obj.MEC, obj.TaskManager, obj.LyapunovManager);
        end
        
        function printStatistics(obj)
            % 打印统计信息
            fprintf('\n=== 仿真统计结果 ===\n');
            fprintf('总时隙数: %d\n', obj.TotalTimeSlots);
            fprintf('总生成任务数: %d\n', obj.Statistics.TotalTasksGenerated);
            fprintf('总完成任务数: %d\n', obj.Statistics.TotalTasksCompleted);
            fprintf('总丢弃任务数: %d\n', obj.Statistics.TotalTasksDropped);
            fprintf('任务完成率: %.2f%%\n', obj.Statistics.TotalTasksCompleted / obj.Statistics.TotalTasksGenerated * 100);
            fprintf('缓存命中次数: %d\n', obj.Statistics.CacheHitCount);
            fprintf('总缓存访问次数: %d\n', obj.Statistics.TotalCacheAccess);
            
            if obj.Statistics.TotalCacheAccess > 0
                fprintf('缓存命中率: %.2f%%\n', obj.Statistics.CacheHitCount / obj.Statistics.TotalCacheAccess * 100);
            else
                fprintf('缓存命中率: 0.00%%\n');
            end
            
            fprintf('缓存利用率: %.2f%%\n', obj.MEC.getCacheUtilization() * 100);
            fprintf('节点利用率: %.2f%%\n', obj.MEC.getNodeUtilization() * 100);
            fprintf('最终收益: %.2f\n', obj.MEC.Revenue);
            fprintf('最终收入: %.2f\n', obj.MEC.Income);
            fprintf('最终成本: %.2f\n', obj.MEC.Cost);
            
            % 计算平均队列长度
            totalLyapunovQueueLength = 0;
            K = constants.K();
            for i = 1:K
                totalLyapunovQueueLength = totalLyapunovQueueLength + obj.LyapunovManager.getQueueLength(i);
            end
            obj.Statistics.AverageLyapunovQueueLength = totalLyapunovQueueLength / K;
            fprintf('平均队列长度: %.2f\n', obj.Statistics.AverageLyapunovQueueLength);
            % 挤压队列平均长度
            totalBacklogQueueLength = 0;
            for i = 1:K
                totalBacklogQueueLength = totalBacklogQueueLength + obj.TaskManager.getBacklogCount(i);
            end
            obj.Statistics.AverageBacklogQueueLength = totalBacklogQueueLength / K;
            fprintf('平均挤压队列长度: %.2f\n', obj.Statistics.AverageBacklogQueueLength);
            
            % 打印各任务类型统计
            fprintf('\n=== 任务类型统计 ===\n');
            keys = cell2mat(obj.Statistics.TaskTypeStats.keys);
            for i = 1:length(keys)
                taskType = keys(i);
                stat = obj.Statistics.TaskTypeStats(taskType);
                fprintf('任务类型 %d: 生成=%d, 完成=%d, 丢弃=%d, 缓存命中=%d\n', ...
                    taskType, stat.Generated, stat.Completed, stat.Dropped, stat.CacheHits);
            end
        end
        
        function stats = getStatistics(obj)
            % 获取统计信息
            stats = obj.Statistics;
        end
    end
end
