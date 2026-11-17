# 渝创界小助手 macOS 构建资料

此目录包含构建输入与云端流水线，**不是 DMG**。已按用户要求上传到公开仓库 `ordinarykai/yuchuangjie`。

当前云构建将源快照版本覆盖为 `1.0.10`，避免与发布中心已有 Windows `stable/1.0.9` 的唯一版本记录冲突。`manifest.json` 记录的 `1.0.8` 是原始输入快照版本；最终应用版本由工作流的 `APP_RELEASE_VERSION` 决定。两种架构的输出名分别包含 `arm64` 与 `x86_64`。

代码及 Cut 前端使用当前工作区快照；未包含 `.env*`、私钥、签名证书、本机用户配置和 Windows 运行时。平台 `https://cqsaigc.com/`，业务 API `https://cqsaigc.com/backend/atai-video-business-platform`，Cut `https://cqsaigc.com/cut/`。包含新品牌文案、用户提供的蓝色 Logo 和已核对的依赖裁剪规则。源码相关 fixture 测试 31 项通过，未执行实际安装或渲染验收。

## 无 Mac：使用 GitHub Actions

1. 本次仓库为用户指定的 `https://github.com/ordinarykai/yuchuangjie`。根目录需要全部 `assistant-source.part-*` 分片和隐藏的 `.github/workflows/build-macos.yml`；脚本会自动合并分片。
2. 在 Actions 页面手动运行 `Build Yuchuangjie macOS internal installers`。
3. 两个任务分别在 `macos-15`（Apple Silicon）和 `macos-15-intel`（Intel）运行；生成 DMG 后，保存到 Actions artifact 和 GitHub 草稿发布，供后续转传后台。
4. 默认 CI 流程仅生成临时签名、未公证的内部测试包。不能将其登记为受信任 Developer ID 签名或已公证，也不能启用正式自动更新。
5. 云端向国内后台上传经测试速度不足，当前构建流程已移除业务后台 Secret，临时 `ATAI_MACOS_UPLOAD_TOKEN` 已删除。`upload-to-backend.py` 保留为独立工具，但没有在当前工作流执行。
6. 下载真实 DMG 后，通过后台文件上传与登记接口保存制品，再在同一发布记录中设置 `platform=macos`、`architecture=arm64/x64`。仅 arm64 为网页默认，Intel 进入历史列表；保持 `signatureVerified=false`、`notarized=false`、`autoUpdateEnabled=false`。先保存草稿、补齐两个架构，再发布。Windows 推荐版本保持独立。

本次没有配置支付或 Apple 签名凭据。`stage-macos-download.yml` 是旧 `1.0.9` 构建的下载中转，`probe-backend-transfer.yml` 是已完成的链路诊断；两者均非业务发布入口。业务发布以 cqsaigc.com 后台记录为准。

## 已有 macOS 主机

需要 Python 3.11、Node 24/npm、Xcode Command Line Tools 和可访问依赖下载源。解压后执行：

```bash
# 内部测试：临时签名，无 Apple 公证
APP_RELEASE_VERSION=1.0.10 MACOS_RELEASE_MODE=internal bash build-on-mac.command

# 正式分发：先安装 Developer ID 证书并配置公证凭据
CODESIGN_IDENTITY='Developer ID Application: Your Company (TEAMID)' \
NOTARYTOOL_PROFILE='your-notary-profile' \
MACOS_RELEASE_MODE=signed bash build-on-mac.command
```

输出位于 `output/arm64/` 或 `output/x86_64/`。当前引擎不能用一个 Node 可执行文件构建 universal2 包，所以两种架构分别生成。构建会在新建的临时工作区执行，原始源码快照保持不变；没有修改本机已安装的小助手。

正式签名需要将 Developer ID 私钥及 Apple 公证凭据安全配置到 macOS 构建机；它们没有包含在此资料中。CI 签名证书导入及公证凭据配置尚未接入。
