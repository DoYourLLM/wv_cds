[English](README.md) | **中文**

# wv_cds — 把原理图的 net 送到 wv (Custom WaveView)

在 Virtuoso 原理图里右键一个 net，把它画到 wv 上。两种方式：

| 右键菜单项 | 作用 |
|---|---|
| **Send to WV (Direct)** | 直接画到 wv，不经过中间层 |
| **Send to WV_CDS** | 把 net 推进一个小 Python 表格窗口；什么时候想画，你再从那里画 |

两个菜单项都会把自己需要的东西自动启动起来 —— 你**不用**手工启动 wv、手工 source
`wv_rpc_server.tcl`，也不用手工打开 Python GUI。

---

## 环境要求

- Linux，Virtuoso 带原理图编辑器（SKILL）
- `wv`（Synopsys Custom WaveView）—— 必须能用
  `wv -ace_gui <script>` 启动，这样 RPC server 才能在它里面起来
- Python 3 带 Tkinter —— **只有** `Send to WV_CDS` 需要
  （Debian/Ubuntu 上装：`sudo apt install python3-tk`）
- 一个你想看的波形文件（fsdb）

## 安装 —— 三步

**1. 解压到任意目录，运行一次安装脚本**

```bash
tar xf wv_cds.tar.gz          # 或者 unzip，或者 git clone
cd wv_cds
./install.sh
```

`install.sh` 会给脚本加执行权限、把本包的真实位置写进三个需要绝对路径的文件
（分发出去的副本里只含占位符，所以不带任何跟机器相关的东西）、检查环境依赖，
并打印出第 2 步要用的那一行。以后要是挪了目录，重跑一次就行。

**2. 往 `~/.cdsinit` 里加一行**

用 `install.sh` 打印出来的那行，形如：

```skill
load("/where/you/put/wv_cds/skill/load_wv_cds.il")
```

（或者把 `skill/cdsinit.wv_cds` 改名成 `cdsinit` 放进你的项目目录 —— Virtuoso
自动加载的是这个名字的文件，不是现在这个。）

**3. 启动 Virtuoso，打开原理图，右键一个 net**

先选中 net（多选、以及 descend 进子单元都可以），然后右键点在这个 net 上。
两个菜单项在菜单最上面。

### 波形文件（可选）

启动 wv —— `./start_wv.sh` 可以单独起，右键菜单项也会替你起 —— 然后按你平常的
习惯在 wv 里打开波形文件。之后画图就按那个 wv 当前打开的文件来解析，所以这里
不需要配任何东西。

如果你更希望工具替你打开一个固定的文件，就在
`skill/wv_cds_config.il` 里设置；direct 那条路会在每次 session 首次画图之前，
正好打开这个文件：

```skill
WV_CDS_FSDB = "/path/to/your/simulation.fsdb"
```

### 自己启动 wv（可选）

两个右键菜单项在需要时都会自己启动 wv，所以这一节只适用于：你想在碰 Virtuoso
**之前**就把 wv 起好，或者你想看它的启动输出。

```bash
./start_wv.sh        # 前台；关掉 wv（或 Ctrl-C）就回到提示符
./start_wv.sh -b     # 后台；等 RPC 端口起来后返回
./start_wv.sh -h     # 帮助，含可用的环境变量覆盖
```

它跑的就是右键菜单项用的那条命令 ——
`wv -ace_gui <package>/wv_rpc_server.tcl` —— 所以 RPC server 会在 61888 上起来，
Virtuoso 马上就能和这个 wv 通信。如果端口已经在应答，就什么都不启动，所以重复
运行没有副作用。

---

## 你应该看到什么

`load(...)` 之后，CIW 打印七行，最后一行是：

```
wv_cds loaded: banner Example > wvcds, RMB net menu > Send to WV (Direct) / Send to WV_CDS
```

第一次点 `Send to WV (Direct)` 时：

```
wvCds: starting wv in the background - plots will work once it is up
wvCds: plot I0.n1 skipped - wv is not answering on the RPC port yet, it may still be starting; click again in a few seconds
...
wvCds: wv "started" - it is ready, click again to plot
```

wv 起来要花一会儿，所以**第一次**点击只是把它启动起来，此刻画图还没有对象可以
说话 —— 这就是为什么画图会被跳过、并且附上一句解释，而不是把连接错误直接甩给
你。等 "ready" 那行出现之后**再点一次**；这一次就画上了，之后每次点击打印
`wvCds: plot I0.n1 => ("1 new, 0 already plotted")`。

（如果 wv 报它解析不了这个信号，说明它里面还没打开波形文件；在 wv 里打开一个
再点一次。）

第一次点 `Send to WV_CDS` 时：

```
wvCds: started the wv_cds GUI (/where/you/put/wv_cds/python/wv_cds_gui.py)
wvCds: push I0.n1 to GUI => ("sent")
```

然后 net 就出现在 GUI 的表格里。在那儿按 **Send to WV** 把它画出来 —— 如果 wv
还没起来，这个按钮会替你启动（它跑 `start_wv.sh -b` 并等 RPC 端口），所以第一次
按就能成功，不会报 `Connection refused`。之后再点，GUI 已经在监听了，就什么都不
打印 —— 只有那行 push。

### Send to WV_CDS 的流程，看图

![右键一个 net 选 Send to WV_CDS；net 落进 GUI 表格；在那儿按 Send to WV](images/wv-cds-send-to-wv-cds.png)

1. 右键那个 net，选 **Send to WV_CDS**（菜单里红框那一项）。
2. net 出现在 **WV_CDS Python GUI** 窗口顶部的表格里。
3. 选中你要的行，按 **Send to WV** 把它们画到 wv。

GUI 底部的日志会记录每一步。这张截图里它同时显示了 `start_wv.sh` 说
`something is already listening on 61888`，然后警告有 **2 个 wv 进程**在跑。
只有一个进程能绑定 61888，所以第二个 wv 没有 RPC server，永远收不到图 ——
这条警告是功能在正常工作，不是故障。

（这张截图里 `sh dir` 框是故意留空的，免得把私有路径拍进图里。**Send to WV**
要能干活，这个框必须填包目录 —— 空着按按钮会报 `set the sh dir first`，
按 **Save** 也会拒绝。）

**关掉任何一个窗口都没关系。** 两个窗口都是按需启动的，而且启动脚本会先探测
自己的端口，所以已经在跑的进程会被复用，被关掉的下次点击会重新拉起。没有那种
「这个 session 已经做过了」的开关会卡住。

---

## 工作原理

```
right-click a net
  |
  |-- Send to WV (Direct) --> CCSwvPlotSelectedSignals --> wvCdsSendToWv
  |                                                          |
  |                                                          +-- start wv if the RPC port is dead
  |                                                          +-- wv_cds_openfsdb.sh  (only when WV_CDS_FSDB is set)
  |                                                          +-- wv_cds_plot.sh      (per net)
  |                                                                  -> 127.0.0.1:61888
  |
  +-- Send to WV_CDS ------> CCSwvPlotSelectedSignals --> wvCdsSendToGui
                                                             |
                                                             +-- start wv if needed
                                                             +-- start the Python GUI if needed
                                                             +-- wv_cds_add.sh  (per net)
                                                                     -> 127.0.0.1:61889

in the Python GUI:  Send to WV --> start_wv.sh -b (bring wv up, wait for the port)
                                     then wv_cds_plot.sh (per row) --> 127.0.0.1:61888
```

- **61888** 是 wv 自己的 RPC server，由 wv 内部的 `wv_rpc_server.tcl` 启动。
  那些 shell 脚本是它的客户端。
- **61889** 是 Python GUI 的 add 监听端口。之所以单独用一个端口，是因为两个
  server 不能共用一个。

## 文件说明

| 路径 | 是什么 |
|---|---|
| `install.sh` | 一次性安装；先跑它 |
| `start_wv.sh` | 手工启动 wv，并加载 RPC server（可选） |
| `skill/wv_cds_config.il` | **通常你唯一需要改的文件** |
| `skill/schRMB.il` | net 的右键菜单项 |
| `skill/wv_cds_ipc.il` | IPC 桥接，以及按需启动 wv / GUI |
| `skill/wv_cds_signal.il` | 读取原理图的选中项，拼出层次路径 |
| `skill/wv_cds_menu.il` | banner 菜单 `Example > wvcds` 和选中项包装 |
| `skill/wv_cds_table.il` | net 列表的 Virtuoso form 窗口版本 |
| `skill/load_wv_cds.il` | 加载以上所有（`.cdsinit` 调用的就是它） |
| `python/wv_cds_gui.py` | 表格窗口 |
| `python/wv_cds_config.py` | 它的配置（路径按文件自身位置解析） |
| `wv_cds_*.sh` | 通过 RPC 端口和 wv 通信的脚本 |
| `wv_rpc_server.tcl` | 跑在 wv 里面的 RPC server |
| `images/` | 本 README 用到的截图 |
| `docs/` | 开发笔记；可以安全删除 |

## 注意事项

- **一个信号只画一次。** `wv_cds_plot.sh` 会记住它已经交给 wv 的那些名字，记在
  **wv 内部**的一个 Tcl 变量里（`::wv_cds_plotted`），所以同一个 net 再点一次
  不会叠出第二条一模一样的曲线。这份记忆属于那个 wv 进程：重启 wv 就全部重画，
  打开文件也会重置。两个右键菜单项和 Python GUI 共用它，因为它们都走同一个脚本。
  回复里会说清楚发生了什么 —— `1 new, 2 already plotted`。这只覆盖工具自己画的；
  你在 wv 里手工加的曲线不在追踪范围内。
- net 名字交给 shell 时会用双引号包起来，所以尽量避免名字里出现 `"`、`$`
  或反引号。
- 落在当前 cellview 引脚上的 net 就是 port net，它的信号名要往上提一级：往下
  descend 两层时，`I0.I1.n1` 会变成 `I0.n1`。
- 包里除了 `install.sh` 填进去的那三处之外，没有任何文件含跟机器相关的路径；
  代码除了注释里的破折号（—）之外都是纯 ASCII —— 所以既不依赖你的 locale，
  也不依赖你把包解压到了哪里。
