# UpdateBlocker123

目标 App：123云盘 2.1.5  
Bundle ID：`com.mfcloudcalculate.123networkdisk`

## 作用

- 将 `CFBundleShortVersionString` 伪装为 `99.99.99`
- 将 `CFBundleVersion` 伪装为 `999999`
- 拦截 `package_info_plus` 的 `getAll`，让 Flutter/Dart 层拿到高版本号
- 固定 `lastUpdatePromptTimestamp` / `storeLastUpdatePromptTimestamp` 到未来时间，减少非强制更新重复弹窗
- 辅助替换原生请求中的 `x-app-version` / `app-version` 请求头

## 编译

```bash
make package FINALPACKAGE=1
```

需要 macOS + Theos + iOS SDK。当前环境没有 iOS SDK，未生成可直接安装的 arm64 dylib。

## 安装

越狱环境可安装生成的 deb；非越狱重签 IPA 需要把 dylib 注入到 IPA 并添加载入命令，再用自己的证书重签。
