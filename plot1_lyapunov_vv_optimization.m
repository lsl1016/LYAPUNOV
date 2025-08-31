function plot1_lyapunov_vv_optimization()
% plot1_lyapunov_vv_optimization.m - 李雅普诺夫漂移参数VV优化折线图
% 
% 目的：寻找合适的李雅普诺夫漂移参数VV
% 参数设置：K=20, N=20, 调度算法使用LyapunovSchedule=3, 缓存算法使用Knapsack=5
% 横坐标：VV（李雅普诺夫漂移参数）
% 纵坐标：MEC的时间平均收益
clc;close all;clear;

fprintf('=== 开始李雅普诺夫参数VV优化实验 ===\n');

% 实验参数设置
constants.K(20);           % 设置任务类型数量为20
constants.N(20);           % 设置每时隙生成任务数为20
totalTimeSlots = 1000;     % 仿真时隙数

% VV参数范围设置
vv_range = [0.5, 1.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 15.0, 20.0];
num_vv = length(vv_range);

% 存储结果
average_revenues = zeros(1, num_vv);

% 对每个VV值进行仿真
for i = 1:num_vv
    current_vv = vv_range(i);
    fprintf('正在测试VV = %.1f (%d/%d)...\n', current_vv, i, num_vv);
    
    % 创建仿真器
    sim = Simulator(totalTimeSlots);
    
    % 设置调度策略为李雅普诺夫调度，缓存策略为背包算法
    sim.setScheduleStrategy(constants.LyapunovSchedule, current_vv);
    sim.setCacheStrategy(constants.Knapsack);
    
    % 运行仿真（静默模式，不输出进度）
    try
        % 临时重定向输出
        evalc('sim.runSimulation()');
    catch ME
        fprintf('仿真过程中出错: %s\n', ME.message);
        continue;
    end
    
    % 获取统计结果
    stats = sim.getStatistics();
    average_revenues(i) = stats.AverageRevenue;
    
    fprintf('VV = %.1f, 时间平均收益 = %.4f\n', current_vv, average_revenues(i));
end

% 绘制折线图
figure;

% 定义线型和标记符号（参考绘图样式模板）
lineStyles = {'-'};         % 线型
markers = {'o'};            % 标记符号
lineWidth = 1.4;            % 线条宽度

% 绘制折线图
plot(vv_range, average_revenues, ...
     'DisplayName', 'MEC时间平均收益', ...
     'LineStyle', lineStyles{1}, ...
     'LineWidth', lineWidth, ...
     'Marker', markers{1}, ...
     'MarkerSize', 6, ...
     'MarkerFaceColor', 'auto');

% 图形设置
xlabel('李雅普诺夫漂移参数 VV');
ylabel('MEC时间平均收益');
title('李雅普诺夫漂移参数VV对系统性能的影响');
grid on;
legend show;

% 找出最优VV值
[max_revenue, max_idx] = max(average_revenues);
optimal_vv = vv_range(max_idx);

% 在图上标注最优点
hold on;
plot(optimal_vv, max_revenue, 'r*', 'MarkerSize', 12, 'LineWidth', 2);
text(optimal_vv, max_revenue + max_revenue*0.05, ...
     sprintf('最优VV = %.1f\n收益 = %.4f', optimal_vv, max_revenue), ...
     'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', 'red');
hold off;

% 输出结果摘要
fprintf('\n=== VV优化实验结果摘要 ===\n');
fprintf('测试的VV范围: [%.1f, %.1f]\n', min(vv_range), max(vv_range));
fprintf('最优VV值: %.1f\n', optimal_vv);
fprintf('最优收益: %.4f\n', max_revenue);
fprintf('收益提升: %.2f%%\n', (max_revenue - min(average_revenues)) / min(average_revenues) * 100);

% 保存结果数据
results_table = table(vv_range', average_revenues', ...
    'VariableNames', {'VV_Parameter', 'Average_Revenue'});

% 保存到CSV文件
filename = sprintf('vv_optimization_results_%s.csv', datestr(now, 'yyyymmdd_HHMMSS'));
% writetable(results_table, filename);
% fprintf('结果已保存到文件: %s\n', filename);

% 保存图形
% saveas(gcf, sprintf('plot1_vv_optimization_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));
% fprintf('图形已保存\n');

fprintf('=== VV优化实验完成 ===\n');

end