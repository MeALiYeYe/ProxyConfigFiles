# 📦 Rule Pipeline（自动规则构建系统）

本项目提供一套完整的规则构建流水线：

> 引入 → 展开 → 归一化 → 去重 → 分类 → 多平台输出 → MRS → Providers

---

# 🚀 功能

- 模块化规则管理（支持 include）
- 自动去重 / 排序 / 合并
- IP CIDR 聚合优化
- 多平台输出（Mihomo / QX / Egern）
- 自动生成 rule-providers

---

# 📂 目录结构

rules/                  # 原始规则
tmp/normalized/         # 中间产物
Mihomo/rule/            # Mihomo 输出
Quantumult X/rule/      # QX 输出
Egern/rule/             # Egern 输出

---

# 🔁 引入语法

推荐：
#!include: local.list
#!source: https://example.com/rules.list

简洁：
@local.list
@https://example.com/rules.list

---

# 🔧 Normalize

- 支持文本规则
- 支持 YAML（Clash / Mihomo）
- 自动转换 / 去重

---

# 🌐 IP 优化

自动 CIDR 聚合

---

# 🧱 输出

- Mihomo（YAML + MRS）
- Quantumult X
- Egern

---

# ⚡ 自动化

- push rules/** 自动触发
- 每日定时更新

---

# 🧠 说明

本项目是一个规则编译系统。
