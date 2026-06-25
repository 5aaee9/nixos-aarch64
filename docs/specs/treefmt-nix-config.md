# treefmt-nix 配置

## 背景

仓库当前使用 `nixpkgs-fmt`，通过 `lefthook` 的 pre-commit 与 fixer 钩子调用（见
`lefthook.yml`），并在 devenv shell 中提供 `nixpkgs-fmt` 包。最近一次提交
`919f279 "feat: format tree"` 刚用 `nixpkgs-fmt` 重新格式化了所有 `.nix` 文件。

目标：引入 [treefmt-nix](https://github.com/numtide/treefmt-nix) 作为格式化规则的
**唯一来源**，并通过 flake-parts 集成；lefthook 改为调用带配置的 treefmt，不再直接
调用 `nixpkgs-fmt`。

## 决策

### 集成方式

treefmt-nix 的 `flakeModule` 负责所有格式化规则；lefthook 的 pre-commit / fixer
调用 treefmt。格式规则单一来源，避免重复配置。flakeModule 同时自动暴露：

- `formatter` —— 支持 `nix fmt` 一键格式化
- `checks.treefmt` —— 支持 `nix flake check` / CI 校验

### 格式化器选择

- 启用 `programs.nixfmt`（`enable = true`），其底层使用 `pkgs.nixfmt`，即 **RFC 166
  官方** Nix 格式化器。
- 设置 `strict = true`，输出规范化、不受输入风格影响。
- **不**启用 prettier / yamlfmt 等其它格式化器，避免对 `README.md`、`AGENTS.md`、
  `.github/workflows/*.yml`、`lefthook.yml` 产生额外改动噪声；如后续有需要可再加。

### 影响范围

nixfmt 只匹配 `*.nix`，因此以下文件均不会被触碰：`flake.lock`、`*.json`、
`*.jsonl`、`*.patch`、`*.dtbo`。

### ⚠️ 重新格式化

由于 RFC 166 nixfmt 与 `nixpkgs-fmt` 风格不同，切换后会对现有 `.nix` 文件产生一次
较大的重新格式化 diff。这是预期内的。

## 改动清单

### `flake.nix`

1. 新增 input：
   ```nix
   treefmt-nix = {
     url = "github:numtide/treefmt-nix";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```
2. `imports` 加入 `inputs.treefmt-nix.flakeModule`。
3. `perSystem` 增加 treefmt 配置块：
   ```nix
   treefmt = {
     projectRootFile = "flake.nix";
     programs.nixfmt = {
       enable = true;
       strict = true;
     };
   };
   ```
4. devenv `packages` 中移除 `nixpkgs-fmt`，加入 treefmt 包装器（`config.treefmt.build.wrapper`，
   flakeModule 未暴露 `packages.treefmt`），使 lefthook 能调用到带配置的 treefmt。

### `lefthook.yml`

```yaml
pre-commit:
  parallel: true
  commands:
    treefmt:
      run: treefmt --fail-on-change {staged_files}

fixer:
  commands:
    treefmt:
      run: treefmt --no-cache {staged_files}
```

## 验证

- `nix fmt` 能格式化整个仓库的 `.nix` 文件
- `nix flake check` 中 `treefmt` 检查通过
- `lefthook run pre-commit` / `lefthook run fixer` 正常工作
