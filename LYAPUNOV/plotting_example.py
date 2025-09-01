"""
绘图模块使用示例
演示如何使用转换后的Python绘图功能
"""

from .plotting import PlottingModule


def example_usage():
    """绘图模块使用示例"""
    print('=== MEC系统仿真绘图模块使用示例 ===\n')
    
    # 创建绘图模块实例
    plotting = PlottingModule()
    
    print('可用的绘图功能：')
    print('1. plot1 - 李雅普诺夫参数VV优化折线图')
    print('2. plot2 - 时序性能对比折线图')
    print('3. plot3 - 参数对比柱状图')
    print('4. plot4 - 缓存策略性能对比柱状图')
    print('5. run_all_plots - 运行所有绘图实验\n')
    
    # 示例1：运行单个绘图实验
    print('示例1：运行李雅普诺夫参数优化实验')
    print('# result = plotting.run_plot1()')
    print('# print(f"最优VV参数: {result[\'optimal_vv\']}")\n')
    
    # 示例2：运行时序对比实验
    print('示例2：运行时序性能对比实验')
    print('# plotting.run_plot2()\n')
    
    # 示例3：运行参数对比实验
    print('示例3：运行参数对比实验')
    print('# plotting.run_plot3()\n')
    
    # 示例4：运行缓存策略对比实验
    print('示例4：运行缓存策略对比实验')
    print('# plotting.run_plot4()\n')
    
    # 示例5：运行所有实验
    print('示例5：运行所有绘图实验')
    print('# plotting.run_all_plots()\n')
    
    print('注意：实际运行时请取消注释相应的代码行')
    print('每个实验都会生成相应的图表，请确保安装了matplotlib')


if __name__ == "__main__":
    example_usage()
