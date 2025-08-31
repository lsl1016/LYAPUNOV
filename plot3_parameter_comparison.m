function plot3_parameter_comparison()
% plot3_parameter_comparison.m - 不同参数下的性能对比柱状图
% 
% 包含两组独立的柱状图：
% 第一组：不同任务类型数量K的性能对比（N=10, totalCacheSize=2000）
% 第二组：不同任务生成数量N的性能对比（K=15, totalCacheSize=2000）

clc;close all;clear;

fprintf('=== 开始参数对比实验 ===\n');

% 第一组实验：不同任务类型数量K的对比
fprintf('\n--- 第一组：不同任务类型数量K的对比 ---\n');
plot_different_k_comparison();

% 第二组实验：不同任务生成数量N的对比
fprintf('\n--- 第二组：不同任务生成数量N的对比 ---\n');
plot_different_n_comparison();

fprintf('=== 参数对比实验完成 ===\n');

end

function plot_different_k_comparison()
% 第一组：
% 横坐标取不同的任务类型 k= [40,50,60,70,80], 单时隙的产生任务数量 N=20，totalCacheSize(1000)
% 纵坐标分别为（所有时隙的） MEC的时间平均收益（总收入/总时隙）、任务积压队列的平均长度（所有任务类型的总积压长度/总时隙）
% 图例为：四种调度算法 + 缓存更新算法使用 Knapsack

% 实验参数设置
k_values = [40,50,60,70,80];
fixed_n = 20;                      % 固定N=10
totalTimeSlots = 500;              % 仿真时隙数
constants.totalCacheSize(1000);    % 设置缓存大小为2000

% 调度算法设置
scheduling_algorithms = [
    constants.GreedySchedule,...
    constants.ShortTermSchedule,...
    constants.LyapunovSchedule,...
    constants.NoCacheSchedule
];

algorithm_names = {
    '贪心调度',...
    '短期调度',...
    '李雅普诺夫调度',...
    '无缓存调度'
};

num_k = length(k_values);
num_algorithms = length(scheduling_algorithms);

% 存储结果
results_revenue = zeros(num_algorithms, num_k);
results_backlog = zeros(num_algorithms, num_k);

% 运行仿真实验
for k_idx = 1:num_k
    current_k = k_values(k_idx);
    constants.K(current_k);        % 设置任务类型数量
    constants.N(fixed_n);          % 设置每时隙生成任务数
    
    fprintf('正在测试K=%d (%d/%d)...\n', current_k, k_idx, num_k);
    
    for alg_idx = 1:num_algorithms
        algorithm = scheduling_algorithms(alg_idx);
        alg_name = algorithm_names{alg_idx};
        
        fprintf('  调度算法: %s (%d/%d)\n', alg_name, alg_idx, num_algorithms);
        
        % 创建仿真器
        sim = Simulator(totalTimeSlots);
        
        % 设置调度策略
        sim.setScheduleStrategy(algorithm, constants.VV_DEFAULT);
        
        % 设置缓存策略（无缓存调度除外）
        if algorithm ~= constants.NoCacheSchedule
            sim.setCacheStrategy(constants.Knapsack);
        else
            sim.MEC.setCacheEnabled(false);
        end
        
        % 运行仿真（静默模式）
        try
            evalc('sim.runSimulation()');
        catch ME
            fprintf('    仿真过程中出错: %s\n', ME.message);
            continue;
        end
        
        % 获取统计结果
        stats = sim.getStatistics();
        results_revenue(alg_idx, k_idx) = stats.AverageRevenue;
        results_backlog(alg_idx, k_idx) = stats.AverageBacklogQueueLength;
        
        fprintf('    完成，平均收益: %.4f, 平均积压长度: %.2f\n', ...
                results_revenue(alg_idx, k_idx), results_backlog(alg_idx, k_idx));
    end
end

% 绘制第一组柱状图：MEC时间平均收益
figure;
bar_data_revenue = results_revenue';
bar(k_values, bar_data_revenue);

xlabel('任务类型数量 K');
ylabel('MEC时间平均收益');
title(sprintf('不同任务类型数量K下的MEC时间平均收益对比 (N=%d, 缓存=%dMbit)', fixed_n, constants.totalCacheSize()));
legend(algorithm_names, 'Location', 'best');
grid on;

% 保存第一组第一个图
% saveas(gcf, sprintf('plot3_group1_k_revenue_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 绘制第一组柱状图：任务积压队列的平均长度
figure;
bar_data_backlog = results_backlog';
bar(k_values, bar_data_backlog);

xlabel('任务类型数量 K');
ylabel('任务积压队列的平均长度');
title(sprintf('不同任务类型数量K下的任务积压队列平均长度对比 (N=%d, 缓存=%dMbit)', fixed_n, constants.totalCacheSize()));
legend(algorithm_names, 'Location', 'best');
grid on;

% 保存第一组第二个图
% saveas(gcf, sprintf('plot3_group1_k_backlog_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 保存第一组数据
results_table1 = table();
results_table1.K_Values = k_values';
for alg_idx = 1:num_algorithms
    var_name_revenue = sprintf('Revenue_%s', strrep(algorithm_names{alg_idx}, '调度', ''));
    var_name_backlog = sprintf('Backlog_%s', strrep(algorithm_names{alg_idx}, '调度', ''));
    results_table1.(var_name_revenue) = results_revenue(alg_idx, :)';
    results_table1.(var_name_backlog) = results_backlog(alg_idx, :)';
end

% filename1 = sprintf('plot3_group1_k_comparison_%s.csv', datestr(now, 'yyyymmdd_HHMMSS'));
% writetable(results_table1, filename1);
% fprintf('第一组结果已保存到文件: %s\n', filename1);

end

function plot_different_n_comparison()
% 第二组：
% 横坐标取单时隙产生的不同任务数量 N= [10,20,30,40,50], 任务类型数量 K固定为 40 ，totalCacheSize(1000)
% 纵坐标分别为（所有时隙的） MEC的时间平均收益（总收入/总时隙）、任务积压队列的平均长度（所有任务类型的总积压长度/总时隙）
% 图例为：四种调度算法 + 缓存更新算法使用 Knapsack

% 实验参数设置
n_values = [10, 20, 30, 40, 50];
fixed_k = 40;                      
totalTimeSlots = 500;              
constants.totalCacheSize(1000);    

% 调度算法设置
scheduling_algorithms = [
    constants.GreedySchedule,...
    constants.ShortTermSchedule,...
    constants.LyapunovSchedule,...
    constants.NoCacheSchedule
];

algorithm_names = {
    '贪心调度',...
    '短期调度',...
    '李雅普诺夫调度',...
    '无缓存调度'
};

num_n = length(n_values);
num_algorithms = length(scheduling_algorithms);

% 存储结果
results_revenue = zeros(num_algorithms, num_n);
results_backlog = zeros(num_algorithms, num_n);

% 运行仿真实验
for n_idx = 1:num_n
    current_n = n_values(n_idx);
    constants.K(fixed_k);          % 设置任务类型数量
    constants.N(current_n);        % 设置每时隙生成任务数
    
    fprintf('正在测试N=%d (%d/%d)...\n', current_n, n_idx, num_n);
    
    for alg_idx = 1:num_algorithms
        algorithm = scheduling_algorithms(alg_idx);
        alg_name = algorithm_names{alg_idx};
        
        fprintf('  调度算法: %s (%d/%d)\n', alg_name, alg_idx, num_algorithms);
        
        % 创建仿真器
        sim = Simulator(totalTimeSlots);
        
        % 设置调度策略
        sim.setScheduleStrategy(algorithm, constants.VV_DEFAULT);
        
        % 设置缓存策略（无缓存调度除外）
        if algorithm ~= constants.NoCacheSchedule
            sim.setCacheStrategy(constants.Knapsack);
        else
            sim.MEC.setCacheEnabled(false);
        end
        
        % 运行仿真（静默模式）
        try
            evalc('sim.runSimulation()');
        catch ME
            fprintf('    仿真过程中出错: %s\n', ME.message);
            continue;
        end
        
        % 获取统计结果
        stats = sim.getStatistics();
        results_revenue(alg_idx, n_idx) = stats.AverageRevenue;
        results_backlog(alg_idx, n_idx) = stats.AverageBacklogQueueLength;
        
        fprintf('    完成，平均收益: %.4f, 平均积压长度: %.2f\n', ...
                results_revenue(alg_idx, n_idx), results_backlog(alg_idx, n_idx));
    end
end

% 绘制第二组柱状图：MEC时间平均收益
figure;
bar_data_revenue = results_revenue';
bar(n_values, bar_data_revenue);

xlabel('每时隙生成任务数量 N');
ylabel('MEC时间平均收益');
title(sprintf('不同任务生成数量N下的MEC时间平均收益对比 (K=%d, 缓存=%dMbit)', fixed_k, constants.totalCacheSize()));
legend(algorithm_names, 'Location', 'best');
grid on;

% 保存第二组第一个图
% saveas(gcf, sprintf('plot3_group2_n_revenue_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 绘制第二组柱状图：任务积压队列的平均长度
figure;
bar_data_backlog = results_backlog';
bar(n_values, bar_data_backlog);

xlabel('每时隙生成任务数量 N');
ylabel('任务积压队列的平均长度');
title(sprintf('不同任务生成数量N下的任务积压队列平均长度对比 (K=%d, 缓存=%dMbit)', fixed_k, constants.totalCacheSize()));
legend(algorithm_names, 'Location', 'best');
grid on;

% 保存第二组第二个图
% saveas(gcf, sprintf('plot3_group2_n_backlog_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));

% 保存第二组数据
results_table2 = table();
results_table2.N_Values = n_values';
for alg_idx = 1:num_algorithms
    var_name_revenue = sprintf('Revenue_%s', strrep(algorithm_names{alg_idx}, '调度', ''));
    var_name_backlog = sprintf('Backlog_%s', strrep(algorithm_names{alg_idx}, '调度', ''));
    results_table2.(var_name_revenue) = results_revenue(alg_idx, :)';
    results_table2.(var_name_backlog) = results_backlog(alg_idx, :)';
end

% filename2 = sprintf('plot3_group2_n_comparison_%s.csv', datestr(now, 'yyyymmdd_HHMMSS'));
% writetable(results_table2, filename2);
% fprintf('第二组结果已保存到文件: %s\n', filename2);

end