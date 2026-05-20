# 📦 Rule Pipeline（自动规则构建系统）

本项目提供一套完整的规则构建流水线：

> 引入 → 展开 → 归一 → 去重 → 分类 → 多平台输出 → MRS → Providers

---

# 🚀 功能

- 模块化规则管理（支持 include）
- 自动去重 / 排序 / 合并
- IP CIDR 聚合优化
- 多平台输出（Mihomo / QX / Egern / Surge）
- 自动生成 rule-providers

---

# 📂 目录结构

```
rules/                  # 原始规则
tmp/normalized/         # 中间产物
Mihomo/rule/            # Mihomo 输出
Quantumult X/rule/      # QX 输出
Egern/rule/             # Egern 输出
Surge/rule/             # Surge 输出
```

---

# 🔁 引入语法

推荐：
#!include: local.list

#!source: https://example.com/rules.list

简洁：
@local.list

@https://example.com/rules.list

## 📁 文件名合并规则（@ 分组机制）

在子目录中，可以使用如下文件命名方式：

```
Direct@ex1.list
Direct@ex2.list
Proxy@streaming.list
```

系统会自动按 @ 前缀进行合并：

```
Direct@ex1.list + Direct@ex2.list → Direct.list
Proxy@streaming.list → Proxy.list
```

- 自动合并同名前缀规则
- 便于拆分维护大规则集
- 不影响目录结构

### 💡 示例

```
rules/
  direct/
    Direct@base.list
    Direct@cn.list
```

生成：

```
Direct.list
```

⚠️ @ 仅用于文件名分组，不影响 include 语法

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
- Surge

---

# ⚡ 自动化

- push rules/** 自动触发
- 每日定时更新

---

# 🧠 说明

本项目是一个规则编译系统。
