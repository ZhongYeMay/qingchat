# Chat

线上地址：https://zhongyemay.github.io/qingchat/

Chat 3.1 使用 Google 官方 Material Web 组件与 Material Design 3 配色系统，支持浅色、深色、主题色和聊天外观自定义。前端由 GitHub Pages 托管，账号、聊天、动态与图片由 Supabase Auth、Postgres、Realtime 和私有 Storage 提供。

## 使用

1. 在「设置 → 账号与登录」注册或登录，编辑 Chat 号、昵称、签名和头像颜色。
2. 在通讯录添加朋友；对方接受后即可收发文字、表情、图片，并同步消息与已读状态。
3. 「动态」支持好友圈、公开广场、关注和收藏；可以发布文字与最多四张图片，点赞、评论、关注、收藏和转发公开动态。「公开」表示所有已登录的 Chat 用户可见。
4. 点击动态上的「分享」，或在聊天中选择最多 30 条消息，创建只读快照。两类分享均可自定义标题、说明、分享署名、主题色、分享内图片封面、昵称显示与 1/7/30 天有效期；创建前有卡片预览。在「设置 → 隐私与分享」统一查看和撤销链接。好友动态仅作者本人可创建公开链接；公开动态可由其他登录用户分享。动态快照不含评论、点赞和收藏，原动态删除后对应分享同时失效。任何获得链接的人都能在有效期内阅读所选内容，撤销不会删除对方已保存的副本。
5. 在「设置 → 系统通知」主动授权通知，可测试通知并控制是否显示消息正文。网页在后台且保持打开时，新消息会触发浏览器系统通知，点击可返回对应聊天。关闭网页后的 Web Push 尚未实现；系统也可能限制通知。iPhone/iPad 需先添加到主屏幕，且浏览器须支持相关 API。
6. 「设置 → 关于 → 更新日志」保留各次版本变化，后续发布也应同步维护。

聊天与动态图片支持 PNG/JPEG/WebP/GIF，单张最大 5 MB。外观偏好保存在当前浏览器，账号和内容保存在云端。网络错误会显示失败状态，不会假装发送成功。

## 分享预览的范围

Chat 内粘贴分享链接会显示所选聊天的标题、摘要和条数。独立 `share.html` 页面支持匿名阅读有效快照和图片，过期或撤销后不可再访问。

GitHub Pages 是静态托管：外部社交平台抓取到的是通用 Chat Open Graph/Twitter 卡片，不会获得每条聊天专属的服务端预览。实现专属外部卡片还需要可返回动态 HTML 的托管服务或自定义域名方案。Supabase 默认 Edge Functions 域名不能直接提供可渲染的 HTML 分享页。

## 开发与发布

```sh
npm ci
npm run check
node tests/sw.test.mjs
npm run build
python3 -m http.server 3000
```

源码位于 `src/`。构建同时生成根目录 `app.js`、`share.js`，并更新静态资源内容哈希；生成文件须与源码一起提交到 Pages。`bash build.sh` 会额外将可发布文件复制到忽略的 `public/`。每次用户可见的发布须更新 `src/releases.js` 和 `package.json` 版本。

## 后端与权限

Supabase 项目：ChattingHub Pro（`uaxnhmaczwjldvjhcysk`）。迁移位于 `supabase/migrations/`。`src/config.js` 仅包含公开 publishable key；服务端密钥不得进入前端或仓库。保留旧 `qing_*` 表名及浏览器会话键，以兼容已有账号和消息。

聊天表 `qing_profiles`、`qing_friendships`、`qing_messages`、`qing_reads` 启用 RLS；只有已确认的聊天双方可读取消息与私有图片。公开资料不含邮箱。

动态表 `chat_posts`、`chat_likes`、`chat_comments`、`chat_follows`、`chat_bookmarks` 启用 RLS；好友动态与图片仅作者和已接受好友可读，收藏仅本人可读。私有桶 `chat-post-images` 的读取也受动态可见范围约束。

`chat_shares` 由数据库按当前用户可读消息生成不可修改快照，要求所选消息属于同一聊天。前端不能伪造快照。`supabase/functions/chat-share/index.ts` 是匿名能力链接入口：校验随机 UUID、有效期与撤销状态，只返回该快照。图片代理再次校验分享及规范存储路径。该函数使用服务端环境密钥，部署时 `verify_jwt=false`；不能以此配置开放其他数据接口。响应禁用缓存，图片不暴露原始签名链接。

当前项目启用邮箱自动确认，注册成功不代表邮箱所有权已验证。若开启邮箱验证或找回密码，需要配置正式邮件服务和 Auth 回调地址。尚未提供群聊、音视频通话、账号删除和聊天导出。

## 验证

已通过真实测试账号验证聊天、动态、好友与公开可见范围、图片、点赞评论、关注收藏转发、匿名分享、昵称隐藏及即时撤销；第三方账号不能读取好友动态与图片。已验证移动布局、官方 Material 组件、主题切换与通知点击路由。安全检查未报告新增 Chat 表或函数的问题。

```sh
node tests/sw.test.mjs
NODE_USE_ENV_PROXY=1 node tests/social-integration.mjs
NODE_USE_ENV_PROXY=1 node tests/custom-sharing.integration.mjs
```

自定义分享测试使用独立的 `.test-custom-shares.json` 保存待清理测试资源。集成测试会创建真实测试账号、好友、内容和图片，将凭据保存在 Git 忽略的 `.test-v3-accounts.json`。只在允许测试邮箱自动确认的项目运行，完成后必须清理对应测试账号及存储对象；严禁提交凭据文件。旧聊天测试位于 `tests/integration.mjs`，使用独立的 `.test-accounts.json`。
