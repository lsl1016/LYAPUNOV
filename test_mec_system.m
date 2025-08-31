function test_mec_system()
    % test_mec_system.m - MEC系统测试和示例程序
    
    fprintf('=== MEC系统测试程序 ===\n\n');
    
    % 测试1: 基本组件测试
    fprintf('1. 测试基本组件...\n');
    test_basic_components();
    
    % 测试2: 简单仿真测试
    fprintf('2. 运行简单仿真测试...\n');
    test_simple_simulation();
    
    % 测试3: 缓存策略对比测试
    fprintf('3. 测试不同缓存策略...\n');
    test_cache_strategies();
    
    fprintf('\n=== 所有测试完成 ===\n');
end

function test_basic_components()
    % 测试基本组件功能
    
    try
        % 测试常量
        fprintf('  - 测试常量定义... ');
        assert(Constants.V == 5, '虚拟节点数量错误');
        assert(Constants.K() == 20, '任务类型数量错误');
        fprintf('通过\n');
        
        % 测试任务管理器
        fprintf('  - 测试任务管理器... ');
        tm = TaskManager();
        assert(~isempty(tm.TaskTypes), '任务类型未初始化');
        assert(tm.TaskTypes.Count == Constants.K(), '任务类型数量错误');
        task = tm.generateTask(1, 0);
        assert(~isempty(task), '任务生成失败');
        assert(task.TaskType == 1, '任务类型错误');
        fprintf('通过\n');
        
        % 测试MEC节点
        fprintf('  - 测试MEC节点... ');
        mec = MEC();
        assert(length(mec.VirtualNodes) == Constants.V, '虚拟节点数量错误');
        assert(mec.Cache.Count == 0, '缓存应为空');
        fprintf('通过\n');
        
        % 测试李雅普诺夫管理器
        fprintf('  - 测试李雅普诺夫管理器... ');
        lm = LyapunovManager();
        assert(lm.Queues.Count == Constants.K(), '队列数量错误');
        assert(lm.getQueueLength(1) == 0, '初始队列长度应为0');
        fprintf('通过\n');
        
        % 测试调度器
        fprintf('  - 测试调度器... ');
        scheduler = Scheduler(Constants.GreedySchedule, Constants.VV_DEFAULT);
        assert(scheduler.Algorithm == Constants.GreedySchedule, '调度算法错误');
        fprintf('通过\n');
        
    catch ME
        fprintf('失败: %s\n', ME.message);
        rethrow(ME);
    end
end

function test_simple_simulation()
    % 测试简单仿真
    
    try
        fprintf('  - 创建仿真器... ');
        sim = Simulator(50); % 运行50个时隙
        fprintf('完成\n');
        
        fprintf('  - 运行仿真... ');
        sim.runSimulation();
        fprintf('完成\n');
        
        % 检查统计结果
        stats = sim.getStatistics();
        assert(stats.TotalTasksGenerated > 0, '应该生成了任务');
        
        fprintf('  - 简单仿真测试完成，生成任务数: %d，完成任务数: %d\n', ...
            stats.TotalTasksGenerated, stats.TotalTasksCompleted);
        
    catch ME
        fprintf('失败: %s\n', ME.message);
        rethrow(ME);
    end
end

function test_cache_strategies()
    % 测试不同缓存策略
    
    timeSlots = 100;
    cacheStrategies = [Constants.FIFO, Constants.LRU, Constants.Knapsack];
    strategyNames = {'FIFO', 'LRU', 'Knapsack'};
    
    fprintf('  - 测试缓存策略对比 (时隙数: %d)\n', timeSlots);
    
    results = [];
    
    for i = 1:length(cacheStrategies)
        strategy = cacheStrategies(i);
        strategyName = strategyNames{i};
        
        fprintf('    测试 %s 策略... ', strategyName);
        
        % 创建仿真器
        sim = Simulator(timeSlots);
        sim.setCacheStrategy(strategy);
        sim.setScheduleStrategy(Constants.GreedySchedule);
        
        % 运行仿真（不输出详细信息）
        sim.MEC.updateTimeSlot(0);
        
        for t = 0:(timeSlots-1)
            sim.CurrentTimeSlot = t;
            sim.runTimeSlot();
        end
        
        % 收集结果
        stats = sim.getStatistics();
        result = struct();
        result.strategy = strategyName;
        result.completionRate = stats.TotalTasksCompleted / stats.TotalTasksGenerated * 100;
        result.cacheHitRate = 0;
        if stats.TotalCacheAccess > 0
            result.cacheHitRate = stats.CacheHitCount / stats.TotalCacheAccess * 100;
        end
        result.revenue = sim.MEC.Revenue;
        
        results = [results, result];
        
        fprintf('完成率: %.1f%%, 命中率: %.1f%%, 收益: %.2f\n', ...
            result.completionRate, result.cacheHitRate, result.revenue);
    end
    
    % 找出最佳策略
    revenues = [results.revenue];
    [~, bestIdx] = max(revenues);
    fprintf('  - 最佳策略: %s (收益: %.2f)\n', results(bestIdx).strategy, results(bestIdx).revenue);
end

function quick_demo()
    % 快速演示程序
    
    fprintf('=== MEC系统快速演示 ===\n\n');
    
    % 创建一个简单的仿真
    fprintf('创建仿真环境...\n');
    sim = Simulator(200);
    
    fprintf('设置策略：李雅普诺夫调度 + 背包缓存\n');
    sim.setScheduleStrategy(Constants.LyapunovSchedule, Constants.VV_DEFAULT);
    sim.setCacheStrategy(Constants.Knapsack);
    
    fprintf('开始仿真...\n\n');
    
    % 运行仿真
    sim.runSimulation();
    
    fprintf('\n演示完成！\n');
end

