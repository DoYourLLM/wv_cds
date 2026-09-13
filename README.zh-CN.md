[English](README.md) | **中文**

# wv_cds — 把原理图的 net 送到 wv (Custom WaveView)

在 Virtuoso 原理图里右键一个 net，把它画到 wv：

| 右键菜单项 | 作用 |
|---|---|
| **Send to WV (Direct)** | 直接画到 wv，然后在原理图里把这些 net probe 出来 |
| **Send to WV_CDS (Interactive)** | 把 net 放进一个小 Python 表格；什么时候想画，你再从那里画，原理图的 probe 也会跟着更新 |

两个菜单项就在 net 菜单最上面。**按住 Shift 可以一次选中多条 net** —— 一条还是
n 条，都会一起送过去：

| 选中一条 net | 按住 Shift 选多条 |
|---|---|
| ![Wire 菜单：最上面是 Send to WV (Direct) 和 Send to WV_CDS (Interactive)](images/wv-cds-rmb-wire.png) | ![Multiple 菜单：同样两项在最上面](images/wv-cds-rmb-multiple.png) |

两个菜单项都会自己启动需要的东西 —— 你不必手工启动 wv、手工 source
`wv_rpc_server.tcl`，也不必手工打开 Python GUI。

## 环境要求

- Linux，Virtuoso 带原理图编辑器
- `wv`（Synopsys Custom WaveView），必须能用 `wv -ace_gui <script>` 启动
- Python 3 带 Tkinter，只有 `Send to WV_CDS (Interactive)` 需要
  （`sudo apt install python3-tk`）

## 安装

**1. 拿到包，运行一次安装脚本**

```bash
git clone https://github.com/DoYourLLM/wv_cds.git
cd wv_cds
./install.sh
```

如果是用 GitHub 的 **Download ZIP** 下载的，解压出来叫 `wv_cds-main`，不是
`wv_cds`：

```bash
unzip wv_cds-main.zip
cd wv_cds-main
./install.sh
```

**2. 往「启动 Virtuoso 的那个目录」里的 `.cdsinit` 加一行**

```skill
load("/where/you/put/wv_cds/skill/load_wv_cds.il")
```

**3. 启动 Virtuoso，打开原理图，右键一个 net**

先选中 net —— 多选和 descend 进子单元都可以。两个菜单项在菜单最上面。
加载后 CIW 会打印 `wv_cds loaded: ...`。

**4. 在 wv 里打开你的 fsdb**

第一次点击会替你启动 wv，但 wv 起来时没有打开任何波形文件，而信号名要对着文件
才能解析。先在 wv 里打开你的 fsdb，再回去点那个 net —— 之后画图就都用这个文件。

## Send to WV_CDS (Interactive) 的流程

![右键一个 net 选 Send to WV_CDS (Interactive)；net 落进 GUI 表格；在那儿按 Send to WV](images/wv-cds-send-to-wv-cds.png)

1. 右键那个 net，选 **Send to WV_CDS (Interactive)**。
2. net 出现在 **WV_CDS Python GUI** 窗口顶部的表格里。
3. 选中你要的行，按 **Send to WV** 把它们画到 wv。

## 自己启动 wv（可选）

两个右键菜单项在需要时会自己启动 wv，所以这一节只用于在碰 Virtuoso 之前先把
wv 起好：

```bash
./start_wv.sh        # 前台
./start_wv.sh -b     # 后台；RPC 端口起来后返回
./start_wv.sh -h     # 帮助
```

它跑的就是右键菜单项用的那条命令 —— `wv -ace_gui <package>/wv_rpc_server.tcl`
—— 所以 RPC server 会在 61888 上起来，Virtuoso 马上能和这个 wv 通信。

如果你不想按第 4 步手工打开文件，而是希望 direct 那条路替你打开一个固定文件，
就在 `skill/wv_cds_config.il` 里设置 `WV_CDS_FSDB`。

## 工作原理

```
right-click a net --> CCSwvPlotSelectedSignals
  |-- Send to WV (Direct) --> wv_cds_openfsdb.sh   (only when WV_CDS_FSDB is set)
  |                           wv_cds_plot.sh  --> 127.0.0.1:61888  (wv's RPC server)
  +-- Send to WV_CDS (Interactive) ------> wv_cds_add.sh   --> 127.0.0.1:61889  (Python GUI)
                              Send to WV in the GUI --> wv_cds_plot.sh --> 61888
```

61888 是 wv 自己的 RPC server，61889 是 Python GUI 的监听端口；分开是因为两个
server 不能共用一个端口。

## 文件说明

| 路径 | 是什么 |
|---|---|
| `install.sh` | 一次性安装；先跑它 |
| `start_wv.sh` | 手工启动 wv 并加载 RPC server（可选） |
| `skill/wv_cds_config.il` | **通常你唯一需要改的文件** |
| `skill/load_wv_cds.il` | 加载其余文件；`.cdsinit` 调用的就是它 |
| `python/wv_cds_gui.py` | 表格窗口 |
| `wv_cds_*.sh` | 通过 RPC 端口和 wv 通信的脚本 |
| `wv_rpc_server.tcl` | 跑在 wv 里面的 RPC server |

skill 和 python 这两半各自的说明见 `skill/README.md`、`python/README.md`。

## 注意事项

- **一个信号只画一次。** `wv_cds_plot.sh` 直接问 wv：留着每次返回的 line 对象探一下，
  你在 wv 里删掉的曲线会返回空 —— 所以还显示着的跳过，删掉的重新画。
- **两个菜单项都会 probe，Direct 那个会先清空该窗口的所有 probe，包括你手动放的。**
  正是靠这一步，wv 里删掉的 net 才会跟着失去 probe。wv 没应答时一个都不动。
- **`Send to WV_CDS (Interactive)` 也是 probe，只是顺序不同**：GUI 画图，再反过来请求
  Virtuoso 执行 probe（走 `python/wv_cds_skill_server.py` 这个小服务器）。**能连上那个
  端口的人就能在你的会话里执行任意 SKILL**，所以只绑 `127.0.0.1`；要关掉就设
  `WV_CDS_SKILL_SERVER = nil`。
- **右键器件端子画的是电流，不是电压。** 两个端子时名字 `<层次>.<inst>:*`，三个及以上时
  `<层次>.<inst>:<n>`；probe 打在**端子**上 `/I0/R2/PLUS`，是 terminal probe —— 所以
  `geDeleteAllProbe` 能像其他 probe 一样删掉，也不会跟你进到别的层级。
- wv 启动要一会儿：第一次点 `Send to WV (Direct)` 往往只是启动它，再点一次。
- GUI 的 `sh dir` 框必须指向本包，否则 **Send to WV** 没反应。
- net 名请保持普通字符：避免 `"`、`$`、反引号、`\`、`{`、`}`、`[`、`]` 和空白 —— 它会
  被拼进一条 Tcl 命令。
- 落在当前 cellview 引脚上的 net 是 port net，信号名往上提一级：`I0.I1.n1` → `I0.n1`。
- 除 `install.sh` 填的三处外没有机器相关路径；代码除注释里的破折号外都是纯 ASCII。
