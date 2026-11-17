# 渝创界小助手 macOS 构建资料

此目录包含构建输入，**不是 DMG，也尚未构建或发布**。

代码及 Cut 前端使用当前工作区快照；未包含 `.env*`、私钥、签名证书、本机用户配置和 Windows 运行时。平台 `https://cqsaigc.com/`，业务 API `https://cqsaigc.com/backend/atai-video-business-platform`，Cut `https://cqsaigc.com/cut/`。包含新品牌文案、用户提供的蓝色 Logo 和已核对的依赖裁剪规则。源码相关 fixture 测试 31 项通过，未执行实际安装或渲染验收。

## 无 Mac：使用 GitHub Actions

1. 准备一个有 Actions 使用额度的 **私有 GitHub 仓库**。上传此目录的内容至仓库根目录，包括全部 `assistant-source.part-*` 分片和隐藏的 `.github/workflows/build-macos.yml`。源代码已拆为不超过 20 MiB 的分片，构建脚本会自动合并。不要把商业源码放进公开仓库；当前资料尚未上传到任何新服务。
2. 在 Actions 页面手动运行 `Build Yuchuangjie macOS internal installers`。
3. 两个任务分别在 `macos-15`（Apple Silicon）和 `macos-15-intel`（Intel）运行，完成后下载对应架构 artifact。
4. 默认 CI 流程仅生成临时签名、未公证的内部测试包。不能将其登记为受信任 Developer ID 签名或已公证，也不能启用正式自动更新。
5. 构建成功后再将真实 DMG 上传 cqsaigc.com 发布中心，配置 `platform=macos`、真实架构、DMG 格式与真实签名/公证状态。Windows 推荐版本保持独立。

GitHub 的私有仓库 macOS 运行器消耗账户额度，超出部分可能计费。此工作流没有配置支付、创建仓库或触发云构建；接入账户后才能运行。

## 已有 macOS 主机

需要 Python 3.11、Node 24/npm、Xcode Command Line Tools 和可访问依赖下载源。解压后执行：

```bash
# 内部测试：临时签名，无 Apple 公证
MACOS_RELEASE_MODE=internal bash build-on-mac.command

# 正式分发：先安装 Developer ID 证书并配置公证凭据
CODESIGN_IDENTITY='Developer ID Application: Your Company (TEAMID)' \
NOTARYTOOL_PROFILE='your-notary-profile' \
MACOS_RELEASE_MODE=signed bash build-on-mac.command
```

输出位于 `output/arm64/` 或 `output/x86_64/`。当前引擎不能用一个 Node 可执行文件构建 universal2 包，所以两种架构分别生成。构建会在新建的临时工作区执行，原始源码快照保持不变；没有修改本机已安装的小助手。

正式签名需要将 Developer ID 私钥及 Apple 公证凭据安全配置到 macOS 构建机；它们没有包含在此资料中。CI 签名证书导入及公证凭据配置尚未接入。
