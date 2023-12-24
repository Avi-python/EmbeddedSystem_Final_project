# 防盜黑盒子

## LS9DS0

### Accelerometer
他有偵測物體傾斜程度的功能，細節不知道，但應該是測量重力加速度所算出。

### 通訊媒介 firebase -> mqtt
- 使用免費的網路 server

### 連線確認
- 借鑑TCP的 Three-way handshack

### 通訊訊息格式

#### Header
- 0: come from 板子
- 1: come from app

#### command
- a: ack
    - ai: for inital connection
        - 0ail: for lock state
        - 0aiu: for unlock state
        只有在 box 傳給我時會有這個 field，直接傳上鎖狀態
    - am: for acknowledge message
- s: syn
- f: fin，告知準備斷線
- c: for connection checking
- l: for change lock type
    - 0l: for success change lock type
        - 0lu: unlock
        - oll: lock
- d: detect, 發生事件
    - 0ds: for detect event happened
    - 1d: for disable detect
    - 0da: for ack diable detect

### 解除警戒
- 重新設置 box 那邊的 init_accel_(x,y,z), init_gryo_(x,y,z)
