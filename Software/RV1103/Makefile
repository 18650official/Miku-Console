# ==========================================
# 顶层自动化构建管理 Makefile
# ==========================================

# 定义默认伪目标
.PHONY: all build clean appclean sysclean help

# 默认执行 make 时运行完整构建脚本
all: build

# 运行完整构建流程
build:
	@echo ">>> [BUILD] 开始运行自动化构建脚本..."
	@bash ./auto_build_rv1103.sh

# 运行基础清理脚本
clean:
	@echo ">>> [CLEAN] 运行基础清理脚本..."
	@bash ./clean.sh

# 运行用户应用/工具链清理脚本
appclean:
	@echo ">>> [APPCLEAN] 运行应用组件清理脚本..."
	@bash ./app_clean.sh

# 运行系统级/SDK深度清理脚本
sysclean:
	@echo ">>> [SYSCLEAN] 运行系统底层深度清理脚本..."
	@bash ./sys_clean.sh

# 显示帮助信息（带 ANSI 颜色）
help:
	@echo ""
	@echo "\033[1;36mMiku Console 自动化构建与清理指令集:\033[0m"
	@echo "-------------------------------------------------------"
	@echo "  \033[1;32mmake\033[0m 或 \033[1;32mmake build\033[0m   - 执行 ./auto_build_rv1103.sh，从零构建系统镜像与用户程序"
	@echo "  \033[1;33mmake clean\033[0m        - 执行 ./clean.sh，清理常规编译产物"
	@echo "  \033[1;33mmake appclean\033[0m     - 执行 ./app_clean.sh，仅清理第三方库与用户应用程序"
	@echo "  \033[1;31mmake sysclean\033[0m     - 执行 ./sys_clean.sh，深度清理 SDK 及系统镜像中间件"
	@echo "  \033[1;35mmake help\033[0m         - 显示当前帮助提示"
	@echo "-------------------------------------------------------"
	@echo ""