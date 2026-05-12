# UpdateBlocker123

`UpdateBlocker123` 是一个用于 **123云盘 iOS 版** 的更新提示屏蔽 dylib 项目。

项目通过伪装本地 App 版本号、拦截 Flutter `package_info_plus` 返回值、固定更新提示时间戳等方式，尽量阻止 App 内部的更新提示弹窗。

## 适配信息

| 项目 | 内容 |
|---|---|
| 目标 App | 123云盘 |
| 已测试版本 | 2.1.5 |
| Bundle ID | `com.mfcloudcalculate.123networkdisk` |
| 主程序 | `Runner` |
| 项目类型 | iOS tweak / dylib |
| 构建工具 | Theos |
| 注入方式 | 越狱插件安装或 IPA 重签注入 |
| 默认输出 | rootful / rootless 两种构建产物 |

## 项目功能

本项目主要用于屏蔽或减少 123云盘 App 内的更新提示。

当前实现包含：

- 将 `CFBundleShortVersionString` 伪装为 `99.99.99`；
- 将 `CFBundleVersion` 伪装为 `999999`；
- Hook `NSBundle`，让原生层读取到高版本号；
- Hook `FLTPackageInfoPlusPlugin` 的 `getAll` 方法，让 Flutter/Dart 层获取到伪装版本；
- 固定 `lastUpdatePromptTimestamp` / `storeLastUpdatePromptTimestamp` 到未来时间，减少非强制更新重复提示；
- 辅助替换原生请求中的 `x-app-version` / `app-version` 请求头。

## 工作原理

123云盘为 Flutter 应用，部分版本检测逻辑会从 `Info.plist` 或 `package_info_plus` 获取当前版本号。

本项目通过 Hook 以下位置：

```objc
NSBundle
FLTPackageInfoPlusPlugin
NSUserDefaults
NSMutableURLRequest
```

让 App 在运行时认为当前版本已经足够新，从而降低触发应用内更新提示的概率。

核心伪装值：

```text
CFBundleShortVersionString = 99.99.99
CFBundleVersion = 999999
```

## 当前已验证功能

| 功能 | 状态 |
|---|---|
| 伪装原生版本号 | 支持 |
| 伪装 Flutter `package_info_plus` 版本号 | 支持 |
| 减少非强制更新重复弹窗 | 支持 |
| 辅助替换部分原生请求头版本号 | 支持 |
| 登录 / 会员 / 授权 / 风控绕过 | 不支持 |
| 服务端强制停用旧版本 | 不保证可绕过 |

## 已知限制

### 1. 不保证绕过所有强制更新

如果服务端直接根据接口返回强制更新状态，或禁止旧版本继续使用，本项目不保证一定有效。

### 2. Flutter/Dart AOT 内部逻辑可能需要单独 Patch

如果更新判断完全发生在 Dart AOT 内部，并且不依赖原生版本号或 `package_info_plus`，则单纯 dylib Hook 可能无法完全屏蔽。

### 3. 仅针对指定版本测试

当前项目主要基于：

```text
123云盘 iOS 2.1.5
com.mfcloudcalculate.123networkdisk
```

其他版本是否可用未验证。

## 编译方式

本项目使用 Theos 编译。

### 本地编译

```bash
make clean
make package FINALPACKAGE=1
```

Rootless 构建：

```bash
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

编译完成后，产物通常位于：

```text
packages/
.theos/
```

## GitHub Actions 云编译

项目内提供 GitHub Actions 配置文件：

```text
.github/workflows/build.yml
```

当前 workflow 仅支持手动触发，不会在 push 时自动运行。

使用方式：

1. 上传项目到 GitHub 仓库；
2. 打开仓库的 **Actions** 页面；
3. 选择 **Build UpdateBlocker123**；
4. 点击 **Run workflow**；
5. 构建完成后，在 Artifacts 中下载构建产物。

输出目录：

```text
out/rootful/
out/rootless/
```

可能包含：

```text
UpdateBlocker123.dylib
*.deb
```

## 安装 / 注入方式

### 越狱环境

可直接安装构建得到的 `.deb` 包。

### 非越狱侧载环境

可将构建得到的：

```text
UpdateBlocker123.dylib
```

注入到 123云盘 IPA 中，然后使用自己的证书重新签名安装。

建议：

```text
不修改 Bundle ID
不要同时注入多个同类更新屏蔽 dylib
保持 Filter 指向 com.mfcloudcalculate.123networkdisk / Runner
```

## 文件说明

```text
.
├── Makefile
├── Tweak.xm
├── UpdateBlocker123.plist
├── control
├── README.md
└── .github/
    └── workflows/
        └── build.yml
```

| 文件 | 说明 |
|---|---|
| `Tweak.xm` | 主 Hook 代码 |
| `Makefile` | Theos 编译配置 |
| `UpdateBlocker123.plist` | MobileSubstrate / ElleKit 注入过滤配置 |
| `control` | deb 包信息 |
| `.github/workflows/build.yml` | GitHub Actions 手动构建配置 |
| `README.md` | 项目说明文档 |

## 注意事项

- 本项目仅用于学习、研究和个人设备调试；
- 本项目不包含 123云盘原始 IPA 或任何官方 App 文件；
- 本项目不提供绕过登录、会员、付费、授权、风控或服务端限制的功能；
- 使用者应自行承担使用风险；
- 使用者应自行确保使用方式符合当地法律法规及相关软件服务条款。

## 开源协议

本项目采用 **MIT License** 开源。

```text
MIT License

Copyright (c) 2026 4A Hello

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 免责声明

本项目仅作为技术研究和个人调试用途。  
使用本项目产生的任何风险由使用者自行承担，包括但不限于 App 无法启动、数据丢失、账号异常、签名失效、系统兼容性问题、服务端限制或其他不可预期问题。
