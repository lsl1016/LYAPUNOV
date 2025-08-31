classdef Scheduler < handle
    % Scheduler 调度器
    
    properties
        Algorithm  % 调度算法类型
        LyapunovVV % 李雅普诺夫漂移参数
    end
    
    methods
        function obj = Scheduler(algorithm, vv)
            % 构造函数
            if nargin < 2
                vv = constants.VV_DEFAULT;
            end
            obj.Algorithm = algorithm;
            obj.LyapunovVV = vv;
        end
        
        function results = scheduleTasks(obj, mec, taskManager, lyapunovManager)
            % 根据调度算法调度任务
            switch obj.Algorithm
                case constants.GreedySchedule
                    results = obj.greedySchedule(mec, taskManager);
                case constants.ShortTermSchedule
                    results = obj.shortTermSchedule(mec, taskManager);
                case constants.LyapunovSchedule
                    results = obj.lyapunovSchedule(mec, taskManager, lyapunovManager);
                case constants.NoCacheSchedule
                    results = obj.noCacheSchedule(mec, taskManager, lyapunovManager);
                otherwise
                    results = obj.greedySchedule(mec, taskManager);
            end
        end

        % TODO: 调整参数，修正算法

        function results = greedySchedule(obj, mec, taskManager)
            % 贪心调度策略（原有简单策略）
            results = {};
            idleNodes = mec.getIdleNodes();
            
            if isempty(idleNodes)
                return;
            end
            
            % 获取积压队列中的任务类型
            candidateTasks = obj.getCandidateTasks(mec, taskManager);
            if isempty(candidateTasks)
                return;
            end
            
            % 按价值排序
            sortedTasks = obj.sortTasksByValue(candidateTasks);
            
            % 贪心分配
            nodeIndex = 1;
            for i = 1:min(length(sortedTasks), length(idleNodes))
                task = sortedTasks{i};
                node = idleNodes{nodeIndex};
                
                % 计算fkr
                taskTypeInfo = taskManager.TaskTypes(task.TaskType);
                
                % 生成随机的mkr值（因为TaskValue2中没有存储）
                mkr = randi([constants.MIN_MKR, constants.MAX_MKR]);
                if mec.scheduleTask(task.TaskType, node.ID, mkr, taskTypeInfo.Ck)
                    backlogCount = taskManager.getBacklogCount(task.TaskType);
                    results{end+1} = SchedulingResult(task.TaskType, node.ID, 0, backlogCount);
                    nodeIndex = nodeIndex + 1;
                end
            end
        end
        
        function results = lyapunovSchedule(obj, mec, taskManager, lyapunovManager)
            % 李雅普诺夫调度算法（调度算法3，KM匹配）
            results = {};
            idleNodes = mec.getIdleNodes();
            
            if isempty(idleNodes)
                return;
            end
            
            % 获取积压队列中的任务类型（过滤掉缓存命中和正在计算的）
            candidateTasks = obj.getCandidateTasks(mec, taskManager);
            if isempty(candidateTasks)
                return;
            end
            
            % 按价值（访问频率*优先级）排序，选择前K个任务类型
            sortedTasks = obj.sortTasksByValue(candidateTasks);
            maxTasks = length(idleNodes);
            if length(sortedTasks) > maxTasks
                sortedTasks = sortedTasks(1:maxTasks);
            end
            
            % 计算权重矩阵：根据李雅普诺夫优化理论
            % 目标：最大化 VV*(收益-成本) - Q*bkr
            % 但由于使用最小权重匹配，需要对权重取负值
            weights = zeros(length(sortedTasks), length(idleNodes));
            for i = 1:length(sortedTasks)
                task = sortedTasks{i};
                queueLength = lyapunovManager.getQueueLength(task.TaskType);
                
                for j = 1:length(idleNodes)
                    node = idleNodes{j};
                    % 计算bkr(t) - 使用taskTypeInfo获取正确的值
                    taskTypeInfo = taskManager.TaskTypes(task.TaskType);
                    mkr_temp = randi([constants.MIN_MKR, constants.MAX_MKR]); % 临时生成mkr值
                    bkr = TaskManager.calculateBKR(mkr_temp, taskTypeInfo.Ck, node.ComputeFrequency, false);
                    
                    % 计算能耗成本
                    frequencyGHz = node.ComputeFrequency / 1000.0;
                    energyCost = constants.AFIE * (frequencyGHz^3) * constants.NMT * constants.Tslot;
                    
                    % 李雅普诺夫优化权重计算：
                    % 目标函数：最大化 V*(收益-成本) - Q*服务增益
                    % 收益 = WCOM * 优先级，成本 = 能耗成本
                    immediateBenefit = constants.WCOM * task.Priority - energyCost;
                    stabilityTerm = queueLength * bkr;
                    
                    % 最终目标：最大化 V*immediateBenefit - stabilityTerm
                    % 但因为使用最小权重匹配，所以权重 = -(V*immediateBenefit - stabilityTerm)
                    weights(i, j) = -(obj.LyapunovVV * immediateBenefit - stabilityTerm);
                end
            end
            
            % 使用匈牙利算法求解最小权重匹配（实际上等价于最大化目标函数）
            matching = obj.hungarianAlgorithm(weights);
            
            % 执行匹配结果
            for i = 1:length(matching)
                nodeIndex = matching(i);
                if i <= length(sortedTasks) && nodeIndex ~= -1 && nodeIndex <= length(idleNodes)
                    task = sortedTasks{i};
                    node = idleNodes{nodeIndex};
                    taskTypeInfo = taskManager.TaskTypes(task.TaskType);
                    mkr = randi([constants.MIN_MKR, constants.MAX_MKR]);
                    
                    if mec.scheduleTask(task.TaskType, node.ID, mkr, taskTypeInfo.Ck)
                        % 获取该类型的积压任务数量
                        backlogCount = taskManager.getBacklogCount(task.TaskType);
                        
                        results{end+1} = SchedulingResult(task.TaskType, node.ID, weights(i, nodeIndex), backlogCount);
                        % 注意：不再在这里清空积压队列，由模拟器统一管理
                    end
                end
            end
        end
        
        function candidateTasks = getCandidateTasks(obj, mec, taskManager)
            % 获取候选调度任务（排除缓存命中和正在计算的任务类型）
            candidateTasks = {};
            
            keys = cell2mat(taskManager.BacklogQueue.keys);
            for i = 1:length(keys)
                taskType = keys(i);
                backlogCount = taskManager.getBacklogCount(taskType);
                
                if backlogCount > 0 && ~mec.isCacheHit(taskType) && ~mec.isTaskTypeComputing(taskType)
                    % 该任务类型在积压队列中且未缓存命中且未在计算
                    tt = taskManager.TaskTypes(taskType);
                    accessFreq = mec.AccessFrequency(taskType);
                    candidateTasks{end+1} = TaskValue2(taskType, tt.Priority, accessFreq, backlogCount, 0);
                end
            end
        end
        
        function sortedTasks = sortTasksByValue(obj, candidateTasks)
            % 按价值（访问频率*优先级）排序任务
            if isempty(candidateTasks)
                sortedTasks = {};
                return;
            end
            
            % 提取价值
            values = zeros(1, length(candidateTasks));
            for i = 1:length(candidateTasks)
                values(i) = candidateTasks{i}.Value;
            end
            
            % 排序（降序）
            [~, sortIndex] = sort(values, 'descend');
            
            sortedTasks = {};
            for i = 1:length(sortIndex)
                sortedTasks{end+1} = candidateTasks{sortIndex(i)};
            end
        end
        
        function matching = hungarianAlgorithm(obj, costMatrix)
            % 匈牙利算法实现（简化版本）
            % 这里使用MATLAB内置的assignmentoptimal函数来替代复杂的匈牙利算法实现
            
            [m, n] = size(costMatrix);
            if m == 0 || n == 0
                matching = [];
                return;
            end
            
            % 处理非方形矩阵
            if m < n
                % 添加虚拟行
                costMatrix = [costMatrix; inf(n-m, n)];
            elseif m > n
                % 添加虚拟列
                costMatrix = [costMatrix, inf(m, m-n)];
            end
            
            try
                % 使用MATLAB内置函数求解分配问题
                [assignment, ~] = assignmentoptimal(costMatrix);
                
                % 转换为匹配格式
                matching = zeros(1, m);
                for i = 1:m
                    if i <= length(assignment) && assignment(i) <= n
                        matching(i) = assignment(i);
                    else
                        matching(i) = -1; % 无匹配
                    end
                end
            catch
                % 如果没有优化工具箱，使用简单的贪心匹配
                warning('未找到assignmentoptimal函数，使用简单贪心匹配');
                matching = obj.greedyMatching(costMatrix(1:m, 1:n));
            end
        end
        
        function matching = greedyMatching(obj, costMatrix)
            % 简单的贪心匹配算法（作为备选方案）
            [m, n] = size(costMatrix);
            matching = -ones(1, m);
            usedCols = false(1, n);
            
            for i = 1:m
                [minVal, minCol] = min(costMatrix(i, :));
                % 找到最小值且未被使用的列
                for j = 1:n
                    if costMatrix(i, j) == minVal && ~usedCols(j)
                        matching(i) = j;
                        usedCols(j) = true;
                        break;
                    end
                end
            end
        end
        
        function results = shortTermSchedule(obj, mec, taskManager)
            results = obj.greedySchedule(mec, taskManager);
        end
        
        function results = noCacheSchedule(obj, mec, taskManager, lyapunovManager)
            % 无缓存调度算法的实现
            results = obj.lyapunovSchedule(mec, taskManager, lyapunovManager);
        end
    end
end
