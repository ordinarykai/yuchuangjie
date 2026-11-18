# macOS 原生构建输入

此目录由小助手源码中的 `packaging/prepare_macos_build.py` 生成。`manifest.json`
固定版本、源码归档、当前助手 UI 及预构建 Cut 前端；只生成输入不代表已构建或已发布。

在已授权的独立构建仓库中提交这些输入后，手动运行 `Build Yuchuangjie native
macOS installers` workflow，分别使用 Apple Silicon 与 Intel 原生 runner。
生成的 Actions artifacts 需要下载并通过业务发布接口上传，不会自动发布或修改推荐版本。

已有 Mac 也可直接执行：

```bash
MACOS_RELEASE_MODE=internal TARGET_ARCH="$(uname -m)" bash build-on-mac.command
```

需要 Python 3.11、Node 24、Xcode Command Line Tools，以及下载 npm、Chrome、FFmpeg
等依赖的网络。输出在 `output/arm64/` 或 `output/x86_64/`；构建工作区路径会打印并保留。

internal 为 ad-hoc 签名，未使用 Developer ID、未完成 Apple 公证，只供手动安装。
发布中心的签名/公证确认必须为 false，自动更新和强制更新关闭。
正式签名可在已配置证书和公证凭据的 Mac 上设置 `MACOS_RELEASE_MODE=signed`、
`CODESIGN_IDENTITY` 和 `NOTARYTOOL_PROFILE`。此模板不会导入私钥或配置公证账户。
