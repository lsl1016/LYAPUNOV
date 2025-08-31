function plot4_cache_strategy_comparison()
% plot4_cache_strategy_comparison.m - 缓存策略性能对比柱状图
% 
% 包含两组独立的柱状图：
% 第一组：不同任务类型数量K下的缓存策略性能对比（N=10）
% 第二组：不同任务生成数量N下的缓存策略性能对比（K=15）
% 
% 纵坐标包括：MEC时间平均收益、任务积压队列平均长度、MEC缓存任务类型总价值、
% 缓存命中率、缓存命中任务总优先级
% 图例为：调度算法使用LyapunovSchedule + 五种不同的缓存更新算法

clc;close all;clear;

fprintf('=== 开始缓存策略性能对比实验 ===\n');

% 第一组实验：不同任务类型数量K下的缓存策略对比
fprintf('\n--- 第一组：不同任务类型数量K下的缓存策略对比 ---\n');
plot_cache_strategies_vs_k();

% 第二组实验：不同任务生成数量N下的缓存策略对比
fprintf('\n--- 第二组：不同任务生成数量N下的缓存策略对比 ---\n');
plot_cache_strategies_vs_n();
fprintf('=== 缓存策略性能对比实验完成 ===\n');

end

function plot_cache_strategies_vs_k()
% 第一组：
% 横坐标取不同的任务类型 k= [40,50,60,70,80], 单时隙的产生任务数量 N=20
% 纵坐标分别为（所有时隙的） MEC的时间平均收益（总收入/总时隙）、任务积压队列的平均长度（所有任务类型的总积压长度/总时隙）、MEC缓存的任务类型总价值，
% 所有时隙的缓存命中率、所有时隙的所有任务缓存命中任务总优先级
% 图例为：调度算法使用LyapunovSchedule = 3 + 五种不同的缓存更新算法（FIFO、LRU、LFU、Priority、Knapsack）

% 实验参数设置
k_values = [40,50,60,70,80];
fixed_n = 20;                      
totalTimeSlots = 500;         
constants.totalCacheSize(1000);    

% 缓存算法设置
cache_algorithms = [
    constants.FIFO,...
    constants.LRU,...
    constants.LFU,...
    constants.Priority,...
    constants.Knapsack
];

cache_names = {
    'FIFO缓存'...
    'LRU缓存'...
    'LFU缓存'...
    'Priority缓存'...
    'Knapsack缓存'...   
};

num_k = length(k_values);
num_cache_algs = length(cache_algorithms);

% 存储结果
results_revenue = zeros(num_cache_algs, num_k);
results_backlog = zeros(num_cache_algs, num_k);
results_cache_value = zeros(num_cache_algs, num_k);
results_hit_rate = zeros(num_cache_algs, num_k);
results_hit_priority = zeros(num_cache_algs, num_k);

% 运行仿真实验
for k_idx = 1:num_k
    current_k = k_values(k_idx);
    constants.K(current_k);        % 设置任务类型数量
    constants.N(fixed_n);          % 设置每时隙生成任务数
    
    fprintf('正在测试K=%d (%d/%d)...\n', current_k, k_idx, num_k);
    
    for cache_idx = 1:num_cache_algs
        cache_alg = cache_algorithms(cache_idx);
        cache_name = cache_names{cache_idx};
        
        fprintf('  缓存算法: %s (%d/%d)\n', cache_name, cache_idx, num_cache_algs);
        
        % 创建仿真器
        sim = Simulator(totalTimeSlots);
        
        % 设置调度策略为李雅普诺夫调度
        sim.setScheduleStrategy(constants.LyapunovSchedule, constants.VV_DEFAULT);
        
        % 设置缓存策略
        sim.setCacheStrategy(cache_alg);
        
        % 运行仿真（静默模式）
        try
            evalc('sim.runSimulation()');
        catch ME
            fprintf('    仿真过程中出错: %s\n', ME.message);
            continue;
        end
        
        % 获取统计结果
        stats = sim.getStatistics();
        results_revenue(cache_idx, k_idx) = stats.AverageRevenue;
        results_backlog(cache_idx, k_idx) = stats.AverageBacklogQueueLength;
        
        % 计算缓存总价值
        results_cache_value(cache_idx, k_idx) = sim.MEC.getCacheTotalValue(sim.TaskManager);
        
        % 计算缓存命中率
        if stats.TotalCacheAccess > 0
            results_hit_rate(cache_idx, k_idx) = stats.CacheHitCount / stats.TotalCacheAccess * 100;
        else
            results_hit_rate(cache_idx, k_idx) = 0;
        end
        
        % 计算所有任务缓存命中任务总优先级
        total_hit_priority = 0;
        keys = cell2mat(stats.TaskTypeStats.keys);
        for i = 1:length(keys)
            taskType = keys(i);
            stat = stats.TaskTypeStats(taskType);
            total_hit_priority = total_hit_priority + stat.CacheHitPrioritySum;
        end
        results_hit_priority(cache_idx, k_idx) = total_hit_priority;
        
        fprintf('    完成，平均收益: %.4f, 平均积压长度: %.2f, 缓存价值: %.2f, 命中率: %.2f%%, 命中优先级: %.0f\n', ...
                results_revenue(cache_idx, k_idx), results_backlog(cache_idx, k_idx), ...
                results_cache_value(cache_idx, k_idx), results_hit_rate(cache_idx, k_idx), ...
                results_hit_priority(cache_idx, k_idx));
    end
end

% 绘制第一组柱状图：MEC时间平均收益
figure;
bar_data_revenue = results_revenue';
bar(k_values, bar_data_revenue);
xlabel('任务类型数量 K');
ylabel('MEC时间平均收益');
title(sprintf('不同任务类型数量K下各缓存策略的MEC时间平均收益对比 (N=%d, 李雅普诺夫调度)', fixed_n));
legend(cache_names, 'Location', 'best');
grid on;
% saveas(gcf, sprintf('plot4_group1_k_revenue_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 绘制第一组柱状图：任务积压队列的平均长度
figure;
bar_data_backlog = results_backlog';
bar(k_values, bar_data_backlog);
xlabel('任务类型数量 K');
ylabel('任务积压队列的平均长度');
title(sprintf('不同任务类型数量K下各缓存策略的任务积压队列平均长度对比 (N=%d, 李雅普诺夫调度)', fixed_n));
legend(cache_names, 'Location', 'best');
grid on;
% saveas(gcf, sprintf('plot4_group1_k_backlog_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 绘制第一组柱状图：MEC缓存的任务类型总价值
figure;
bar_data_cache_value = results_cache_value';
bar(k_values, bar_data_cache_value);
xlabel('任务类型数量 K');
ylabel('MEC缓存的任务类型总价值');
title(sprintf('不同任务类型数量K下各缓存策略的缓存总价值对比 (N=%d, 李雅普诺夫调度)', fixed_n));
legend(cache_names, 'Location', 'best');
grid on;
% saveas(gcf, sprintf('plot4_group1_k_cache_value_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 绘制第一组柱状图：缓存命中率
figure;
bar_data_hit_rate = results_hit_rate';
bar(k_values, bar_data_hit_rate);
xlabel('任务类型数量 K');
ylabel('缓存命中率 (%)');
title(sprintf('不同任务类型数量K下各缓存策略的缓存命中率对比 (N=%d, 李雅普诺夫调度)', fixed_n));
legend(cache_names, 'Location', 'best');
grid on;
% saveas(gcf, sprintf('plot4_group1_k_hit_rate_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 绘制第一组柱状图：缓存命中任务总优先级
figure;
bar_data_hit_priority = results_hit_priority';
bar(k_values, bar_data_hit_priority);
xlabel('任务类型数量 K');
ylabel('缓存命中任务总优先级');
title(sprintf('不同任务类型数量K下各缓存策略的缓存命中任务总优先级对比 (N=%d, 李雅普诺夫调度)', fixed_n));
legend(cache_names, 'Location', 'best');
grid on;
% saveas(gcf, sprintf('plot4_group1_k_hit_priority_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 保存第一组数据
results_table1 = table();
results_table1.K_Values = k_values';
for cache_idx = 1:num_cache_algs
    cache_suffix = strrep(cache_names{cache_idx}, '缓存', '');
    results_table1.(sprintf('Revenue_%s', cache_suffix)) = results_revenue(cache_idx, :)';
    results_table1.(sprintf('Backlog_%s', cache_suffix)) = results_backlog(cache_idx, :)';
    results_table1.(sprintf('CacheValue_%s', cache_suffix)) = results_cache_value(cache_idx, :)';
    results_table1.(sprintf('HitRate_%s', cache_suffix)) = results_hit_rate(cache_idx, :)';
    results_table1.(sprintf('HitPriority_%s', cache_suffix)) = results_hit_priority(cache_idx, :)';
end
% 
% filename1 = sprintf('plot4_group1_k_cache_comparison_%s.csv', datestr(now, 'yyyymmdd_HHMMSS'));
% writetable(results_table1, filename1);
% fprintf('第一组结果已保存到文件: %s\n', filename1);

end

function plot_cache_strategies_vs_n()
% 第二组：
% 横坐标取单时隙产生的不同任务数量 N= [10, 15, 20, 25, 30], 任务类型数量 K固定为 50
% 纵坐标分别为（所有时隙的） MEC的时间平均收益（总收入/总时隙）、任务积压队列的平均长度（所有任务类型的总积压长度/总时隙）、MEC缓存的任务类型总价值，
% 所有时隙的缓存命中率、所有时隙的所有任务缓存命中任务总优先级
% 图例为：调度算法使用LyapunovSchedule = 3 + 五种不同的缓存更新算法（FIFO、LRU、LFU、Priority、Knapsack）

% 实验参数设置
n_values = [10, 15, 20, 25, 30];
fixed_k = 50;                      
totalTimeSlots = 500;              
constants.totalCacheSize(1000);    

% 缓存算法设置
cache_algorithms = [
    constants.FIFO,...
    constants.LRU,...   
    constants.LFU,...
    constants.Priority,...
    constants.Knapsack
];

cache_names = {
    'FIFO缓存'...
    'LRU缓存'...
    'LFU缓存'...
    'Priority缓存'...
    'Knapsack缓存'...
};

num_n = length(n_values);
num_cache_algs = length(cache_algorithms);

% 存储结果
results_revenue = zeros(num_cache_algs, num_n);
results_backlog = zeros(num_cache_algs, num_n);
results_cache_value = zeros(num_cache_algs, num_n);
results_hit_rate = zeros(num_cache_algs, num_n);
results_hit_priority = zeros(num_cache_algs, num_n);

% 运行仿真实验
for n_idx = 1:num_n
    current_n = n_values(n_idx);
    constants.K(fixed_k);          % 设置任务类型数量
    constants.N(current_n);        % 设置每时隙生成任务数
    
    fprintf('正在测试N=%d (%d/%d)...\n', current_n, n_idx, num_n);
    
    for cache_idx = 1:num_cache_algs
        cache_alg = cache_algorithms(cache_idx);
        cache_name = cache_names{cache_idx};
        
        fprintf('  缓存算法: %s (%d/%d)\n', cache_name, cache_idx, num_cache_algs);
        
        % 创建仿真器
        sim = Simulator(totalTimeSlots);
        
        % 设置调度策略为李雅普诺夫调度
        sim.setScheduleStrategy(constants.LyapunovSchedule, constants.VV_DEFAULT);
        
        % 设置缓存策略
        sim.setCacheStrategy(cache_alg);
        
        % 运行仿真（静默模式）
        try
            evalc('sim.runSimulation()');
        catch ME
            fprintf('    仿真过程中出错: %s\n', ME.message);
            continue;
        end
        
        % 获取统计结果
        stats = sim.getStatistics();
        results_revenue(cache_idx, n_idx) = stats.AverageRevenue;
        results_backlog(cache_idx, n_idx) = stats.AverageBacklogQueueLength;
        
        % 计算缓存总价值
        results_cache_value(cache_idx, n_idx) = sim.MEC.getCacheTotalValue(sim.TaskManager);
        
        % 计算缓存命中率
        if stats.TotalCacheAccess > 0
            results_hit_rate(cache_idx, n_idx) = stats.CacheHitCount / stats.TotalCacheAccess * 100;
        else
            results_hit_rate(cache_idx, n_idx) = 0;
        end
        
        % 计算所有任务缓存命中任务总优先级
        total_hit_priority = 0;
        keys = cell2mat(stats.TaskTypeStats.keys);
        for i = 1:length(keys)
            taskType = keys(i);
            stat = stats.TaskTypeStats(taskType);
            total_hit_priority = total_hit_priority + stat.CacheHitPrioritySum;
        end
        results_hit_priority(cache_idx, n_idx) = total_hit_priority;
        
        fprintf('    完成，平均收益: %.4f, 平均积压长度: %.2f, 缓存价值: %.2f, 命中率: %.2f%%, 命中优先级: %.0f\n', ...
                results_revenue(cache_idx, n_idx), results_backlog(cache_idx, n_idx), ...
                results_cache_value(cache_idx, n_idx), results_hit_rate(cache_idx, n_idx), ...
                results_hit_priority(cache_idx, n_idx));
    end
end

% 绘制第二组柱状图：MEC时间平均收益
figure;
bar_data_revenue = results_revenue';
bar(n_values, bar_data_revenue);
xlabel('每时隙生成任务数量 N');
ylabel('MEC时间平均收益');
title(sprintf('不同任务生成数量N下各缓存策略的MEC时间平均收益对比 (K=%d, 李雅普诺夫调度)', fixed_k));
legend(cache_names, 'Location', 'best');
grid on;
% saveas(gcf, sprintf('plot4_group2_n_revenue_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 绘制第二组柱状图：任务积压队列的平均长度
figure;
bar_data_backlog = results_backlog';
bar(n_values, bar_data_backlog);
xlabel('每时隙生成任务数量 N');
ylabel('任务积压队列的平均长度');
title(sprintf('不同任务生成数量N下各缓存策略的任务积压队列平均长度对比 (K=%d, 李雅普诺夫调度)', fixed_k));
legend(cache_names, 'Location', 'best');
grid on;
%saveas(gcf, sprintf('plot4_group2_n_backlog_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 绘制第二组柱状图：MEC缓存的任务类型总价值
figure;
bar_data_cache_value = results_cache_value';
bar(n_values, bar_data_cache_value);
xlabel('每时隙生成任务数量 N');
ylabel('MEC缓存的任务类型总价值');
title(sprintf('不同任务生成数量N下各缓存策略的缓存总价值对比 (K=%d, 李雅普诺夫调度)', fixed_k));
legend(cache_names, 'Location', 'best');
grid on;
% saveas(gcf, sprintf('plot4_group2_n_cache_value_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 绘制第二组柱状图：缓存命中率
figure;
bar_data_hit_rate = results_hit_rate';
bar(n_values, bar_data_hit_rate);
xlabel('每时隙生成任务数量 N');
ylabel('缓存命中率 (%)');
title(sprintf('不同任务生成数量N下各缓存策略的缓存命中率对比 (K=%d, 李雅普诺夫调度)', fixed_k));
legend(cache_names, 'Location', 'best');
grid on;
% saveas(gcf, sprintf('plot4_group2_n_hit_rate_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 绘制第二组柱状图：缓存命中任务总优先级
figure;
bar_data_hit_priority = results_hit_priority';
bar(n_values, bar_data_hit_priority);
xlabel('每时隙生成任务数量 N');
ylabel('缓存命中任务总优先级');
title(sprintf('不同任务生成数量N下各缓存策略的缓存命中任务总优先级对比 (K=%d, 李雅普诺夫调度)', fixed_k));
legend(cache_names, 'Location', 'best');
grid on;
% saveas(gcf, sprintf('plot4_group2_n_hit_priority_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 保存第二组数据
results_table2 = table();
results_table2.N_Values = n_values';
for cache_idx = 1:num_cache_algs
    cache_suffix = strrep(cache_names{cache_idx}, '缓存', '');
    results_table2.(sprintf('Revenue_%s', cache_suffix)) = results_revenue(cache_idx, :)';
    results_table2.(sprintf('Backlog_%s', cache_suffix)) = results_backlog(cache_idx, :)';
    results_table2.(sprintf('CacheValue_%s', cache_suffix)) = results_cache_value(cache_idx, :)';
    results_table2.(sprintf('HitRate_%s', cache_suffix)) = results_hit_rate(cache_idx, :)';
    results_table2.(sprintf('HitPriority_%s', cache_suffix)) = results_hit_priority(cache_idx, :)';
end

% filename2 = sprintf('plot4_group2_n_cache_comparison_%s.csv', datestr(now, 'yyyymmdd_HHMMSS'));
% writetable(results_table2, filename2);
% fprintf('第二组结果已保存到文件: %s\n', filename2);

end