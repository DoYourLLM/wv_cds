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

- **一个信号只画一次。** `wv_cds_plot.sh` 不靠记名字，而是**直接问 wv**：每次
  `sx_display` 返回的 line 对象都留着，下次点的时候拿它探一下。你在 wv 里删掉的
  曲线会返回空字符串 —— 所以还显示着的会跳过，你删掉的会重新画上。
- **`Send to WV (Direct)` 同时会 probe。** 画完之后它会问 wv 现在还显示着哪些
  信号（这个工具画过的全部，减去你在 wv 里删掉的），然后在原理图里给每个都加上
  net probe。**它会先清空该窗口里的所有 probe —— 包括你自己手动放的**；正是靠
  这一步，你在 wv 里删掉的 net 才会跟着失去 probe。wv 没应答时，一个 probe 都不动。
- **`Send to WV_CDS (Interactive)` 同样会 probe，只是顺序不同。** 这条路画图发生在 Python GUI 里，
  画完之后由 GUI 反过来请求 Virtuoso 执行 probe。Virtuoso 没法被外部直接调用，
  所以包里跑一个小型本地服务器，把收到的东西交给 Virtuoso **当 SKILL 求值**
  （`python/wv_cds_skill_server.py`，照 Cadence 官方示例移植）。**能连上这个端口的人
  就能在你的会话里执行任意 SKILL**，所以它只绑 `127.0.0.1`。要关掉就在
  `skill/wv_cds_config.il` 里设 `WV_CDS_SKILL_SERVER = nil`，那时 GUI 只会记一行
  "no skill server"，其余功能不受影响。Virtuoso 一退出，这个服务器就跟着退出，
  端口随它释放，不会留一个残进程占着。
- **右键器件端子画的是电流，不是电压。** 符号上的端子，两个端子时名字是
  `<层次>.<inst>:*`；三个及以上时是 `<层次>.<inst>:<n>`，n 是该端子的 net 在器件
  端子表里的位置；net 不在表里的端子会被跳过并 warn 一行。电流**不加 probe**——
  原理图的 probe 是 net，把端子名当 net 递过去（`/R2:1`）就会得到 "the object
  does not exist"；改成在原理图里高亮那个端子的 figure 本身，CIW 里同时打印它
  对应的实例端子路径（`/I0/R2/PLUS`）。标记是**按 wv 报回来的列表重建的**，和
  net probe 同一轮：wv 里还留着哪个电流，那个端子就一直标着；你在 wv 里删掉曲线，
  标记也跟着消失。wv 里有、但本次会话没发过的电流没有记录 figure，只会计数、
  不会标。net / 导线不受影响，照旧 probe。
- wv 启动要一会儿，所以第一次点 `Send to WV (Direct)` 往往只是把它启动起来、
  画图被跳过；等它起来后再点一次。
- GUI 的 `sh dir` 框如果空着，**Send to WV** 不会有任何动作 —— 它必须指向本包。
- net 名字交给 shell 时会用双引号包起来，随后又被拼进一条 Tcl 命令，所以请让它
  保持普通字符：避免 `"`、`$`、反引号、`\`、`{`、`}`、`[`、`]` 和空白。名字里
  带 `[` 或 `$` 时，到达 wv 的就不是名字而是 Tcl 语法了。
- 落在当前 cellview 引脚上的 net 就是 port net，信号名要往上提一级：
  `I0.I1.n1` 会变成 `I0.n1`。
- 包里除了 `install.sh` 填的那三处之外没有文件含机器相关路径；代码除注释里的
  破折号外都是纯 ASCII。
