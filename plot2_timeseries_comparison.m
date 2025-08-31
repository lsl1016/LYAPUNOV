function plot2_timeseries_comparison()
% plot2_timeseries_comparison.m - 时序性能对比折线图
% 
% 包含两组独立的折线图：
% 第一组：四种调度算法的时序性能对比（统一使用背包缓存算法）
% 第二组：五种缓存算法的时序性能对比（使用李雅普诺夫调度算法）

clc;close all;clear;

fprintf('=== 开始时序性能对比实验 ===\n');

% 第一组实验：四种调度算法对比
fprintf('\n--- 第一组：调度算法对比 ---\n');
plot_scheduling_algorithms_comparison();

% 第二组实验：五种缓存算法对比
fprintf('\n--- 第二组：缓存算法对比 ---\n');
plot_cache_algorithms_comparison();

fprintf('=== 时序性能对比实验完成 ===\n');

end

function plot_scheduling_algorithms_comparison()
% 第一组：横坐标为时隙（0——Tsolt），纵坐标分别为MEC时间平均收益、任务积压队列的平均长度
% 图例为：四种调度算法，缓存更新统一使用背包算法，最后一种调度应该是不启用缓存的

% 实验参数设置
totalTimeSlots = 500;      % 仿真时隙数
constants.K(40);           % 任务类型数量
constants.N(20);           % 每时隙生成任务数

% 调度算法设置
scheduling_algorithms = [
    constants.GreedySchedule,...      % 贪心调度
    constants.ShortTermSchedule,...   % 短期调度  
    constants.LyapunovSchedule,...    % 李雅普诺夫调度
    constants.NoCacheSchedule         % 无缓存调度
];

algorithm_names = {
    '贪心调度+背包缓存',...
    '短期调度+背包缓存', ...
    '李雅普诺夫调度+背包缓存',...
    '无缓存调度'
};

% 定义线型和标记符号（参考绘图样式模板）
lineStyles = {'-', '-.', '--', ':'};
markers = {'+', 'o', '*', 'x'};
lineWidth = 1.4;

num_algorithms = length(scheduling_algorithms);

% 存储每个算法的时序数据
time_series_revenue = zeros(num_algorithms, totalTimeSlots);
time_series_backlog = zeros(num_algorithms, totalTimeSlots);

% 运行仿真实验
for alg_idx = 1:num_algorithms
    algorithm = scheduling_algorithms(alg_idx);
    alg_name = algorithm_names{alg_idx};
    
    fprintf('正在测试调度算法: %s (%d/%d)...\n', alg_name, alg_idx, num_algorithms);
    
    % 创建仿真器
    sim = Simulator(totalTimeSlots);
    
    % 打印任务类型的静态信息
    sim.TaskManager.printTaskTypeStaticInfo();
    
    % 设置调度策略
    sim.setScheduleStrategy(algorithm, constants.VV_DEFAULT);
    
    % 设置缓存策略（无缓存调度除外）
    if algorithm ~= constants.NoCacheSchedule
        sim.setCacheStrategy(constants.Knapsack);
    else
        sim.MEC.setCacheEnabled(false);
    end
    
    % 运行仿真并记录每个时隙的数据
    sim.MEC.updateTimeSlot(0);
    
    for t = 0:(totalTimeSlots-1)
        sim.CurrentTimeSlot = t;
        sim.runTimeSlot();
        
        % 记录当前时隙的数据
        time_series_revenue(alg_idx, t+1) = sim.Statistics.AverageRevenue;
        
        % 计算积压队列平均长度
        total_backlog = 0;
        K = constants.K();
        for k = 1:K
            total_backlog = total_backlog + sim.TaskManager.getBacklogCount(k);
        end
        time_series_backlog(alg_idx, t+1) = total_backlog / K;
    end
    
    fprintf('完成，最终平均收益: %.4f, 最终平均积压长度: %.2f\n', ...
            time_series_revenue(alg_idx, end), time_series_backlog(alg_idx, end));
end

% 绘制第一组图：MEC时间平均收益
figure;
time_slots = 1:totalTimeSlots;

for alg_idx = 1:num_algorithms
    plot(time_slots, time_series_revenue(alg_idx, :), ...
         'DisplayName', algorithm_names{alg_idx}, ...
         'LineStyle', lineStyles{alg_idx}, ...
         'LineWidth', lineWidth, ...
         'Marker', markers{alg_idx}, ...
         'MarkerIndices', 1:50:totalTimeSlots);  % 每50个点显示一个标记
    hold on;
end

xlabel('时隙');
ylabel('MEC时间平均收益');
title('不同调度算法的MEC时间平均收益对比');
legend('show', 'Location', 'best');
grid on;
hold off;

% 保存第一组第一个图
% saveas(gcf, sprintf('plot2_group1_revenue_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 绘制第一组图：任务积压队列的平均长度
figure;

for alg_idx = 1:num_algorithms
    plot(time_slots, time_series_backlog(alg_idx, :), ...
         'DisplayName', algorithm_names{alg_idx}, ...
         'LineStyle', lineStyles{alg_idx}, ...
         'LineWidth', lineWidth, ...
         'Marker', markers{alg_idx}, ...
         'MarkerIndices', 1:50:totalTimeSlots);  % 每50个点显示一个标记
    hold on;
end

xlabel('时隙');
ylabel('任务积压队列的平均长度');
title('不同调度算法的任务积压队列平均长度对比');
legend('show', 'Location', 'best');
grid on;
hold off;

% 保存第一组第二个图
% saveas(gcf, sprintf('plot2_group1_backlog_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 保存第一组数据
results_table = table();
results_table.TimeSlot = time_slots';
for alg_idx = 1:num_algorithms
    var_name_revenue = sprintf('Revenue_%s', strrep(algorithm_names{alg_idx}, '+', '_'));
    var_name_backlog = sprintf('Backlog_%s', strrep(algorithm_names{alg_idx}, '+', '_'));
    var_name_revenue = strrep(var_name_revenue, '调度', '');
    var_name_backlog = strrep(var_name_backlog, '调度', '');
    results_table.(var_name_revenue) = time_series_revenue(alg_idx, :)';
    results_table.(var_name_backlog) = time_series_backlog(alg_idx, :)';
end

% filename = sprintf('plot2_group1_scheduling_results_%s.csv', datestr(now, 'yyyymmdd_HHMMSS'));
% writetable(results_table, filename);
% fprintf('第一组结果已保存到文件: %s\n', filename);

end

function plot_cache_algorithms_comparison()
% 第二组：K=20, N=20, VV=1
% 横坐标为时隙（0——Tsolt），纵坐标分别为当前时隙MEC的时间平均收益、任务积压队列的平均长度、MEC缓存的任务类型总价值
% 图例为：调度算法使用LyapunovSchedule=3 + 五种不同的缓存更新算法（FIFO、LRU、LFU、Priority、Knapsack）

% 实验参数设置
totalTimeSlots = 500;      % 仿真时隙数
constants.K(40);           % 任务类型数量
constants.N(20);           % 每时隙生成任务数
vv_parameter = 1.0;        % 李雅普诺夫参数VV=1

% 缓存算法设置
cache_algorithms = [
    constants.FIFO,...
    constants.LRU,...
    constants.LFU,...
    constants.Priority,...
    constants.Knapsack
];

cache_names = {
    'FIFO缓存',...
    'LRU缓存',...
    'LFU缓存',...
    'Priority缓存',...
    'Knapsack缓存'
};

% 定义线型和标记符号
lineStyles = {'-', '-.', '--', ':', '-'};
markers = {'+', 'o', '*', 'x', 's'};
lineWidth = 1.4;

num_cache_algs = length(cache_algorithms);

% 存储每个缓存算法的时序数据
cache_time_series_revenue = zeros(num_cache_algs, totalTimeSlots);
cache_time_series_backlog = zeros(num_cache_algs, totalTimeSlots);
cache_time_series_value = zeros(num_cache_algs, totalTimeSlots);

% 运行仿真实验
for cache_idx = 1:num_cache_algs
    cache_alg = cache_algorithms(cache_idx);
    cache_name = cache_names{cache_idx};
    
    fprintf('正在测试缓存算法: %s (%d/%d)...\n', cache_name, cache_idx, num_cache_algs);
    
    % 创建仿真器
    sim = Simulator(totalTimeSlots);
    
    % 设置调度策略为李雅普诺夫调度，VV=1
    sim.setScheduleStrategy(constants.LyapunovSchedule, vv_parameter);
    
    % 设置缓存策略
    sim.setCacheStrategy(cache_alg);
    
    % 运行仿真并记录每个时隙的数据
    sim.MEC.updateTimeSlot(0);
    
    for t = 0:(totalTimeSlots-1)
        sim.CurrentTimeSlot = t;
        sim.runTimeSlot();
        
        % 记录当前时隙的数据
        cache_time_series_revenue(cache_idx, t+1) = sim.Statistics.AverageRevenue;
        
        % 计算积压队列平均长度
        total_backlog = 0;
        K = constants.K();
        for k = 1:K
            total_backlog = total_backlog + sim.TaskManager.getBacklogCount(k);
        end
        cache_time_series_backlog(cache_idx, t+1) = total_backlog / K;
        
        % 计算缓存总价值
        cache_time_series_value(cache_idx, t+1) = sim.MEC.getCacheTotalValue(sim.TaskManager);
    end
    
    fprintf('完成，最终平均收益: %.4f, 最终平均积压长度: %.2f, 最终缓存价值: %.2f\n', ...
            cache_time_series_revenue(cache_idx, end), ...
            cache_time_series_backlog(cache_idx, end), ...
            cache_time_series_value(cache_idx, end));
end

% 绘制第二组图：MEC时间平均收益
figure;
time_slots = 1:totalTimeSlots;

for cache_idx = 1:num_cache_algs
    plot(time_slots, cache_time_series_revenue(cache_idx, :), ...
         'DisplayName', cache_names{cache_idx}, ...
         'LineStyle', lineStyles{cache_idx}, ...
         'LineWidth', lineWidth, ...
         'Marker', markers{cache_idx}, ...
         'MarkerIndices', 1:50:totalTimeSlots);  % 每50个点显示一个标记
    hold on;
end

xlabel('时隙');
ylabel('MEC时间平均收益');
title('不同缓存算法的MEC时间平均收益对比 (李雅普诺夫调度, VV=1)');
legend('show', 'Location', 'best');
grid on;
hold off;

% 保存第二组第一个图
% saveas(gcf, sprintf('plot2_group2_revenue_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 绘制第二组图：任务积压队列的平均长度
figure;

for cache_idx = 1:num_cache_algs
    plot(time_slots, cache_time_series_backlog(cache_idx, :), ...
         'DisplayName', cache_names{cache_idx}, ...
         'LineStyle', lineStyles{cache_idx}, ...
         'LineWidth', lineWidth, ...
         'Marker', markers{cache_idx}, ...
         'MarkerIndices', 1:50:totalTimeSlots);  % 每50个点显示一个标记
    hold on;
end

xlabel('时隙');
ylabel('任务积压队列的平均长度');
title('不同缓存算法的任务积压队列平均长度对比 (李雅普诺夫调度, VV=1)');
legend('show', 'Location', 'best');
grid on;
hold off;

% 保存第二组第二个图
% saveas(gcf, sprintf('plot2_group2_backlog_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 绘制第二组图：MEC缓存的任务类型总价值
figure;

for cache_idx = 1:num_cache_algs
    plot(time_slots, cache_time_series_value(cache_idx, :), ...
         'DisplayName', cache_names{cache_idx}, ...
         'LineStyle', lineStyles{cache_idx}, ...
         'LineWidth', lineWidth, ...
         'Marker', markers{cache_idx}, ...
         'MarkerIndices', 1:50:totalTimeSlots);  % 每50个点显示一个标记
    hold on;
end

xlabel('时隙');
ylabel('MEC缓存的任务类型总价值');
title('不同缓存算法的缓存总价值对比 (李雅普诺夫调度, VV=1)');
legend('show', 'Location', 'best');
grid on;
hold off;

% 保存第二组第三个图
% saveas(gcf, sprintf('plot2_group2_cache_value_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 保存第二组数据
results_table2 = table();
results_table2.TimeSlot = time_slots';
for cache_idx = 1:num_cache_algs
    var_name_revenue = sprintf('Revenue_%s', strrep(cache_names{cache_idx}, '缓存', ''));
    var_name_backlog = sprintf('Backlog_%s', strrep(cache_names{cache_idx}, '缓存', ''));
    var_name_value = sprintf('CacheValue_%s', strrep(cache_names{cache_idx}, '缓存', ''));
    results_table2.(var_name_revenue) = cache_time_series_revenue(cache_idx, :)';
    results_table2.(var_name_backlog) = cache_time_series_backlog(cache_idx, :)';
    results_table2.(var_name_value) = cache_time_series_value(cache_idx, :)';
end

% filename2 = sprintf('plot2_group2_cache_results_%s.csv', datestr(now, 'yyyymmdd_HHMMSS'));
% writetable(results_table2, filename2);
% fprintf('第二组结果已保存到文件: %s\n', filename2);

end