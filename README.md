# 青聊

线上地址：https://zhongyemay.github.io/qingchat/

微信风格的真实聊天网站，使用 Supabase Auth、Postgres、Realtime 和私有 Storage。前端由 GitHub Pages 托管。

## 使用

1. 用邮箱和至少 8 位密码注册或登录。
2. 点击侧栏头像，在「我的资料」查看或修改青聊号、昵称、个性签名和头像颜色。
3. 点击 ＋ 搜索朋友的完整青聊号，发送好友申请。
4. 对方在「通讯录 → 新的朋友」接受后，即可互发文字、表情和图片。
5. 同一账号在其他设备登录即可查看云端聊天记录。发送成功和已读状态会自动同步。

图片支持 PNG/JPEG/WebP/GIF，最大 5 MB。网络中断时消息不会假装发送成功，文字会留在输入框供重试。离线时无法发送，恢复网络后会同步历史。

## 本地开发

```sh
npm ci
npm run check
npm run build
python3 -m http.server 3000
```

编辑 `src/app.js` 后需要重新运行构建。根目录 `app.js` 是提交到 Pages 的打包结果。`bash build.sh` 为其他静态托管平台复制可发布文件。

## 后端与权限

项目：ChattingHub Pro（uaxnhmaczwjldvjhcysk）。迁移位于 `supabase/migrations/`，已在该项目应用。`src/config.js` 仅包含公开的 publishable key，前端没有服务端密钥。

独立表：`qing_profiles`、`qing_friendships`、`qing_messages`、`qing_reads`。所有表启用 RLS；好友申请仅接收方可接受；消息及图片仅已确认的聊天双方可访问；已读更新使用 SECURITY INVOKER 函数，避免授予修改所属用户的权限。用户公开资料可被登录用户搜索，不包含邮箱。图片存放在私有 `qingchat-images` 桶，通过限时签名链接加载。

当前 Supabase 项目启用了邮箱自动确认，注册后可直接登录；这不表示邮箱所有权已经验证。若开启邮箱确认，请配置正式邮件服务，并在 Supabase Auth URL Configuration 添加 `https://zhongyemay.github.io/qingchat/` 为 Site URL 和 Redirect URL。找回密码需要上述回调设置和邮件服务，因此本次未在界面开放找回密码入口；配置邮件后可以开启。不能仅以请求成功作为邮件送达证明。

当前功能为一对一好友聊天，尚未提供群聊、语音视频通话、推送通知、账号删除和聊天导出。

## 验证

已用实际测试账号验证注册、资料编辑、好友搜索/申请/接受、文字与图片收发、实时跨账号和跨设备同步、持久化登录、聊天记录、已读状态与手机布局。匿名用户和第三方账号无法读取聊天、发送或伪造消息、访问私有图片。Supabase advisors 未报告新增青聊表/函数的安全问题。

权限集成测试：`NODE_USE_ENV_PROXY=1 node tests/integration.mjs`（代理环境）或 `node tests/integration.mjs`。测试会在配置的 Supabase 项目创建测试账号、好友关系和图片，并将账号资料保存到 Git 忽略的 `.test-accounts.json`。测试后必须清理这些测试资源，不能将该文件公开或提交。测试项目需允许测试邮箱自动确认。
